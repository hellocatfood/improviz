{-# LANGUAGE TemplateHaskell   #-}

module Gfx.Engine where

import           Control.Monad.State.Strict
import           Data.Vec                       ( Mat44
                                                , identity
                                                , multmm
                                                )
import           Graphics.Rendering.OpenGL      ( GLfloat )
import           Lens.Simple                    ( makeLenses
                                                , over
                                                , view
                                                , set
                                                , (^.)
                                                )

import           Gfx.GeometryBuffers            ( GeometryBuffers
                                                , createAllBuffers
                                                )
import           Gfx.Matrices                   ( projectionMat
                                                , vec3
                                                , viewMat
                                                )
import           Gfx.PostProcessing             ( AnimationStyle(NormalStyle)
                                                , PostProcessing
                                                )
import           Gfx.Shaders
import           Gfx.TextRendering              ( TextRenderer )
import           Gfx.Textures                   ( TextureLibrary )
import           Gfx.Types                      ( Colour(..) )

import           Configuration                  ( ImprovizConfig )
import qualified Configuration                 as C
import qualified Configuration.Screen          as CS

import           Util                           ( (/.) )

data GFXFillStyling
  = GFXFillColour Colour
  | GFXFillTexture String
                   Int
  | GFXNoFill
  deriving (Eq, Show)

data GFXStrokeStyling
  = GFXStrokeColour Colour
  | GFXNoStroke
  deriving (Eq, Show)

data SavableState = SavableState
  { _savedMatrixStack  :: [Mat44 GLfloat]
  , _savedFillStyles   :: [GFXFillStyling]
  , _savedStrokeStyles :: [GFXStrokeStyling]
  } deriving (Show)

makeLenses ''SavableState

data GfxEngine = GfxEngine
  { _fillStyles         :: [GFXFillStyling]
  , _strokeStyles       :: [GFXStrokeStyling]
  , _geometryBuffers    :: GeometryBuffers
  , _textureLibrary     :: TextureLibrary
  , _colourShaders      :: Shaders
  , _textureShaders     :: Shaders
  , _viewMatrix         :: Mat44 GLfloat
  , _projectionMatrix   :: Mat44 GLfloat
  , _postFX             :: PostProcessing
  , _textRenderer       :: TextRenderer
  , _matrixStack        :: [Mat44 GLfloat]
  , _scopeStack         :: [SavableState]
  , _animationStyle     :: AnimationStyle
  , _backgroundColor    :: Colour
  } deriving (Show)

makeLenses ''GfxEngine

type GraphicsEngine v = StateT GfxEngine IO v

createGfxEngine
  :: ImprovizConfig
  -> Int
  -> Int
  -> PostProcessing
  -> TextRenderer
  -> TextureLibrary
  -> IO GfxEngine
createGfxEngine config width height pprocess trender textLib =
  let ratio      = width /. height
      front      = config ^. C.screen . CS.front
      back       = config ^. C.screen . CS.back
      projection = projectionMat front back (pi / 4) ratio
      view       = viewMat (vec3 0 0 10) (vec3 0 0 0) (vec3 0 1 0)
  in  do
        gbos <- createAllBuffers
        cshd <- createColourShaders
        tshd <- createTextureShaders
        return GfxEngine { _fillStyles       = [GFXFillColour $ Colour 1 1 1 1]
                         , _strokeStyles = [GFXStrokeColour $ Colour 0 0 0 1]
                         , _geometryBuffers  = gbos
                         , _textureLibrary   = textLib
                         , _colourShaders    = cshd
                         , _textureShaders   = tshd
                         , _viewMatrix       = view
                         , _projectionMatrix = projection
                         , _postFX           = pprocess
                         , _textRenderer     = trender
                         , _matrixStack      = [identity]
                         , _scopeStack       = []
                         , _animationStyle   = NormalStyle
                         , _backgroundColor  = Colour 1 1 1 1
                         }

resizeGfxEngine
  :: ImprovizConfig
  -> Int
  -> Int
  -> PostProcessing
  -> TextRenderer
  -> GfxEngine
  -> GfxEngine
resizeGfxEngine config newWidth newHeight newPP newTR =
  let front    = config ^. C.screen . CS.front
      back     = config ^. C.screen . CS.back
      newRatio = newWidth /. newHeight
      newProj  = projectionMat front back (pi / 4) newRatio
  in  set projectionMatrix newProj . set postFX newPP . set textRenderer newTR

updateGfxEngine :: GfxEngine -> GfxEngine -> GfxEngine
updateGfxEngine es changed = es { _animationStyle  = _animationStyle changed
                                , _backgroundColor = _backgroundColor changed
                                }

pushFillStyle :: GFXFillStyling -> GfxEngine -> GfxEngine
pushFillStyle s = over fillStyles (s :)

currentFillStyle :: GfxEngine -> GFXFillStyling
currentFillStyle = head . view fillStyles

pushStrokeStyle :: GFXStrokeStyling -> GfxEngine -> GfxEngine
pushStrokeStyle c = over strokeStyles (c :)

currentStrokeStyle :: GfxEngine -> GFXStrokeStyling
currentStrokeStyle = head . view strokeStyles

pushMatrix :: GfxEngine -> Mat44 Float -> GfxEngine
pushMatrix es mat =
  let stack = view matrixStack es
      comp  = multmm (head stack) mat
  in  set matrixStack (comp : stack) es

popMatrix :: GfxEngine -> GfxEngine
popMatrix = over matrixStack tail

modelMatrix :: GfxEngine -> Mat44 Float
modelMatrix = head . view matrixStack

multMatrix :: GfxEngine -> Mat44 Float -> GfxEngine
multMatrix es mat =
  let stack   = view matrixStack es
      newhead = multmm (head stack) mat
  in  set matrixStack (newhead : tail stack) es
