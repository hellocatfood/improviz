module Language.StdLib.Shapes
  ( addShapesStdLib
  ) where

import           Control.Monad.Except

import qualified Gfx.Ast                     as GA
import           Language.Ast
import           Language.Interpreter        (addGfxCommand, getBlock,
                                              getVarOrNull,
                                              getVariableWithDefault,
                                              gfxScopedBlock, setBuiltIn)
import           Language.Interpreter.Types
import           Language.Interpreter.Values

addShapesStdLib :: InterpreterProcess ()
addShapesStdLib = do
  setBuiltIn "box" box ["a", "b", "c"]
  setBuiltIn "sphere" sphere ["a", "b", "c"]
  setBuiltIn "cylinder" cylinder ["a", "b", "c"]
  setBuiltIn "rectangle" rectangle ["a", "b"]
  setBuiltIn "line" line ["a"]

box :: InterpreterProcess Value
box = do
  a <- getVarOrNull "a"
  b <- getVarOrNull "b"
  c <- getVarOrNull "c"
  (xSize, ySize, zSize) <-
    case (a, b, c) of
      (Null, Null, Null) -> return (1, 1, 1)
      (Number x, Null, Null) -> return (x, x, x)
      (Number x, Number y, Null) -> return (x, y, 1)
      (Number x, Number y, Number z) -> return (x, y, z)
      _ -> throwError "Error with arguments to box"
  let cmd = GA.ShapeCommand $ GA.Cube xSize ySize zSize
  block <- getBlock
  maybe (addGfxCommand cmd) (gfxScopedBlock cmd) block
  return Null

sphere :: InterpreterProcess Value
sphere = do
  a <- getVarOrNull "a"
  b <- getVarOrNull "b"
  c <- getVarOrNull "c"
  (xSize, ySize, zSize) <-
    case (a, b, c) of
      (Null, Null, Null) -> return (1, 1, 1)
      (Number x, Null, Null) -> return (x, x, x)
      (Number x, Number y, Null) -> return (x, y, 1)
      (Number x, Number y, Number z) -> return (x, y, z)
      _ -> throwError "Error with arguments to sphere"
  let cmd = GA.ShapeCommand $ GA.Cube xSize ySize zSize
  block <- getBlock
  maybe (addGfxCommand cmd) (gfxScopedBlock cmd) block
  return Null

cylinder :: InterpreterProcess Value
cylinder = do
  a <- getVarOrNull "a"
  b <- getVarOrNull "b"
  c <- getVarOrNull "c"
  (xSize, ySize, zSize) <-
    case (a, b, c) of
      (Null, Null, Null) -> return (1, 1, 1)
      (Number x, Null, Null) -> return (x, x, x)
      (Number x, Number y, Null) -> return (x, y, 1)
      (Number x, Number y, Number z) -> return (x, y, z)
      _ -> throwError "Error with arguments to cylinder"
  let cmd = GA.ShapeCommand $ GA.Cylinder xSize ySize zSize
  block <- getBlock
  maybe (addGfxCommand cmd) (gfxScopedBlock cmd) block
  return Null

rectangle :: InterpreterProcess Value
rectangle = do
  a <- getVarOrNull "a"
  b <- getVarOrNull "b"
  (xSize, ySize) <-
    case (a, b) of
      (Null, Null)         -> return (1, 1)
      (Number x, Null)     -> return (x, x)
      (Number x, Number y) -> return (x, y)
      _                    -> throwError "Error with arguments to rectangle"
  let cmd = GA.ShapeCommand $ GA.Rectangle xSize ySize
  block <- getBlock
  maybe (addGfxCommand cmd) (gfxScopedBlock cmd) block
  return Null

line :: InterpreterProcess Value
line = do
  l <- getVariableWithDefault "l" (Number 1) >>= getNumberValue
  let cmd = GA.ShapeCommand $ GA.Line l
  block <- getBlock
  maybe (addGfxCommand cmd) (gfxScopedBlock cmd) block
  return Null
