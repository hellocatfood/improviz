module Main where

import Graphics.UI.GLUT hiding (Cube, get, Fill)

import Data.Map.Strict hiding (size)
import Control.Monad.State.Strict

import GfxAst
import GfxInterpreter
import GfxEngineState

import Data.IORef

displayAst :: GfxAst
displayAst = [
  ColourCommand (Stroke (Number 0) (Number 0) (Number 0) (Number 1)) Nothing,
  ColourCommand (Fill (Number 0) (Number 0.7) (Number 0.2) (Number 1)) Nothing,
  MatrixCommand (Rotate (Variable "time") (Number 0) (Number 1)) $ Just [
    ShapeCommand (Cube (Number 0.3) (Number 0.6) (Number 0.2)) $ Just [
      ColourCommand NoFill Nothing,
      MatrixCommand (Rotate (Number 2) (Variable "time") (Variable "time")) Nothing,
      ShapeCommand (Cube (Number 0.3) (Number 0.5) (Number 0.1)) Nothing
    ]]]

startState :: EngineState
startState = EngineState {
    variables = fromList [("time", 1)]
  , fillColours = [Color4 1 1 1 1]
  , strokeColours = [Color4 0 0 0 1]
  , backgroundColour = Color4 1 1 1 1
}

main :: IO ()
main = do
  (_progName, _args) <- getArgsAndInitialize
  initialDisplayMode $= [WithDepthBuffer]
  _window <- createWindow _progName
  reshapeCallback $= Just reshape
  depthFunc $= Just Less
  blend $= Enabled
  blendFunc $= (SrcAlpha, OneMinusSrcAlpha)
  initialState <- newIORef startState
  displayCallback $= display initialState
  idleCallback $= Just (idle initialState)
  mainLoop

display :: IORef EngineState -> DisplayCallback
display engineState = do
  es <- readIORef engineState
  clearColor $= backgroundColour es
  clear [ ColorBuffer, DepthBuffer ]
  clear [ ColorBuffer ]
  loadIdentity
  putStrLn "display loop"
  evalStateT (interpretGfx displayAst) es
  flush

reshape :: ReshapeCallback
reshape size = do
  viewport $= (Position 0 0, size)
  postRedisplay Nothing


idle :: IORef EngineState -> IdleCallback
idle engineState = do
  es <- readIORef engineState
  let newvars = adjust (1 +) "time" (variables es)
  writeIORef engineState es {variables=newvars}
  postRedisplay Nothing
