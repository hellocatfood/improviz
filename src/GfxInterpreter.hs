module GfxInterpreter where

import Data.Map.Strict hiding (foldl)
import Data.Maybe (maybe)
import Control.Monad (mapM)
import Control.Monad.State.Strict

import Graphics.Rendering.OpenGL hiding (Fill, get)

import GfxAst
import Geometries


type GfxAction = IO
type GfxOutput = ()

data EngineState = EngineState {
    variables :: Map String Double
  , fillColours :: [ Color4 Double ]
  , strokeColours :: [ Color4 Double ]
  , backgroundColour :: Color4 GLfloat
} deriving (Show, Eq)

type GraphicsEngine v = StateT EngineState GfxAction v

interpretGfx :: GfxAst -> GraphicsEngine GfxOutput
interpretGfx ast = do
  _ <- interpretBlock ast
  return ()

interpretBlock :: Block -> GraphicsEngine [ GfxOutput ]
interpretBlock = mapM interpretCommand

interpretCommand' :: GraphicsEngine GfxOutput -> Maybe Block -> GraphicsEngine GfxOutput
interpretCommand' commandOutput = maybe commandOutput (newScope commandOutput)


interpretCommand :: GfxCommand -> GraphicsEngine GfxOutput
interpretCommand (ShapeCommand shapeAst block) = interpretCommand' (interpretShape shapeAst) block
interpretCommand (MatrixCommand matrixAst block) = interpretCommand' (interpretMatrix matrixAst) block
interpretCommand (ColourCommand colourAst block) = interpretCommand' (interpretColour colourAst) block

interpretShape :: ShapeGfx -> GraphicsEngine GfxOutput
interpretShape (Cube xV yV zV) =
  do
    x <- getValue xV
    y <- getValue yV
    z <- getValue zV
    strokeC <- getStroke
    fillC <- getFill
    lift $ preservingMatrix $ do
      scale x y z
      color fillC
      cube 1
      color strokeC
      cubeFrame 1

interpretMatrix :: MatrixGfx -> GraphicsEngine GfxOutput
interpretMatrix (Rotate xV yV zV) =
  do
    x <- getValue xV
    y <- getValue yV
    z <- getValue zV
    lift $ rotate x $ Vector3 1 0 0
    lift $ rotate y $ Vector3 0 1 0
    lift $ rotate z $ Vector3 0 0 1

interpretColour :: ColourGfx -> GraphicsEngine GfxOutput
interpretColour (Fill rV gV bV aV) = do
  r <- getValue rV
  g <- getValue gV
  b <- getValue bV
  a <- getValue aV
  pushFill r g b a
interpretColour NoFill = pushFill 0 0 0 0
interpretColour (Stroke rV gV bV aV) = do
  r <- getValue rV
  g <- getValue gV
  b <- getValue bV
  a <- getValue aV
  pushStroke r g b a
interpretColour NoStroke = pushStroke 0 0 0 0

getValue :: Value -> GraphicsEngine Double
getValue (Number v) = return v
getValue (Variable name) = gets $ findWithDefault 0 name . variables

pushFill :: Double -> Double -> Double -> Double -> GraphicsEngine GfxOutput
pushFill r g b a = modify' (\s ->  s { fillColours = Color4 r g b a : fillColours s })

popFill :: GraphicsEngine GfxOutput
popFill = modify' (\s ->  s { fillColours = tail $ fillColours s })

getFill :: GraphicsEngine (Color4 GLdouble)
getFill = gets (head . fillColours)

pushStroke :: Double -> Double -> Double -> Double -> GraphicsEngine GfxOutput
pushStroke r g b a = modify' (\s ->  s { strokeColours = Color4 r g b a : strokeColours s })

popStroke :: GraphicsEngine GfxOutput
popStroke = modify' (\s ->  s { strokeColours = tail $ strokeColours s })

getStroke :: GraphicsEngine (Color4 GLdouble)
getStroke = gets (head . strokeColours)


newScope :: GraphicsEngine GfxOutput -> Block -> GraphicsEngine GfxOutput
newScope gfx block =
  let
    stateMap :: IO (a, EngineState) -> IO (GfxOutput, EngineState)
    stateMap d = preservingMatrix $ do
      (_, engineState) <- d
      _ <- evalStateT (interpretBlock block) engineState
      return ((), engineState)
  in
    mapStateT stateMap gfx
