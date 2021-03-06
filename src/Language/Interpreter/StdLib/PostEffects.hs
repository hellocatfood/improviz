module Language.Interpreter.StdLib.PostEffects
  ( addPostEffectsStdLib
  )
where

import           Gfx.PostProcessing             ( AnimationStyle(..) )

import           Language.Ast                   ( Value(Symbol, Null) )
import           Gfx.Context                    ( setAnimationStyle )
import           Language.Interpreter.Types     ( InterpreterProcess
                                                , setBuiltIn
                                                , withGfxCtx
                                                )

addPostEffectsStdLib :: InterpreterProcess ()
addPostEffectsStdLib = do
  setBuiltIn "paintOver"      paintOver
  setBuiltIn "motionBlur"     motionBlur
  setBuiltIn "animationStyle" animationStyle

motionBlur :: [Value] -> InterpreterProcess Value
motionBlur _ = withGfxCtx (`setAnimationStyle` MotionBlur) >> return Null

paintOver :: [Value] -> InterpreterProcess Value
paintOver _ = withGfxCtx (`setAnimationStyle` PaintOver) >> return Null

animationStyle :: [Value] -> InterpreterProcess Value
animationStyle args = do
  case args of
    [Symbol "paintOver" ] -> withGfxCtx (`setAnimationStyle` PaintOver)
    [Symbol "motionBlur"] -> withGfxCtx (`setAnimationStyle` MotionBlur)
    _                     -> withGfxCtx (`setAnimationStyle` NormalStyle)
  return Null
