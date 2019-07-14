module Tests.Language.Interpreter.Expressions
  ( interpreterExpressionTests
  )
where

import           Test.Framework                 ( Test
                                                , testGroup
                                                )
import           Test.Framework.Providers.HUnit ( testCase )
import           Test.HUnit                     ( Assertion )
import           TestHelpers.Util               ( resultTest )

import           Language.Ast

interpreterExpressionTests :: Test
interpreterExpressionTests = testGroup
  "Expression Tests"
  [testCase "interprets number expression" test_number_expression]

test_number_expression :: Assertion
test_number_expression =
  let program  = "3"
      expected = Number 3
  in  resultTest program expected "expected 3 result"
