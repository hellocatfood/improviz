module Language.Ast.Transformers where

import           Control.Monad
import           Control.Monad.Trans.State.Strict
import qualified Data.Maybe                       as M
import           Data.Set                         (Set (..))
import qualified Data.Set                         as S

import           Language.Ast

newtype InliningState = InliningState
  { globalVars :: Set String
  }

type Transformer = State InliningState

localState :: (s -> s) -> State s a -> State s a
localState f ls = gets (\st -> (evalState ls) (f st))

globalise :: Set String -> Program -> Program
globalise globals p = evalState (globaliseProgram p) (InliningState globals)

globaliseProgram :: Program -> Transformer Program
globaliseProgram (Program statements) =
  Program <$> mapM globaliseStatement statements

globaliseStatement :: Statement -> Transformer Statement
globaliseStatement (StLoop loop) = StLoop <$> globaliseLoop loop
globaliseStatement (StAssign assignment) =
  StAssign <$> globaliseAssignment assignment
globaliseStatement (StExpression expression) =
  StExpression <$> globaliseExpression expression
globaliseStatement (StIf ifAst) = StIf <$> globaliseIf ifAst
globaliseStatement (StFunc func) = StFunc <$> globaliseFunc func

globaliseBlock :: Set String -> Block -> Transformer Block
globaliseBlock newVars (Block elements) = do
  Block <$>
    localState
      (\st -> st {globalVars = S.difference (globalVars st) newVars})
      (mapM globaliseElement elements)

globaliseElement :: Element -> Transformer Element
globaliseElement (ElLoop loop) = ElLoop <$> globaliseLoop loop
globaliseElement (ElAssign assignment) =
  ElAssign <$> globaliseAssignment assignment
globaliseElement (ElExpression expression) =
  ElExpression <$> globaliseExpression expression
globaliseElement (ElIf ifAst) = ElIf <$> globaliseIf ifAst

globaliseLoop :: Loop -> Transformer Loop
globaliseLoop (Loop expr mbId block) = do
  newExpr <- globaliseExpression expr
  let mbVar = maybe S.empty S.singleton mbId
  newBlock <- globaliseBlock mbVar block
  return $ Loop newExpr mbId newBlock

globaliseAssignment :: Assignment -> Transformer Assignment
globaliseAssignment (AbsoluteAssignment ident expr) = do
  newExpr <- globaliseExpression expr
  modify
    (\st -> st {globalVars = S.difference (globalVars st) (S.singleton ident)})
  return $ AbsoluteAssignment ident newExpr
globaliseAssignment (ConditionalAssignment ident expr) = do
  newExpr <- globaliseExpression expr
  modify
    (\st -> st {globalVars = S.difference (globalVars st) (S.singleton ident)})
  return $ ConditionalAssignment ident newExpr

globaliseExpression :: Expression -> Transformer Expression
globaliseExpression (EApp application) =
  EApp <$> globaliseApplication application
globaliseExpression (BinaryOp op expr1 expr2) = do
  BinaryOp op <$> globaliseExpression expr1 <*> globaliseExpression expr2
globaliseExpression (UnaryOp op expr1) = do
  UnaryOp op <$> globaliseExpression expr1
globaliseExpression (EVar variable) = EVar <$> globaliseVariable variable
globaliseExpression (EVal value) = EVal <$> globaliseValue value

globaliseIf :: If -> Transformer If
globaliseIf (If predicate block elseBlock) = do
  newPred <- globaliseExpression predicate
  newBlock <- globaliseBlock S.empty block
  newElse <- mapM (globaliseBlock S.empty) elseBlock
  return $ If newPred newBlock newElse

globaliseFunc :: Func -> Transformer Func
globaliseFunc (Func name argNames block)
  -- TODO global name for name?
 = do
  newBlock <- globaliseBlock (S.fromList argNames) block
  return $ Func name argNames newBlock

globaliseApplication :: Application -> Transformer Application
globaliseApplication (Application name args mbBlock)
  -- TODO should application names actually be global vars?
 = do
  newArgs <- mapM globaliseExpression args
  newMbBlock <- mapM (globaliseBlock S.empty) mbBlock
  return $ Application name newArgs newMbBlock

globaliseVariable :: Variable -> Transformer Variable
globaliseVariable v@(LocalVariable name) = do
  gets
    (\st ->
       if S.member name (globalVars st)
         then GlobalVariable name
         else v)
globaliseVariable globalVar = return globalVar

globaliseValue :: Value -> Transformer Value
globaliseValue = return
