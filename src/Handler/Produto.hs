{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeFamilies #-}
module Handler.Produto where

import Data.Char (isDigit)
import qualified Data.Text as T
import Import

parseCentavos :: Text -> Either Text Int
parseCentavos raw =
    let s = T.strip raw
    in case T.uncons s of
        Nothing -> Left "Informe um preço válido (ex.: 899,90 ou 899.90)"
        Just ('-', resto) ->
            case parsePositivo resto of
                Right _ -> Left "O preço deve ser maior que zero"
                Left err -> Left err
        Just _ ->
            case parsePositivo s of
                Right c | c <= 0 -> Left "O preço deve ser maior que zero"
                Right c -> Right c
                Left err -> Left err
  where
    parsePositivo :: Text -> Either Text Int
    parsePositivo txt =
        let norm = T.replace "," "." txt
        in case T.splitOn "." norm of
            [reaisTxt]
                | not (T.null reaisTxt) && T.all isDigit reaisTxt ->
                    case readMay reaisTxt of
                        Just r -> Right (r * 100)
                        Nothing -> Left "Informe um preço válido (ex.: 899,90 ou 899.90)"
            [reaisTxt, centTxt]
                | not (T.null reaisTxt)
                  && T.all isDigit reaisTxt
                  && (T.length centTxt == 1 || T.length centTxt == 2)
                  && T.all isDigit centTxt ->
                    case (readMay reaisTxt, readMay centTxt) of
                        (Just r, Just c) ->
                            let cent = if T.length centTxt == 1 then c * 10 else c
                            in Right (r * 100 + cent)
                        _ -> Left "Informe um preço válido (ex.: 899,90 ou 899.90)"
            _ -> Left "Informe um preço válido (ex.: 899,90 ou 899.90)"

formatPrecoInput :: Int -> Text
formatPrecoInput centavos =
    let (reais, resto) = abs centavos `quotRem` 100
        centavosTxt = if resto < 10 then "0" <> tshow resto else tshow resto
        sinal = if centavos < 0 then "-" else ""
    in sinal <> tshow reais <> "," <> centavosTxt

formatarPreco :: Int -> Text
formatarPreco centavos = "R$ " <> formatPrecoInput centavos

precoField :: Field Handler Int
precoField = checkMMap (return . parseCentavos) formatPrecoInput textField

produtoForm :: Maybe Produto -> Form Produto
produtoForm mp = renderDivs $ Produto
    <$> areq textField "Nome" (produtoNome <$> mp)
    <*> aopt textField "Descrição" (produtoDescricao <$> mp)
    <*> areq precoField "Preço (R$)" (produtoPreco <$> mp)
    <*> areq estoqueField "Estoque" (produtoEstoque <$> mp)
    <*> areq (selectField (optionsPersistKey [] [Asc CategoriaNome] categoriaNome)) "Categoria" (produtoCategoriaId <$> mp)
    <*> areq (selectField (optionsPersistKey [] [Asc MarcaNome] marcaNome)) "Marca" (produtoMarcaId <$> mp)
  where
    estoqueField = checkBool (>= 0) ("O estoque não pode ser negativo" :: Text) intField

listarProdutos :: Handler [(Entity Produto, Maybe Categoria, Maybe Marca)]
listarProdutos = runDB $ do
    produtos <- selectList [] [Asc ProdutoNome]
    forM produtos $ \p@(Entity _ prod) -> do
        c <- get (produtoCategoriaId prod)
        m <- get (produtoMarcaId prod)
        return (p, c, m)

getProdutosR :: Handler Html
getProdutosR = do
    req <- getRequest
    linhas <- listarProdutos
    (widget, enctype) <- generateFormPost (produtoForm Nothing)
    defaultLayout $ do
        setTitle "Produtos - Hockey Store"
        $(widgetFile "produtos")

postProdutosR :: Handler Html
postProdutosR = do
    ((res, widget), enctype) <- runFormPost (produtoForm Nothing)
    case res of
        FormSuccess p -> do
            runDB $ insert_ p
            setMessage "Produto criado com sucesso"
            redirect ProdutosR
        _ -> do
            req <- getRequest
            linhas <- listarProdutos
            defaultLayout $ do
                setTitle "Produtos - Hockey Store"
                $(widgetFile "produtos")

getProdutoEditarR :: ProdutoId -> Handler Html
getProdutoEditarR pid = do
    p <- runDB $ get404 pid
    (widget, enctype) <- generateFormPost (produtoForm (Just p))
    defaultLayout $ do
        setTitle "Editar produto - Hockey Store"
        $(widgetFile "produto-editar")

postProdutoEditarR :: ProdutoId -> Handler Html
postProdutoEditarR pid = do
    p <- runDB $ get404 pid
    ((res, widget), enctype) <- runFormPost (produtoForm (Just p))
    case res of
        FormSuccess novo -> do
            runDB $ replace pid novo
            setMessage "Produto atualizado"
            redirect ProdutosR
        _ -> defaultLayout $ do
            setTitle "Editar produto - Hockey Store"
            $(widgetFile "produto-editar")

postProdutoExcluirR :: ProdutoId -> Handler Html
postProdutoExcluirR pid = do
    emUso <- runDB $ count [ItemPedidoProdutoId ==. pid]
    if emUso > 0
        then setMessage "Produto já vendido, não pode ser excluído"
        else do
            runDB $ delete pid
            setMessage "Produto excluído"
    redirect ProdutosR
