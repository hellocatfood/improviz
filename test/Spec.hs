module Main where

import           Data.Monoid                    ( mempty )

import           Test.Framework

import           Tests.Language.Ast.Transformers.Globalise
                                                ( transformersGlobaliseTests )
import           Tests.Language.Interpreter     ( interpreterTests )
import           Tests.Language.Parser          ( parserTests )

import           Tests.Language.VM              ( vmTests )

main :: IO ()
main = defaultMainWithOpts
  [transformersGlobaliseTests, interpreterTests, parserTests, vmTests]
  mempty
