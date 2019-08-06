module Language.Interpreter.StdLib.Util
  ( addUtilStdLib
  )
where

import           Control.Monad.Trans            ( liftIO )
import           Control.Monad.Except           ( throwError )
import           System.Random                  ( random
                                                , mkStdGen
                                                )

import           Lens.Simple                    ( use
                                                , assign
                                                )
import           Language.Ast
import           Language.Interpreter           ( getExternal
                                                , setBuiltIn
                                                )
import           Language.Interpreter.Types
import           Language.Interpreter.Values

addUtilStdLib :: InterpreterProcess ()
addUtilStdLib = do
  setBuiltIn "isNull"     isNullFunc
  setBuiltIn "ext"        getExtFunc
  setBuiltIn "length"     lengthFunc
  setBuiltIn "random"     randomFunc
  setBuiltIn "randomSeed" randomSeedFunc

isNullFunc :: [Value] -> InterpreterProcess Value
isNullFunc args = case args of
  []      -> throwError "Need to provide isNull with argument"
  arg : _ -> return $ if valIsNull arg then Number 1 else Number 0

getExtFunc :: [Value] -> InterpreterProcess Value
getExtFunc args = case args of
  Symbol name : defaultValue : _ -> getExternal name defaultValue
  [Symbol name] -> getExternal name Null
  _ -> throwError "Need to provide ext with a name"

lengthFunc :: [Value] -> InterpreterProcess Value
lengthFunc args = case args of
  VList elems : _ -> return $ Number $ fromIntegral $ length elems
  _               -> throwError "Must give length a list"

randomFunc :: [Value] -> InterpreterProcess Value
randomFunc _ = do
  (v, newRng) <- random <$> use rnGen
  assign rnGen newRng
  liftIO $ print v
  return $ Number v

randomSeedFunc :: [Value] -> InterpreterProcess Value
randomSeedFunc args = case args of
  Number seed : _ -> do
    assign rnGen (mkStdGen $ round seed)
    return Null
  _ -> throwError "Must give a number argument for seed function"
