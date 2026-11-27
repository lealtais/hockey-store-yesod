{-# LANGUAGE OverloadedStrings #-}
module SeedSpec (spec) where

import Database.Persist.Sql (runSqlPool)
import Seed (semear)
import TestImport

spec :: Spec
spec = withApp $ do
    describe "seed de demonstração" $ do
        it "insere os dados de hockey sem duplicar em inicializações repetidas" $ do
            app <- getTestYesod
            liftIO $ runSqlPool semear (appConnPool app)
            categorias <- runDB $ count ([] :: [Filter Categoria])
            marcas <- runDB $ count ([] :: [Filter Marca])
            quantidadeProdutos <- runDB $ count ([] :: [Filter Produto])
            produtos <- runDB $ selectList [] [Asc ProdutoNome]
            liftIO $ runSqlPool semear (appConnPool app)
            countCategorias <- runDB $ count ([] :: [Filter Categoria])
            countMarcas <- runDB $ count ([] :: [Filter Marca])
            countProdutos <- runDB $ count ([] :: [Filter Produto])
            let precosNexus =
                    [ produtoPreco produto
                    | Entity _ produto <- produtos
                    , produtoNome produto == "Taco Bauer Nexus"
                    ]
            liftIO $ do
                categorias `shouldBe` 5
                marcas `shouldBe` 4
                quantidadeProdutos `shouldBe` 7
                countCategorias `shouldBe` categorias
                countMarcas `shouldBe` marcas
                countProdutos `shouldBe` quantidadeProdutos
                precosNexus `shouldBe` [129990]
