module Tests.Language (languageTests) where

import Test.Framework (Test, testGroup)
import Test.HUnit (Assertion, assertEqual)
import Test.Framework.Providers.HUnit (testCase)

import Data.Either
import Data.Maybe
import Data.Map.Strict
import Control.Monad.State.Strict
import Control.Monad.Writer.Strict
import Control.Monad.Except

import qualified Gfx.Ast as GA
import Gfx (Scene(..))
import Gfx.PostProcessing(AnimationStyle(..))

import qualified Language
import Language.LanguageAst
import Language.Interpreter


languageTests :: Test
languageTests =
  testGroup "Language Tests" [
    testCase "Graphics Creation" test_create_gfx,
    testCase "Animation Style Setting" test_animation_style,
    testCase "Basic program" test_basic_program,
    testCase "Loop program" test_loop_program
  ]

test_basic_program :: Assertion
test_basic_program =
  let
    program = "a = 2\nb = 3\nfoo = (c, d) => c * d\nbox(b, a, foo(a, b))\n"
    result = do
      ast <- Language.parse program
      scene <- fst $ Language.createGfx [] ast
      return $ sceneGfx scene
    expected = Right [GA.ShapeCommand (GA.Cube 3 2 6) Nothing]
  in
    assertEqual "" expected result

test_animation_style :: Assertion
test_animation_style =
  let
    program = "motionBlur()"
    result = do
      ast <- Language.parse program
      scene <- fst $ Language.createGfx [] ast
      return $ scenePostProcessingFX scene
    expected = Right MotionBlur
  in
    assertEqual "" expected result

test_loop_program :: Assertion
test_loop_program =
  let
    program = "rotate(0.1, 0.1, 0.1)\n3 times with i\n\trotate(0.2, 0.2, 0.2)\n\tbox(i)\n\n\n"
    result = do
      ast <- Language.parse program
      scene <- fst $ Language.createGfx [] ast
      return $ sceneGfx scene
    expected = Right [
      GA.MatrixCommand (GA.Rotate 0.1 0.1 0.1) Nothing,
      GA.MatrixCommand (GA.Rotate 0.2 0.2 0.2) Nothing,
      GA.ShapeCommand (GA.Cube 0 1 1) Nothing,
      GA.MatrixCommand (GA.Rotate 0.2 0.2 0.2) Nothing,
      GA.ShapeCommand (GA.Cube 1 1 1) Nothing,
      GA.MatrixCommand (GA.Rotate 0.2 0.2 0.2) Nothing,
      GA.ShapeCommand (GA.Cube 2 1 1) Nothing
      ]
  in
    assertEqual "" expected result

test_create_gfx :: Assertion
test_create_gfx =
  let
    box = EApp $ Application "box" [EVal $ Number 1, EVal $ Number 2, EVal $ Number 1] Nothing
    block = Block [ElExpression box]
    scene = fst $ Language.createGfx [] block :: Either String Scene
    result = either (const []) sceneGfx scene
    expected = [GA.ShapeCommand (GA.Cube 1 2 1) Nothing]
  in
    assertEqual "" expected result
