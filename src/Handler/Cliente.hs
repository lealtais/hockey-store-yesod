{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeFamilies #-}
module Handler.Cliente where

import Handler.Produto (formatarPreco)
import Handler.Common (mensagemErro, mensagemSucesso)
import Import

clienteForm :: Maybe Cliente -> Form Cliente
clienteForm atual = renderDivs $ Cliente
    <$> areq textField "Nome" (clienteNome <$> atual)
    <*> areq emailField "E-mail" (clienteEmail <$> atual)
    <*> aopt textField "Telefone" (clienteTelefone <$> atual)
    <*> pure (atual >>= clienteUserId)

renderClientes :: Widget -> Enctype -> Handler Html
renderClientes widget enctype = do
    req <- getRequest
    clientes <- runDB $ selectList [] [Asc ClienteNome]
    defaultLayout $ do
        setTitle "Clientes - Hockey Store"
        $(widgetFile "clientes")

getClientesR :: Handler Html
getClientesR = do
    (widget, enctype) <- generateFormPost (clienteForm Nothing)
    renderClientes widget enctype

postClientesR :: Handler Html
postClientesR = do
    ((resultado, widget), enctype) <- runFormPost (clienteForm Nothing)
    case resultado of
        FormSuccess cliente -> do
            inserido <- runDB $ insertUnique cliente
            case inserido of
                Just cid -> do
                    mensagemSucesso "Cliente criado com sucesso"
                    redirect (ClienteR cid)
                Nothing -> do
                    mensagemErro "Já existe cliente com esse e-mail"
                    renderClientes widget enctype
        _ -> renderClientes widget enctype

getClienteR :: ClienteId -> Handler Html
getClienteR cid = do
    (cliente, enderecos, pedidos) <- runDB $ do
        cliente <- get404 cid
        enderecos <- selectList [EnderecoClienteId ==. cid] [Asc EnderecoLogradouro]
        pedidos <- selectList [PedidoClienteId ==. cid] [Desc PedidoCriadoEm]
        pure (cliente, enderecos, pedidos)
    defaultLayout $ do
        setTitle "Cliente - Hockey Store"
        $(widgetFile "cliente")

renderClienteEditar :: ClienteId -> Widget -> Enctype -> Handler Html
renderClienteEditar cid widget enctype = defaultLayout $ do
    setTitle "Editar cliente - Hockey Store"
    $(widgetFile "cliente-editar")

getClienteEditarR :: ClienteId -> Handler Html
getClienteEditarR cid = do
    cliente <- runDB $ get404 cid
    (widget, enctype) <- generateFormPost (clienteForm (Just cliente))
    renderClienteEditar cid widget enctype

postClienteEditarR :: ClienteId -> Handler Html
postClienteEditarR cid = do
    cliente <- runDB $ get404 cid
    ((resultado, widget), enctype) <- runFormPost (clienteForm (Just cliente))
    case resultado of
        FormSuccess novo -> do
            atualizado <- runDB $ do
                existente <- getBy (UniqueCliente (clienteEmail novo))
                case existente of
                    Just (Entity outroId _) | outroId /= cid -> pure False
                    _ -> do
                        _ <- get404 cid
                        update cid
                            [ ClienteNome =. clienteNome novo
                            , ClienteEmail =. clienteEmail novo
                            , ClienteTelefone =. clienteTelefone novo
                            ]
                        pure True
            if atualizado
                then do
                    mensagemSucesso "Cliente atualizado com sucesso"
                    redirect (ClienteR cid)
                else do
                    mensagemErro "Já existe cliente com esse e-mail"
                    renderClienteEditar cid widget enctype
        _ -> renderClienteEditar cid widget enctype

postClienteExcluirR :: ClienteId -> Handler Html
postClienteExcluirR cid = do
    excluido <- runDB $ do
        _ <- get404 cid
        temPedido <- exists [PedidoClienteId ==. cid]
        if temPedido
            then pure False
            else do
                deleteWhere [EnderecoClienteId ==. cid]
                delete cid
                pure True
    if excluido
        then mensagemSucesso "Cliente excluído com sucesso"
        else mensagemErro "Cliente possui pedidos"
    redirect ClientesR
