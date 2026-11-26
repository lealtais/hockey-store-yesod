{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeFamilies #-}
module Handler.Endereco where

import qualified Data.Text as T
import Api.ViaCEP
import Handler.Common (mensagemErro, mensagemSucesso)
import Import

enderecoForm :: ClienteId -> Maybe Endereco -> Form Endereco
enderecoForm cid atual = renderDivs $ Endereco cid
    <$> areq textField "CEP" (enderecoCep <$> atual)
    <*> areq textField "Logradouro" (enderecoLogradouro <$> atual)
    <*> areq textField "Número" (enderecoNumero <$> atual)
    <*> aopt textField "Complemento" (enderecoComplemento <$> atual)
    <*> areq textField "Bairro" (enderecoBairro <$> atual)
    <*> areq textField "Cidade" (enderecoCidade <$> atual)
    <*> areq textField "UF" (enderecoUf <$> atual)

renderEnderecoForm :: Text -> Route App -> Route App -> Widget -> Enctype -> Handler Html
renderEnderecoForm titulo action voltar widget enctype = defaultLayout $ do
    setTitle (toHtml titulo)
    $(widgetFile "endereco-form")

renderNovoEndereco :: ClienteId -> Widget -> Enctype -> Handler Html
renderNovoEndereco cid widget enctype =
    renderEnderecoForm "Novo endereço - Hockey Store"
        (EnderecoNovoR cid) (ClienteR cid) widget enctype

renderEditarEndereco :: EnderecoId -> ClienteId -> Widget -> Enctype -> Handler Html
renderEditarEndereco eid cid widget enctype =
    renderEnderecoForm "Editar endereço - Hockey Store"
        (EnderecoEditarR eid) (ClienteR cid) widget enctype

getEnderecoNovoR :: ClienteId -> Handler Html
getEnderecoNovoR cid = do
    _ <- runDB $ get404 cid
    (widget, enctype) <- generateFormPost (enderecoForm cid Nothing)
    renderNovoEndereco cid widget enctype

postEnderecoNovoR :: ClienteId -> Handler Html
postEnderecoNovoR cid = do
    _ <- runDB $ get404 cid
    ((resultado, widget), enctype) <- runFormPost (enderecoForm cid Nothing)
    buscar <- lookupPostParam "buscar"
    case buscar of
        Just _ -> do
            cep <- fromMaybe "" <$> lookupPostParam "f1"
            numero <- fromMaybe "" <$> lookupPostParam "f3"
            complemento <- lookupPostParam "f4"
            app <- getYesod
            resposta <- liftIO $ buscarCep (appHttpManager app) cep
            case resposta of
                Left erro -> do
                    mensagemErro erro
                    renderNovoEndereco cid widget enctype
                Right dados -> do
                    let endereco = Endereco cid
                            (viaCepCep dados)
                            (viaCepLogradouro dados)
                            numero
                            (complementoNaoVazio complemento)
                            (viaCepBairro dados)
                            (viaCepLocalidade dados)
                            (viaCepUf dados)
                    (preenchido, novoEnctype) <- generateFormPost
                        (enderecoForm cid (Just endereco))
                    renderNovoEndereco cid preenchido novoEnctype
        Nothing -> case resultado of
            FormSuccess endereco -> do
                _ <- runDB $ insert endereco
                mensagemSucesso "Endereço cadastrado com sucesso"
                redirect (ClienteR cid)
            _ -> renderNovoEndereco cid widget enctype

getEnderecoEditarR :: EnderecoId -> Handler Html
getEnderecoEditarR eid = do
    endereco <- runDB $ get404 eid
    (widget, enctype) <- generateFormPost (enderecoForm (enderecoClienteId endereco) (Just endereco))
    renderEditarEndereco eid (enderecoClienteId endereco) widget enctype

postEnderecoEditarR :: EnderecoId -> Handler Html
postEnderecoEditarR eid = do
    original <- runDB $ get404 eid
    let cid = enderecoClienteId original
    ((resultado, widget), enctype) <- runFormPost (enderecoForm cid (Just original))
    buscar <- lookupPostParam "buscar"
    case buscar of
        Just _ -> do
            cep <- fromMaybe "" <$> lookupPostParam "f1"
            numero <- fromMaybe (enderecoNumero original) <$> lookupPostParam "f3"
            complemento <- lookupPostParam "f4"
            app <- getYesod
            resposta <- liftIO $ buscarCep (appHttpManager app) cep
            case resposta of
                Left erro -> do
                    mensagemErro erro
                    renderEditarEndereco eid cid widget enctype
                Right dados -> do
                    let endereco = Endereco cid
                            (viaCepCep dados)
                            (viaCepLogradouro dados)
                            numero
                            (complementoNaoVazio complemento)
                            (viaCepBairro dados)
                            (viaCepLocalidade dados)
                            (viaCepUf dados)
                    (preenchido, novoEnctype) <- generateFormPost
                        (enderecoForm cid (Just endereco))
                    renderEditarEndereco eid cid preenchido novoEnctype
        Nothing -> case resultado of
            FormSuccess endereco -> do
                runDB $ replace eid endereco
                mensagemSucesso "Endereço atualizado com sucesso"
                redirect (ClienteR cid)
            _ -> renderEditarEndereco eid cid widget enctype

postEnderecoExcluirR :: EnderecoId -> Handler Html
postEnderecoExcluirR eid = do
    cid <- runDB $ do
        endereco <- get404 eid
        delete eid
        pure (enderecoClienteId endereco)
    mensagemSucesso "Endereço excluído com sucesso"
    redirect (ClienteR cid)

complementoNaoVazio :: Maybe Text -> Maybe Text
complementoNaoVazio complemento =
    complemento >>= \texto ->
        if T.null (T.strip texto) then Nothing else Just texto
