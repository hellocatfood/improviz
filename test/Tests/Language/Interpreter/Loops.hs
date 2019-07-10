module Tests.Language.Interpreter.Loops
  ( loopTests
  )
where

import           Test.Framework                 ( Test
                                                , testGroup
                                                )
import           Test.Framework.Providers.HUnit ( testCase )
import           Test.HUnit                     ( Assertion )
import           TestHelpers.Util               ( gfxTest )

import qualified Gfx.Ast                       as GA

loopTests :: Test
loopTests =
  testGroup "Language Tests" [testCase "Loop program" test_loop_program]

test_loop_program :: Assertion
test_loop_program =
  let
    program
      = "matrix(:rotate, 0.1, 0.2, 0.3)\n3 times with i\n\tmatrix(:rotate, 0.2, 0.2, 0.2)\n\tshape(:cube, i, i, i)\n\n\n"
    expectedGfx =
      [ GA.MatrixCommand (GA.Rotate 0.1 0.2 0.3)
      , GA.MatrixCommand (GA.Rotate 0.2 0.2 0.2)
      , GA.ShapeCommand (GA.Cube 0 0 0)
      , GA.MatrixCommand (GA.Rotate 0.2 0.2 0.2)
      , GA.ShapeCommand (GA.Cube 1 1 1)
      , GA.MatrixCommand (GA.Rotate 0.2 0.2 0.2)
      , GA.ShapeCommand (GA.Cube 2 2 2)
      ]
  in
    gfxTest program expectedGfx
