module Tests.Language.Interpreter.If
  ( interpreterIfTests
  )
where

import           Test.Framework                 ( Test
                                                , testGroup
                                                )
import           Test.Framework.Providers.HUnit ( testCase )
import           Test.HUnit                     ( Assertion )
import           TestHelpers.Util               ( gfxTest )

import qualified Gfx.Ast                       as GA

interpreterIfTests :: Test
interpreterIfTests = testGroup
  "If Tests"
  [ testCase "True single if statement"  test_true_if_statement
  , testCase "False single if statement" test_false_if_statement
  , testCase "True if else statement"    test_true_if_else_statement
  , testCase "False if else statement"   test_false_if_else_statement
  ]

test_true_if_statement :: Assertion
test_true_if_statement =
  let program     = "if (1)\n\tshape(:cube, 1, 1, 1)"
      expectedGfx = [GA.ShapeCommand (GA.Cube 1 1 1)]
  in  gfxTest program expectedGfx

test_false_if_statement :: Assertion
test_false_if_statement =
  let program     = "if (0)\n\tshape(:cube, 1, 1, 1)"
      expectedGfx = []
  in  gfxTest program expectedGfx

test_true_if_else_statement :: Assertion
test_true_if_else_statement =
  let program     = "if (1)\n\tshape(:cube, 1, 1, 1)\nelse\n\tshape(:line, 1)"
      expectedGfx = [GA.ShapeCommand (GA.Cube 1 1 1)]
  in  gfxTest program expectedGfx

test_false_if_else_statement :: Assertion
test_false_if_else_statement =
  let program     = "if (0)\n\tshape(:cube, 1, 1, 1)\nelse\n\tshape(:line, 1)"
      expectedGfx = [GA.ShapeCommand (GA.Line 1)]
  in  gfxTest program expectedGfx
