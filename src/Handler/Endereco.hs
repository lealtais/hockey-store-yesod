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

lerRascunhoEndereco :: ClienteId -> Maybe Endereco -> Handler Endereco
lerRascunhoEndereco cid base = do
    cep <- fromMaybe (maybe "" enderecoCep base) <$> lookupPostParam "f1"
    logradouro <- fromMaybe (maybe "" enderecoLogradouro base) <$> lookupPostParam "f2"
    numero <- fromMaybe (maybe "" enderecoNumero base) <$> lookupPostParam "f3"
    complemento <- lookupPostParam "f4"
    bairro <- fromMaybe (maybe "" enderecoBairro base) <$> lookupPostParam "f5"
    cidade <- fromMaybe (maybe "" enderecoCidade base) <$> lookupPostParam "f6"
    uf <- fromMaybe (maybe "" enderecoUf base) <$> lookupPostParam "f7"
    pure $ Endereco cid cep logradouro numero (complementoNaoVazio complemento) bairro cidade uf

preencherComViaCep :: ClienteId -> Endereco -> Handler (Either Text Endereco)
preencherComViaCep cid rascunho = do
    app <- getYesod
    resposta <- liftIO $ buscarCep (appHttpManager app) (enderecoCep rascunho)
    pure $ case resposta of
        Left erro -> Left erro
        Right dados ->
            Right $ Endereco cid
                (viaCepCep dados)
                (viaCepLogradouro dados)
                (enderecoNumero rascunho)
                (enderecoComplemento rascunho)
                (viaCepBairro dados)
                (viaCepLocalidade dados)
                (viaCepUf dados)

getEnderecoNovoR :: ClienteId -> Handler Html
getEnderecoNovoR cid = do
    _ <- runDB $ get404 cid
    (widget, enctype) <- generateFormPost (enderecoForm cid Nothing)
    renderNovoEndereco cid widget enctype

postEnderecoNovoR :: ClienteId -> Handler Html
postEnderecoNovoR cid = do
    _ <- runDB $ get404 cid
    buscar <- lookupPostParam "buscar"
    case buscar of
        Just _ -> do
            rascunho <- lerRascunhoEndereco cid Nothing
            resultadoBusca <- preencherComViaCep cid rascunho
            enderecoExibido <- case resultadoBusca of
                Left erro -> do
                    mensagemErro erro
                    pure rascunho
                Right preenchido -> pure preenchido
            (widget, enctype) <- generateFormPost (enderecoForm cid (Just enderecoExibido))
            renderNovoEndereco cid widget enctype
        Nothing -> do
            ((resultado, widget), enctype) <- runFormPost (enderecoForm cid Nothing)
            case resultado of
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
    buscar <- lookupPostParam "buscar"
    case buscar of
        Just _ -> do
            rascunho <- lerRascunhoEndereco cid (Just original)
            resultadoBusca <- preencherComViaCep cid rascunho
            enderecoExibido <- case resultadoBusca of
                Left erro -> do
                    mensagemErro erro
                    pure rascunho
                Right preenchido -> pure preenchido
            (widget, enctype) <- generateFormPost (enderecoForm cid (Just enderecoExibido))
            renderEditarEndereco eid cid widget enctype
        Nothing -> do
            ((resultado, widget), enctype) <- runFormPost (enderecoForm cid (Just original))
            case resultado of
                FormSuccess endereco -> do
                    runDB $ replace eid endereco
                    mensagemSucesso "Endereço atualizado com sucesso"
                    redirect (ClienteR cid)
                _ -> renderEditarEndereco eid cid widget enctype

postEnderecoExcluirR :: EnderecoId -> Handler Html
postEnderecoExcluirR eid = do
    (cid, emUso) <- runDB $ do
        endereco <- get404 eid
        usos <- count [PedidoEnderecoId ==. Just eid]
        when (usos == 0) $ delete eid
        pure (enderecoClienteId endereco, usos > 0)
    if emUso
        then mensagemErro "Não é possível excluir: existem pedidos vinculados a este endereço"
        else mensagemSucesso "Endereço excluído com sucesso"
    redirect (ClienteR cid)

complementoNaoVazio :: Maybe Text -> Maybe Text
complementoNaoVazio complemento =
    complemento >>= \texto ->
        if T.null (T.strip texto) then Nothing else Just texto
