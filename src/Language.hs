module Language
  ( initialState
  , parse
  , simpleParse
  , interpret
  , updateStateVariables
  , setGfxContext
  , module Language.Ast
  )
where

import           Control.Monad                  ( forM_ )
import           Lens.Simple                    ( set )

import           Gfx.Context                    ( GfxContext )

import           Language.Ast                   ( Identifier
                                                , Program
                                                , Value(..)
                                                )
import           Language.Ast.Transformers      ( transform )
import           Language.Interpreter           ( emptyState
                                                , getGlobalNames
                                                , interpretLanguage
                                                , setVariable
                                                )
import           Language.Interpreter.Types     ( InterpreterState
                                                , gfxContext
                                                , runInterpreterM
                                                )
import           Language.Parser                ( parseProgram )
import           Language.Parser.Errors         ( ParserError )
import           Language.StdLib                ( addStdLib )

parse :: String -> Either ParserError Program
parse = parseProgram

simpleParse :: String -> Either String Program
simpleParse code = case parseProgram code of
  Left  err -> Left $ show err
  Right ast -> Right ast

initialState :: [Program] -> IO InterpreterState
initialState userCode =
  let setup = do
        addStdLib
        globals <- getGlobalNames
        mapM (interpretLanguage . transform globals) userCode
  in  snd <$> runInterpreterM setup emptyState

updateStateVariables
  :: [(Identifier, Value)] -> InterpreterState -> IO InterpreterState
updateStateVariables vars oldState =
  let setVars = forM_ vars (uncurry setVariable)
  in  snd <$> runInterpreterM setVars oldState

setGfxContext :: GfxContext -> InterpreterState -> InterpreterState
setGfxContext = set gfxContext


interpret
  :: InterpreterState -> Program -> IO (Either String Value, InterpreterState)
interpret initialState program =
  let run = do
        globals <- getGlobalNames
        interpretLanguage (transform globals program)
  in  runInterpreterM run initialState
