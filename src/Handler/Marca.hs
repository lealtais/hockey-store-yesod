{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeFamilies #-}
module Handler.Marca where

import Handler.Common (mensagemErro, mensagemSucesso)
import Import

marcaForm :: Maybe Marca -> Form Marca
marcaForm mm = renderDivs $ Marca
    <$> areq textField "Nome" (marcaNome <$> mm)
    <*> aopt textField "País" (marcaPais <$> mm)

listarMarcas :: Handler [Entity Marca]
listarMarcas = runDB $ selectList [] [Asc MarcaNome]

getMarcasR :: Handler Html
getMarcasR = do
    req <- getRequest
    marcas <- listarMarcas
    (widget, enctype) <- generateFormPost (marcaForm Nothing)
    defaultLayout $ do
        setTitle "Marcas - Hockey Store"
        $(widgetFile "marcas")

postMarcasR :: Handler Html
postMarcasR = do
    ((res, widget), enctype) <- runFormPost (marcaForm Nothing)
    case res of
        FormSuccess m -> do
            r <- runDB $ insertUnique m
            case r of
                Just _ -> mensagemSucesso "Marca criada com sucesso"
                Nothing -> mensagemErro "Já existe uma marca com esse nome"
            redirect MarcasR
        _ -> do
            req <- getRequest
            marcas <- listarMarcas
            defaultLayout $ do
                setTitle "Marcas - Hockey Store"
                $(widgetFile "marcas")

getMarcaEditarR :: MarcaId -> Handler Html
getMarcaEditarR mid = do
    m <- runDB $ get404 mid
    (widget, enctype) <- generateFormPost (marcaForm (Just m))
    defaultLayout $ do
        setTitle "Editar marca - Hockey Store"
        $(widgetFile "marca-editar")

postMarcaEditarR :: MarcaId -> Handler Html
postMarcaEditarR mid = do
    m <- runDB $ get404 mid
    ((res, widget), enctype) <- runFormPost (marcaForm (Just m))
    case res of
        FormSuccess novo -> do
            existente <- runDB $ getBy (UniqueMarca (marcaNome novo))
            case existente of
                Just (Entity eid _) | eid /= mid -> do
                    mensagemErro "Já existe uma marca com esse nome"
                    defaultLayout $ do
                        setTitle "Editar marca - Hockey Store"
                        $(widgetFile "marca-editar")
                _ -> do
                    runDB $ replace mid novo
                    mensagemSucesso "Marca atualizada"
                    redirect MarcasR
        _ -> defaultLayout $ do
            setTitle "Editar marca - Hockey Store"
            $(widgetFile "marca-editar")

postMarcaExcluirR :: MarcaId -> Handler Html
postMarcaExcluirR mid = do
    emUso <- runDB $ do
        _ <- get404 mid
        count [ProdutoMarcaId ==. mid]
    if emUso > 0
        then mensagemErro "Não é possível excluir: existem produtos desta marca"
        else do
            runDB $ delete mid
            mensagemSucesso "Marca excluída"
    redirect MarcasR
