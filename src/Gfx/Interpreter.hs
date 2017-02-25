module Gfx.Interpreter where

import Data.Maybe (maybe)
import Control.Monad (mapM, when, void)
import Control.Monad.State.Strict

import Graphics.Rendering.OpenGL hiding (Fill, get)

import Gfx.Ast
import Gfx.EngineState
import Gfx.Geometries

hasTransparency :: Color4 Double -> Bool
hasTransparency (Color4 _ _ _ a) = a < 1.0

fullyTransparent :: Color4 Double -> Bool
fullyTransparent (Color4 _ _ _ a) = a == 0

drawNow :: EngineState -> Color4 Double -> IO () -> IO ()
drawNow es colour action =
  let
    transDraw = drawTransparencies es
  in
    when (not (fullyTransparent colour) && ((transDraw && hasTransparency colour)
          || (not transDraw && not (hasTransparency colour))))
      action

type GfxAction = IO
type GfxOutput = ()

type GraphicsEngine v = StateT EngineState GfxAction v

interpretGfx :: GfxAst -> GraphicsEngine GfxOutput
interpretGfx = void . interpretBlock

interpretBlock :: Block -> GraphicsEngine [ GfxOutput ]
interpretBlock = mapM interpretCommand

interpretCommand' :: GraphicsEngine GfxOutput -> Maybe Block -> GraphicsEngine GfxOutput
interpretCommand' commandOutput = maybe commandOutput (newScope commandOutput)


interpretCommand :: GfxCommand -> GraphicsEngine GfxOutput
interpretCommand (ShapeCommand shapeAst block) = interpretCommand' (interpretShape shapeAst) block
interpretCommand (MatrixCommand matrixAst block) = interpretCommand' (interpretMatrix matrixAst) block
interpretCommand (ColourCommand colourAst block) = interpretCommand' (interpretColour colourAst) block

interpretShape :: ShapeGfx -> GraphicsEngine GfxOutput
interpretShape (Cube x y z) =
  do
    es <- get
    strokeC <- gets currentStrokeColour
    fillC <- gets currentFillColour
    lift $ preservingMatrix $ do
      scale x y z
      drawNow es fillC (color fillC >> cube 1)
      drawNow es strokeC (color strokeC >> cubeFrame 1)

interpretMatrix :: MatrixGfx -> GraphicsEngine GfxOutput
interpretMatrix (Rotate x y z) =
  do
    lift $ rotate x $ Vector3 1 0 0
    lift $ rotate y $ Vector3 0 1 0
    lift $ rotate z $ Vector3 0 0 1
interpretMatrix (Scale x y z) = lift $ scale x y z
interpretMatrix (Move x y z) = lift $ translate $ Vector3 x y z

interpretColour :: ColourGfx -> GraphicsEngine GfxOutput
interpretColour (Fill r g b a) = modify' (pushFillColour $ Color4 r g b a)
interpretColour NoFill = modify' (pushFillColour $ Color4 0 0 0 0)

interpretColour (Stroke r g b a) = modify' (pushStrokeColour $ Color4 r g b a)
interpretColour NoStroke = modify' (pushStrokeColour $ Color4 0 0 0 0)

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
