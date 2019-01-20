module Main where

import           GHC.Float              (double2Float)
import           System.Exit            (exitSuccess)

import           Control.Concurrent.STM (atomically, modifyTVar, putTMVar,
                                         readTMVar, readTVarIO, takeTMVar,
                                         writeTVar)
import           Control.Monad          (when)
import qualified Data.Map.Strict        as M
import           Data.Maybe             (fromMaybe)

import           Lens.Simple            ((^.))

import qualified Graphics.UI.GLFW       as GLFW

import qualified Configuration          as C
import qualified Configuration.Font     as CF
import qualified Configuration.OSC      as CO
import qualified Configuration.Screen   as CS
import           Improviz               (ImprovizEnv, ImprovizError (..))
import qualified Improviz               as I
import qualified Improviz.Language      as IL
import qualified Improviz.UI            as IUI

import           Gfx                    (EngineState (..), createGfxEngineState,
                                         renderGfx)
import           Gfx.Matrices           (projectionMat, vec3, viewMat)
import           Gfx.PostProcessing     (createPostProcessing,
                                         deletePostProcessing,
                                         renderPostProcessing,
                                         usePostProcessing)
import           Gfx.TextRendering      (TextRenderer, addCodeTextureToLib,
                                         createTextRenderer, renderCode,
                                         renderCodebuffer,
                                         resizeTextRendererScreen)
import           Gfx.Textures           (addTexture, createTextureLib)
import           Gfx.Windowing          (setupWindow)
import           Language               (copyRNG, copyRNG, createGfx,
                                         updateEngineInfo, updateStateVariables)
import           Language.Ast           (Value (Number))
import           Language.Interpreter   (setRNG)
import           Logging                (logError, logInfo)
import           Server                 (serveComs)

import           Util                   ((/.))

main :: IO ()
main = I.createEnv >>= app

app :: ImprovizEnv -> IO ()
app env =
  let initCallback = initApp env
      resizeCallback = resize env
      displayCallback = display env
   in do serveComs env
         setupWindow env initCallback resizeCallback displayCallback

initApp :: ImprovizEnv -> Int -> Int -> IO ()
initApp env width height =
  let ratio = width /. height
      front = env ^. I.config . C.screen . CS.front
      back = env ^. I.config . C.screen . CS.back
      proj = projectionMat front back (pi / 4) ratio
      view = viewMat (vec3 0 0 10) (vec3 0 0 0) (vec3 0 1 0)
   in do post <- createPostProcessing width height
         textRenderer <-
           createTextRenderer (env ^. I.config) front back width height
         textureLib <- createTextureLib (env ^. I.config . C.textureDirectories)
         let tLibWithCode = addCodeTextureToLib textRenderer textureLib
         gfxEngineState <-
           createGfxEngineState proj view post textRenderer tLibWithCode
         atomically $ do
           putTMVar (env ^. I.graphics) gfxEngineState
           modifyTVar
             (env ^. I.language)
             (IL.updateInterpreterState (updateEngineInfo gfxEngineState))

resize :: ImprovizEnv -> GLFW.WindowSizeCallback
resize env window newWidth newHeight = do
  logInfo "Resizing"
  (fbWidth, fbHeight) <- GLFW.getFramebufferSize window
  let front = env ^. I.config . C.screen . CS.front
      back = env ^. I.config . C.screen . CS.back
      newRatio = fbWidth /. fbHeight
      newProj = projectionMat front back (pi / 4) newRatio
  engineState <- atomically $ readTMVar (env ^. I.graphics)
  deletePostProcessing $ postFX engineState
  newPost <- createPostProcessing fbWidth fbHeight
  newTrender <-
    resizeTextRendererScreen
      front
      back
      fbWidth
      fbHeight
      (textRenderer engineState)
  atomically $ do
    es <- takeTMVar (env ^. I.graphics)
    putTMVar
      (env ^. I.graphics)
      es
        { projectionMatrix = newProj
        , postFX = newPost
        , textRenderer = newTrender
        }

display :: ImprovizEnv -> Double -> IO ()
display env time = do
  as <- readTVarIO (env ^. I.language)
  vars <- readTVarIO (env ^. I.externalVars)
  let newVars = ("time", Number $ double2Float time) : M.toList vars
      interpreterState =
        updateStateVariables newVars (as ^. IL.initialInterpreter)
      ((result, logs), nextState) =
        createGfx interpreterState (as ^. IL.currentAst)
  case result of
    Left msg -> do
      logError $ "Could not interpret program: " ++ msg
      atomically $ modifyTVar (env ^. I.language) IL.resetProgram
    Right scene -> do
      gs <- atomically $ readTMVar (env ^. I.graphics)
      ui <- readTVarIO $ env ^. I.ui
      when (IL.programHasChanged as) $ do
        logInfo "Saving current ast"
        renderCode 0 0 (textRenderer gs) (ui ^. IUI.currentText)
        atomically $ modifyTVar (env ^. I.language) IL.saveProgram
      renderGfx gs scene
      when (ui ^. IUI.displayText) $ do
        renderCode 0 0 (textRenderer gs) (ui ^. IUI.currentText)
        renderCodebuffer (textRenderer gs)
  atomically $
    modifyTVar
      (env ^. I.language)
      (IL.updateInterpreterState (copyRNG nextState))
