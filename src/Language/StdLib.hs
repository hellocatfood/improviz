module Language.StdLib (noop, module Ops) where

import Language.StdLib.Shapes as Ops
import Language.StdLib.MatrixOps as Ops
import Language.StdLib.ColourOps as Ops
import Language.StdLib.PostEffects as Ops

import Language.Interpreter.Types (BuiltInFunction)
import Language.LanguageAst ( Value(Null) )

noop :: BuiltInFunction
noop _ = return Null
