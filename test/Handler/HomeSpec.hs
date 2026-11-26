{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}
module Handler.HomeSpec (spec) where

import TestImport

spec :: Spec
spec = withApp $ do
    describe "Homepage" $ do
        it "carrega a pagina inicial" $ do
            get HomeR
            statusIs 200
            htmlAnyContain "h1" "Equipamentos de hockey no gelo"
