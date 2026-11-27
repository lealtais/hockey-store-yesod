{-# LANGUAGE OverloadedStrings #-}
module ViaCEPSpec (spec) where

import Api.ViaCEP (normalizarCep)
import TestImport

spec :: Spec
spec =
    describe "normalizarCep" $ do
        it "accepts eight digits with or without a hyphen" $ do
            normalizarCep "01001000" `shouldBe` Just "01001000"
            normalizarCep "01001-000" `shouldBe` Just "01001000"
        it "rejects values that do not contain exactly eight digits" $ do
            normalizarCep "123" `shouldBe` Nothing
            normalizarCep "01001-0000" `shouldBe` Nothing
