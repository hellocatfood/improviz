{-# LANGUAGE TemplateHaskell #-}

module Improviz.Language where

import           Language                   (initialState, parse)
import           Language.Ast               (Program (..))
import           Language.Interpreter.Types (InterpreterState)
import           Lens.Simple

data ImprovizLanguage = ImprovizLanguage
  { _programText        :: String
  , _lastProgramText    :: String
  , _currentAst         :: Program
  , _lastWorkingAst     :: Program
  , _initialInterpreter :: InterpreterState
  }

makeLenses ''ImprovizLanguage

makeLanguageState :: ImprovizLanguage
makeLanguageState =
  ImprovizLanguage
    { _programText = ""
    , _lastProgramText = ""
    , _currentAst = Program []
    , _lastWorkingAst = Program []
    , _initialInterpreter = initialState []
    }

updateProgram :: String -> Program -> ImprovizLanguage -> ImprovizLanguage
updateProgram newProgram newAst =
  set programText newProgram . set currentAst newAst

resetProgram :: ImprovizLanguage -> ImprovizLanguage
resetProgram as =
  let oldAst = view lastWorkingAst as
      oldText = view lastProgramText as
   in set programText oldText $ set currentAst oldAst as

saveProgram :: ImprovizLanguage -> ImprovizLanguage
saveProgram as =
  let ast = view currentAst as
      text = view programText as
   in set lastWorkingAst ast $ set lastProgramText text as

programHasChanged :: ImprovizLanguage -> Bool
programHasChanged as = as ^. currentAst /= as ^. lastWorkingAst

updateInterpreterState ::
     (InterpreterState -> InterpreterState)
  -> ImprovizLanguage
  -> ImprovizLanguage
updateInterpreterState = over initialInterpreter
