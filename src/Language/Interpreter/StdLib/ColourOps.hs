module Language.Interpreter.StdLib.ColourOps
  ( addColourStdLib
  )
where

import           Control.Monad.Except
import           Data.Maybe                     ( maybe
                                                , listToMaybe
                                                )

import           Gfx.Context                    ( textureFill
                                                , colourFill
                                                , noFill
                                                , colourStroke
                                                , noStroke
                                                , setStrokeSize
                                                , setMaterial
                                                , setBackground
                                                )
import           Language.Ast                   ( Value(Number, Null, Symbol) )
import           Language.Interpreter           ( useGfxCtx
                                                , getTextureInfo
                                                , setBuiltIn
                                                )
import           Language.Interpreter.Types     ( InterpreterProcess )
import           Language.Interpreter.Values    ( getNumberValue )

addColourStdLib :: InterpreterProcess ()
addColourStdLib = do
  setBuiltIn "frames"     frames
  setBuiltIn "background" background
  setBuiltIn "style"      style

dToC :: Float -> Float
dToC c = max 0 (min c 255) / 255

frames :: [Value] -> InterpreterProcess Value
frames args = case args of
  [Symbol name] -> do
    symbolFrames <- getTextureInfo name
    return $ case symbolFrames of
      Nothing -> Null
      Just v  -> Number (fromIntegral v)
  _ -> return Null

background :: [Value] -> InterpreterProcess Value
background args = do
  (rVal, gVal, bVal) <- case args of
    []                             -> return (255, 255, 255)
    [Number x]                     -> return (x, x, x)
    [Number x, Number y]           -> return (x, y, 0)
    [Number x, Number y, Number z] -> return (x, y, z)
    _ -> throwError "Error with functions to background"
  useGfxCtx (\ctx -> setBackground ctx (dToC rVal) (dToC gVal) (dToC bVal))
  return Null


style :: [Value] -> InterpreterProcess Value
style styleArgs = do
  cmd <- case styleArgs of
    Symbol "fill"       : rest -> runFill rest
    Symbol "noFill"     : rest -> useGfxCtx noFill
    Symbol "stroke"     : rest -> runStroke rest
    Symbol "noStroke"   : rest -> useGfxCtx noStroke
    Symbol "strokeSize" : rest -> runStrokeSize rest
    Symbol "texture"    : rest -> runTexture rest
    Symbol "material"   : rest -> runMaterial rest
  return Null
 where
  runFill :: [Value] -> InterpreterProcess ()
  runFill args = case args of
    [Number r, Number g, Number b, Number a] ->
      useGfxCtx (\ctx -> colourFill ctx (dToC r) (dToC g) (dToC b) (dToC a))
    _ -> throwError "Error with functions to fill"
  runStroke :: [Value] -> InterpreterProcess ()
  runStroke args = case args of
    [Number r, Number g, Number b, Number a] ->
      useGfxCtx (\ctx -> colourStroke ctx (dToC r) (dToC g) (dToC b) (dToC a))
    _ -> throwError "Error with functions to fill"
  runStrokeSize :: [Value] -> InterpreterProcess ()
  runStrokeSize args = case args of
    [Number sSize] -> useGfxCtx (\ctx -> setStrokeSize ctx sSize)
    _              -> throwError "Error with functions to strokeSize"
  runTexture :: [Value] -> InterpreterProcess ()
  runTexture args = case args of
    Symbol name : rest -> do
      frame <- maybe (return 0) getNumberValue $ listToMaybe rest
      useGfxCtx (\ctx -> textureFill ctx name frame)
    _ -> throwError "Error with functions to texture"
  runMaterial :: [Value] -> InterpreterProcess ()
  runMaterial args = case args of
    [Symbol name] -> do
      useGfxCtx (\ctx -> setMaterial ctx name)
    _ -> throwError "Error with functions to material"
