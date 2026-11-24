{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeFamilies #-}
module Handler.Categoria where

import Import

categoriaForm :: Maybe Categoria -> Form Categoria
categoriaForm mc = renderDivs $ Categoria
    <$> areq textField "Nome" (categoriaNome <$> mc)

listarCategorias :: Handler [Entity Categoria]
listarCategorias = runDB $ selectList [] [Asc CategoriaNome]

getCategoriasR :: Handler Html
getCategoriasR = do
    req <- getRequest
    categorias <- listarCategorias
    (widget, enctype) <- generateFormPost (categoriaForm Nothing)
    defaultLayout $ do
        setTitle "Categorias - Hockey Store"
        $(widgetFile "categorias")

postCategoriasR :: Handler Html
postCategoriasR = do
    ((res, widget), enctype) <- runFormPost (categoriaForm Nothing)
    case res of
        FormSuccess c -> do
            r <- runDB $ insertUnique c
            case r of
                Just _ -> setMessage "Categoria criada com sucesso"
                Nothing -> setMessage "Já existe uma categoria com esse nome"
            redirect CategoriasR
        _ -> do
            req <- getRequest
            categorias <- listarCategorias
            defaultLayout $ do
                setTitle "Categorias - Hockey Store"
                $(widgetFile "categorias")

getCategoriaEditarR :: CategoriaId -> Handler Html
getCategoriaEditarR cid = do
    c <- runDB $ get404 cid
    (widget, enctype) <- generateFormPost (categoriaForm (Just c))
    defaultLayout $ do
        setTitle "Editar categoria - Hockey Store"
        $(widgetFile "categoria-editar")

postCategoriaEditarR :: CategoriaId -> Handler Html
postCategoriaEditarR cid = do
    c <- runDB $ get404 cid
    ((res, widget), enctype) <- runFormPost (categoriaForm (Just c))
    case res of
        FormSuccess novo -> do
            existente <- runDB $ getBy (UniqueCategoria (categoriaNome novo))
            case existente of
                Just (Entity eid _) | eid /= cid -> do
                    setMessage "Já existe uma categoria com esse nome"
                    defaultLayout $ do
                        setTitle "Editar categoria - Hockey Store"
                        $(widgetFile "categoria-editar")
                _ -> do
                    runDB $ replace cid novo
                    setMessage "Categoria atualizada"
                    redirect CategoriasR
        _ -> defaultLayout $ do
            setTitle "Editar categoria - Hockey Store"
            $(widgetFile "categoria-editar")

postCategoriaExcluirR :: CategoriaId -> Handler Html
postCategoriaExcluirR cid = do
    emUso <- runDB $ count [ProdutoCategoriaId ==. cid]
    if emUso > 0
        then setMessage "Não é possível excluir: existem produtos nesta categoria"
        else do
            runDB $ delete cid
            setMessage "Categoria excluída"
    redirect CategoriasR
