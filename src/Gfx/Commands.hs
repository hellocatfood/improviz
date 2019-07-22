module Gfx.Commands
  ( drawShape
  , rotate
  , scale
  , move
  , textureFill
  , colourFill
  , noFill
  , colourStroke
  , noStroke
  , setBackground
  , setAnimationStyle
  , pushScope
  , popScope
  , renderCode
  , renderCodeToBuffer
  )
where

import           Control.Monad.Trans            ( liftIO )
import           Control.Monad.State.Strict     ( modify' )
import           Lens.Simple                    ( use
                                                , assign
                                                , view
                                                )
import qualified Data.Map.Strict               as M

import           Data.Maybe                     ( maybe )
import           Data.Vec                       ( Mat44
                                                , multmm
                                                )

import           Graphics.Rendering.OpenGL      ( ($=)
                                                , GLfloat
                                                , TextureUnit(..)
                                                , TextureTarget2D(Texture2D)
                                                , activeTexture
                                                , textureBinding
                                                , currentProgram
                                                )

import           Gfx.Engine
import           Gfx.GeometryBuffers            ( ShapeBuffer(..) )
import           Gfx.Matrices                   ( scaleMat
                                                , translateMat
                                                , rotMat
                                                )
import           Gfx.Shaders                    ( setMVPMatrixUniform
                                                , shaderProgram
                                                , setColourUniform
                                                )
import           Gfx.Types                      ( Colour(..) )
import           Gfx.VertexBuffers              ( VBO
                                                , drawVBO
                                                )
import           Gfx.PostProcessing             ( AnimationStyle(..) )
import           Gfx.TextRendering              ( renderText
                                                , renderTextToBuffer
                                                )
import           Gfx.OpenGL                     ( printErrors )


getFullMatrix :: GraphicsEngine (Mat44 GLfloat)
getFullMatrix = do
  mMat <- head <$> use matrixStack
  pMat <- use projectionMatrix
  vMat <- use viewMatrix
  return $ multmm (multmm pMat vMat) mMat

drawTriangles :: VBO -> GraphicsEngine ()
drawTriangles vbo = do
  style <- head <$> use fillStyles
  case style of
    GFXFillColour fillC -> do
      mvp     <- getFullMatrix
      program <- use colourShaders
      liftIO (currentProgram $= Just (shaderProgram program))
      liftIO $ setMVPMatrixUniform program mvp
      liftIO $ setColourUniform program fillC
      liftIO $ drawVBO vbo
    GFXFillTexture name frame -> do
      mvp     <- getFullMatrix
      program <- use textureShaders
      liftIO (currentProgram $= Just (shaderProgram program))
      textureLib <- use textureLibrary
      case M.lookup name textureLib >>= M.lookup frame of
        Nothing      -> return ()
        Just texture -> do
          liftIO $ activeTexture $= TextureUnit 0
          liftIO $ textureBinding Texture2D $= Just texture
          liftIO $ setMVPMatrixUniform program mvp
          liftIO $ drawVBO vbo
    GFXNoFill -> return ()
  liftIO printErrors

drawWireframe :: VBO -> GraphicsEngine ()
drawWireframe vbo = do
  style <- head <$> use strokeStyles
  case style of
    GFXStrokeColour strokeC -> do
      mvp     <- getFullMatrix
      program <- use strokeShaders
      liftIO (currentProgram $= Just (shaderProgram program))
      liftIO $ setMVPMatrixUniform program mvp
      liftIO $ setColourUniform program strokeC
      liftIO $ drawVBO vbo
    GFXNoStroke -> return ()
  liftIO printErrors

drawShape :: String -> Float -> Float -> Float -> GraphicsEngine ()
drawShape name x y z = do
  gbos <- use geometryBuffers
  case M.lookup name gbos of
    Nothing -> liftIO $ print $ "Could not find shape: " ++ name
    Just (ShapeBuffer tb wb) -> do
      modify' (pushMatrix $ scaleMat x y z)
      maybe (return ()) drawTriangles tb
      maybe (return ()) drawWireframe wb
      modify' popMatrix

rotate :: Float -> Float -> Float -> GraphicsEngine ()
rotate x y z = modify' (multMatrix $ rotMat x y z)

scale :: Float -> Float -> Float -> GraphicsEngine ()
scale x y z = modify' (multMatrix $ scaleMat x y z)

move :: Float -> Float -> Float -> GraphicsEngine ()
move x y z = modify' (multMatrix $ translateMat x y z)

setBackground :: Float -> Float -> Float -> GraphicsEngine ()
setBackground r g b = assign backgroundColor (Colour r g b 1)

setAnimationStyle :: AnimationStyle -> GraphicsEngine ()
setAnimationStyle = assign animationStyle

textureFill :: String -> Float -> GraphicsEngine ()
textureFill name frame =
  modify' (pushFillStyle $ GFXFillTexture name (floor frame))

colourFill :: Float -> Float -> Float -> Float -> GraphicsEngine ()
colourFill r g b a = modify' (pushFillStyle $ GFXFillColour $ Colour r g b a)

noFill :: GraphicsEngine ()
noFill = modify' (pushFillStyle GFXNoFill)

colourStroke :: Float -> Float -> Float -> Float -> GraphicsEngine ()
colourStroke r g b a =
  modify' (pushStrokeStyle $ GFXStrokeColour $ Colour r g b a)

noStroke :: GraphicsEngine ()
noStroke = modify' (pushStrokeStyle GFXNoStroke)

pushScope :: GraphicsEngine ()
pushScope = do
  mStack  <- use matrixStack
  fStyles <- use fillStyles
  sStyles <- use strokeStyles
  stack   <- use scopeStack
  let savable = SavableState mStack fStyles sStyles
  assign scopeStack (savable : stack)

popScope :: GraphicsEngine ()
popScope = do
  stack <- use scopeStack
  let prev = head stack
  assign scopeStack   (tail stack)
  assign fillStyles   (view savedFillStyles prev)
  assign strokeStyles (view savedStrokeStyles prev)
  assign matrixStack  (view savedMatrixStack prev)

renderCode :: String -> GraphicsEngine ()
renderCode text = do
  tr <- use textRenderer
  liftIO $ renderText 0 0 tr text

renderCodeToBuffer :: String -> GraphicsEngine ()
renderCodeToBuffer text = do
  tr <- use textRenderer
  liftIO $ renderText 0 0 tr text
  liftIO $ renderTextToBuffer tr
