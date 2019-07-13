module Tests.Language.Parser.Lists
  ( parserListTests
  )
where

import           Test.Framework                 ( Test
                                                , testGroup
                                                )
import           Test.Framework.Providers.HUnit ( testCase )
import           Test.HUnit                     ( Assertion )
import           TestHelpers.Util               ( parserTest )

import           Language.Ast

parserListTests :: Test
parserListTests = testGroup
  "Parser List Tests"
  [ testCase "Parses a list value"     test_list_parsing
  , testCase "Parses accessing a list" test_accessor_parsing
  , testCase "Parses nested lists"     test_nested_list_parsing
  , testCase "Parses nested accessing" test_nested_accessing_parsing
  ]

test_list_parsing :: Assertion
test_list_parsing =
  let program  = "a = [1, 2, 3]"
      list     = EList [EVal $ Number 1, EVal $ Number 2, EVal $ Number 3]
      expected = Program [StAssign $ AbsoluteAssignment "a" list]
  in  parserTest program expected

test_accessor_parsing :: Assertion
test_accessor_parsing =
  let program = "a = [1,2,3]\nb = a[2 + 1]"
      list    = EList [EVal $ Number 1, EVal $ Number 2, EVal $ Number 3]
      access  = EAccess (EVar $ LocalVariable "a")
                        (BinaryOp "+" (EVal $ Number 2) (EVal $ Number 1))
      expected = Program
        [ StAssign $ AbsoluteAssignment "a" list
        , StAssign $ AbsoluteAssignment "b" access
        ]
  in  parserTest program expected

test_nested_list_parsing :: Assertion
test_nested_list_parsing =
  let program = "a = [1, [[1, 2], [3, 4]]]"
      list    = EList
        [ EVal $ Number 1
        , EList
          [ EList [EVal $ Number 1, EVal $ Number 2]
          , EList [EVal $ Number 3, EVal $ Number 4]
          ]
        ]
      expected = Program [StAssign $ AbsoluteAssignment "a" list]
  in  parserTest program expected

test_nested_accessing_parsing :: Assertion
test_nested_accessing_parsing =
  let program = "a = [1, [[1, 2], [3, 4]]][0][1][2]"
      list    = EList
        [ EVal $ Number 1
        , EList
          [ EList [EVal $ Number 1, EVal $ Number 2]
          , EList [EVal $ Number 3, EVal $ Number 4]
          ]
        ]
      accessor = EAccess
        (EAccess (EAccess list (EVal $ Number 0)) (EVal $ Number 1))
        (EVal $ Number 2)
      expected = Program [StAssign $ AbsoluteAssignment "a" accessor]
  in  parserTest program expected
