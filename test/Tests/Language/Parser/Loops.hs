module Tests.Language.Parser.Loops
  ( parserLoopTests
  ) where

import           Test.Framework                 (Test, testGroup)
import           Test.Framework.Providers.HUnit (testCase)
import           Test.HUnit                     (Assertion, assertEqual)

import qualified Language
import           Language.Ast

parserLoopTests :: Test
parserLoopTests =
  testGroup
    "Parser Loop Tests"
    [ testCase "Parse simple loop" test_simple_loop
    , testCase "Parse loop with variable" test_loop_with_var
    , testCase "Parse loop with number expression" test_loop_with_expr_number
    , testCase
        "Parse loop with number expression and variable"
        test_loop_with_expr_number_and_loop_var
    ]

test_simple_loop :: Assertion
test_simple_loop =
  let program = "4 times\n\trotate()\n\tbox()\n"
      rot =
        ElExpression $ EApp $ Application (LocalVariable "rotate") [] Nothing
      box = ElExpression $ EApp $ Application (LocalVariable "box") [] Nothing
      loop = Loop (EVal $ Number 4) Nothing $ Block [rot, box]
      expected = Right $ Program [StLoop loop]
      result = Language.parse program
   in assertEqual "" expected result

test_loop_with_var :: Assertion
test_loop_with_var =
  let program = "4 times with i\n\trotate()\n\tbox(i, i, i)\n"
      rot =
        ElExpression $ EApp $ Application (LocalVariable "rotate") [] Nothing
      boxargs =
        [ EVar $ LocalVariable "i"
        , EVar $ LocalVariable "i"
        , EVar $ LocalVariable "i"
        ]
      box =
        ElExpression $ EApp $ Application (LocalVariable "box") boxargs Nothing
      loop = Loop (EVal $ Number 4) (Just "i") $ Block [rot, box]
      expected = Right $ Program [StLoop loop]
      result = Language.parse program
   in assertEqual "" expected result

test_loop_with_expr_number :: Assertion
test_loop_with_expr_number =
  let program = "(3 + 4) times\n\trotate()\n\tbox()\n"
      numExpr = BinaryOp "+" (EVal $ Number 3) (EVal $ Number 4)
      rot =
        ElExpression $ EApp $ Application (LocalVariable "rotate") [] Nothing
      box = ElExpression $ EApp $ Application (LocalVariable "box") [] Nothing
      loop = Loop numExpr Nothing $ Block [rot, box]
      expected = Right $ Program [StLoop loop]
      result = Language.parse program
   in assertEqual "" expected result

test_loop_with_expr_number_and_loop_var :: Assertion
test_loop_with_expr_number_and_loop_var =
  let program = "(5 * 2) times with i\n\trotate(i)\n\tbox(i)\n"
      numExpr = BinaryOp "*" (EVal $ Number 5) (EVal $ Number 2)
      rotArgs = [EVar $ LocalVariable "i"]
      rot =
        ElExpression $
        EApp $ Application (LocalVariable "rotate") rotArgs Nothing
      box =
        ElExpression $
        EApp $
        Application (LocalVariable "box") [EVar $ LocalVariable "i"] Nothing
      loop = Loop numExpr (Just "i") $ Block [rot, box]
      expected = Right $ Program [StLoop loop]
      result = Language.parse program
   in assertEqual "" expected result
