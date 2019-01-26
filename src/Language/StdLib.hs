module Language.StdLib
  ( addStdLib
  ) where

import           Language.StdLib.BlockHandling (addBlockHandlingStdLib)
import           Language.StdLib.ColourOps     (addColourStdLib)
import           Language.StdLib.Maths         (addMathStdLib)
import           Language.StdLib.MatrixOps     (addMatrixStdLib)
import           Language.StdLib.PostEffects   (addPostEffectsStdLib)
import           Language.StdLib.Shapes        (addShapesStdLib)

import           Language.Ast                  (Value (Null))
import           Language.Interpreter          (setBuiltIn)
import           Language.Interpreter.Types    (BuiltInFunction,
                                                InterpreterProcess)

addStdLib :: InterpreterProcess ()
addStdLib = do
  addMathStdLib
  addShapesStdLib
  addMatrixStdLib
  addColourStdLib
  addPostEffectsStdLib
  addBlockHandlingStdLib
