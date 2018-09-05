module Tests.Language.Parser.Assignment
  ( parserAssignmentTests
  ) where

import           Test.Framework                 (Test, testGroup)
import           Test.Framework.Providers.HUnit (testCase)
import           Test.HUnit                     (Assertion, assertEqual)

import qualified Language
import           Language.Ast

parserAssignmentTests :: Test
parserAssignmentTests =
  testGroup
    "Parser Assignment Tests"
    [ testCase "Parse simple number assignment" test_parse_assign_simple_number
    , testCase
        "Parse negative number assignment"
        test_parse_assign_negative_number
    , testCase "Parse assignment of an expression" test_parse_expr_assignment
    , testCase "Parse assignment of a list" test_parse_list_assignment
    , testCase "Parse multiple assignments" test_multiple_assignment
    , testCase "Parse conditional assignments" test_multiple_assignment
    ]

test_parse_assign_simple_number :: Assertion
test_parse_assign_simple_number =
  let program = "a = 1"
      assignment = AbsoluteAssignment "a" (EVal $ Number 1)
      expected = Right $ Block [ElAssign assignment]
      result = Language.parse program
   in assertEqual "" expected result

test_parse_assign_negative_number :: Assertion
test_parse_assign_negative_number =
  let program = "a = -444"
      assignment = AbsoluteAssignment "a" (UnaryOp "-" (EVal $ Number 444))
      expected = Right $ Block [ElAssign assignment]
      result = Language.parse program
   in assertEqual "" expected result

test_parse_expr_assignment :: Assertion
test_parse_expr_assignment =
  let program = "foo = a + b\n"
      bop = BinaryOp "+" (EVar $ Variable "a") (EVar $ Variable "b")
      expected = Right $ Block [ElAssign $ AbsoluteAssignment "foo" bop]
      result = Language.parse program
   in assertEqual "" expected result

test_parse_list_assignment :: Assertion
test_parse_list_assignment =
  let program = "foo = [1, 2]\n"
      list = EVal $ VList [EVal $ Number 1, EVal $ Number 2]
      expected = Right $ Block [ElAssign $ AbsoluteAssignment "foo" list]
      result = Language.parse program
   in assertEqual "" expected result

test_multiple_assignment :: Assertion
test_multiple_assignment =
  let program = "foo = 1 + 2\nbar = foo - 2\nbaz = foo * bar\n"
      bop1 = BinaryOp "+" (EVal $ Number 1) (EVal $ Number 2)
      foo = ElAssign $ AbsoluteAssignment "foo" bop1
      bop2 = BinaryOp "-" (EVar $ Variable "foo") (EVal $ Number 2)
      bar = ElAssign $ AbsoluteAssignment "bar" bop2
      bop3 = BinaryOp "*" (EVar $ Variable "foo") (EVar $ Variable "bar")
      baz = ElAssign $ AbsoluteAssignment "baz" bop3
      expected = Right $ Block [foo, bar, baz]
      result = Language.parse program
   in assertEqual "" expected result

test_parse_absolute_assignment :: Assertion
test_parse_absolute_assignment =
  let program = "foo := a + b\n"
      bop = BinaryOp "+" (EVar $ Variable "a") (EVar $ Variable "b")
      expected = Right $ Block [ElAssign $ ConditionalAssignment "foo" bop]
      result = Language.parse program
   in assertEqual "" expected result
