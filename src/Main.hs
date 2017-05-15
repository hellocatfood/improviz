module Main where

import GHC.Float (double2Float)

import qualified Graphics.UI.GLFW as GLFW
import Graphics.Rendering.OpenGL
import System.Exit
import System.IO

import Control.Monad
import Control.Monad.State.Strict (evalStateT)
import Control.Concurrent
import Control.Concurrent.STM
import qualified Gfx.Matrices as GM

import Gfx
import qualified Language as L
import qualified Language.Ast as LA
import AppServer
import AppTypes
import Gfx.PostProcessing
import Gfx.TextRendering
import Gfx.Windowing


-- type ErrorCallback = Error -> String -> IO ()
errorCallback :: GLFW.ErrorCallback
errorCallback _ = hPutStrLn stderr

main :: IO ()
main = do
  gfxETMVar <- newEmptyTMVarIO
  asTVar <- newTVarIO makeAppState
  _ <- forkIO $ runServer asTVar

  let initialWidth = 640
  let initialHeight = 480
  let initCB = initApp gfxETMVar
  let resizeCB = resize gfxETMVar
  let displayCB = display asTVar gfxETMVar
  setupWindow initialWidth initialHeight initCB resizeCB displayCB
  exitSuccess

initApp :: TMVar EngineState -> Int -> Int -> IO ()
initApp gfxEngineTMVar width height = do
  let ratio = fromIntegral width / fromIntegral height
      front = 0.1
      back = 100
      charSize = 36
      proj = GM.projectionMat front back (pi/4) ratio
      view = GM.viewMat (GM.vec3 0 0 10) (GM.vec3 0 0 0) (GM.vec3 0 1 0)

  post <- createPostProcessing (fromIntegral width) (fromIntegral height)

  let textColour = Color4 0.0 0.0 0.0 1.0 :: Color4 GLfloat
  let textBGColour = Color4 1.0 0.8 0.0 1.0 :: Color4 GLfloat
  textRenderer <- createTextRenderer front back width height "fonts/VeraMono.ttf" charSize textColour textBGColour

  gfxEngineState <- baseState proj view post textRenderer
  atomically$ putTMVar gfxEngineTMVar gfxEngineState


resize :: TMVar EngineState -> GLFW.WindowSizeCallback
resize esVar window newWidth newHeight = do
  print "Resizing"
  (fbWidth, fbHeight) <- GLFW.getFramebufferSize window
  engineState <- atomically $ readTMVar esVar
  deletePostProcessing $ postFX engineState
  newPost <- createPostProcessing (fromIntegral fbWidth) (fromIntegral fbHeight)
  newTrender <- resizeTextRendererScreen 0.1 100 fbWidth fbHeight (textRenderer engineState)
  let newRatio = fromIntegral fbWidth / fromIntegral fbHeight
      newProj = GM.projectionMat 0.1 100 (pi/4) newRatio
  atomically $ do
    es <- takeTMVar esVar
    putTMVar esVar es {
        projectionMatrix = newProj,
        postFX = newPost,
        textRenderer = newTrender
      }

display :: TVar AppState -> TMVar EngineState -> Double -> IO ()
display appState gfxState time = do
  as <- readTVarIO appState
  gs <- atomically $ readTMVar gfxState
  let vars = [("time", LA.Number (double2Float time))]

  case fst $ L.createGfx vars (currentAst as) of
    Left msg -> do
      putStrLn $ "Could not interpret program: " ++ msg
      atomically $ modifyTVar appState (\as -> as { currentAst = lastWorkingAst as })
    Right scene ->
      do
        drawScene gs scene
        drawText gs as
        unless (currentAst as == lastWorkingAst as) $ do
          putStrLn "Saving current ast"
          atomically $ modifyTVar appState (\as -> as { lastWorkingAst = currentAst as })

drawText :: EngineState -> AppState -> IO ()
drawText es appState =
  do
    renderText 0 0 (textRenderer es) (programText appState)
    renderTextbuffer (textRenderer es)

drawScene :: EngineState -> Scene -> IO ()
drawScene gs scene =
  do
    let post = postFX gs
    usePostProcessing post

    frontFace $= CCW
    cullFace $= Just Back
    depthFunc $= Just Less
    blend $= Enabled
    blendEquationSeparate $= (FuncAdd, FuncAdd)
    blendFuncSeparate $= ((SrcAlpha, OneMinusSrcAlpha), (One, Zero))
    clearColor $= sceneBackground scene
    clear [ ColorBuffer, DepthBuffer ]
    evalStateT (Gfx.interpretGfx $ Gfx.sceneGfx scene) gs

    renderPostProcessing post $ scenePostProcessingFX scene

