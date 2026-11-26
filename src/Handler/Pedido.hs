{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeFamilies #-}
module Handler.Pedido where

import Handler.Produto (formatarPreco)
import Handler.Common (inteiroLimitadoField, mensagemErro, mensagemSucesso)
import Import

novoPedidoForm :: Form ClienteId
novoPedidoForm = renderDivs $
    areq (selectField (optionsPersistKey [] [Asc ClienteNome] clienteNome)) "Cliente" Nothing

itemForm :: Form (ProdutoId, Int)
itemForm = renderDivs $ (,)
    <$> areq (selectField (optionsPersistKey [] [Asc ProdutoNome] produtoNome)) "Produto" Nothing
    <*> areq (checkBool (> 0) ("Quantidade deve ser maior que zero" :: Text) inteiroLimitadoField) "Quantidade" (Just 1)

enderecoForm :: Pedido -> Form EnderecoId
enderecoForm pedido = renderDivs $
    areq (selectField (optionsPersistKey filtros [Asc EnderecoLogradouro] rotuloEndereco))
        "Endereço" (pedidoEnderecoId pedido)
  where
    filtros = [EnderecoClienteId ==. pedidoClienteId pedido]

rotuloEndereco :: Endereco -> Text
rotuloEndereco endereco =
    enderecoLogradouro endereco <> ", " <> enderecoNumero endereco
        <> " — " <> enderecoCidade endereco <> "/" <> enderecoUf endereco

renderPedidos :: Widget -> Enctype -> Handler Html
renderPedidos widget enctype = do
    pedidos <- runDB $ do
        registros <- selectList [] [Desc PedidoCriadoEm, Desc PedidoId]
        forM registros $ \(Entity pid pedido) -> do
            cliente <- get404 (pedidoClienteId pedido)
            pure (pid, pedido, clienteNome cliente)
    defaultLayout $ do
        setTitle "Pedidos - Hockey Store"
        $(widgetFile "pedidos")

getPedidosR :: Handler Html
getPedidosR = do
    (widget, enctype) <- generateFormPost novoPedidoForm
    renderPedidos widget enctype

postPedidosR :: Handler Html
postPedidosR = do
    ((resultado, widget), enctype) <- runFormPost novoPedidoForm
    case resultado of
        FormSuccess cid -> do
            agora <- liftIO getCurrentTime
            pid <- runDB $ do
                _ <- get404 cid
                insert (Pedido cid Nothing Aberto 0 agora)
            mensagemSucesso "Pedido criado com sucesso"
            redirect (PedidoR pid)
        _ -> renderPedidos widget enctype

renderPedido :: PedidoId -> Maybe (Widget, Enctype) -> Maybe (Widget, Enctype) -> Handler Html
renderPedido pid itemInvalido enderecoInvalido = do
    req <- getRequest
    let tokenCsrf = reqToken req
    (pedido, cliente, endereco, temEnderecos, itens) <- runDB $ do
        pedido <- get404 pid
        cliente <- get404 (pedidoClienteId pedido)
        endereco <- traverse get (pedidoEnderecoId pedido)
        temEnderecos <- exists [EnderecoClienteId ==. pedidoClienteId pedido]
        registros <- selectList [ItemPedidoPedidoId ==. pid] [Asc ItemPedidoId]
        itens <- forM registros $ \(Entity iid item) -> do
            produto <- get404 (itemPedidoProdutoId item)
            pure (iid, item, produtoNome produto)
        pure (pedido, cliente, join endereco, temEnderecos, itens)
    let aberto = pedidoStatus pedido == Aberto
        colunasItens = if aberto then (4 :: Int) else 3
    (itemWidget, itemEnctype) <- maybe (generateFormPost itemForm) pure itemInvalido
    (enderecoWidget, enderecoEnctype) <- maybe (generateFormPost (enderecoForm pedido)) pure enderecoInvalido
    defaultLayout $ do
        setTitle "Detalhe do pedido - Hockey Store"
        $(widgetFile "pedido")

getPedidoR :: PedidoId -> Handler Html
getPedidoR pid = renderPedido pid Nothing Nothing

comPedidoAberto :: PedidoId -> (Pedido -> YesodDB App (Either Text Text)) -> YesodDB App (Either Text Text)
comPedidoAberto pid acao = do
    updateWhere [PedidoId ==. pid, PedidoStatus ==. Aberto] [PedidoStatus =. Aberto]
    pedido <- get404 pid
    if pedidoStatus pedido == Aberto
        then acao pedido
        else pure (Left "Somente pedidos abertos podem ser alterados")

responderPedido :: Route App -> Either Text Text -> Handler Html
responderPedido destino resultado = do
    either mensagemErro mensagemSucesso resultado
    redirect destino

recalcularTotal :: PedidoId -> YesodDB App ()
recalcularTotal pid = do
    itens <- selectList [ItemPedidoPedidoId ==. pid] []
    let total = sum [itemPedidoQuantidade item * itemPedidoPrecoUnitario item | Entity _ item <- itens]
    update pid [PedidoTotal =. total]

postPedidoItensR :: PedidoId -> Handler Html
postPedidoItensR pid = do
    ((resultado, widget), enctype) <- runFormPost itemForm
    case resultado of
        FormSuccess (produtoId, quantidade) -> do
            alteracao <- runDB $ comPedidoAberto pid $ \pedido -> do
                produto <- get404 produtoId
                existente <- getBy (UniqueItemPedido pid produtoId)
                let quantidadeAnterior = maybe 0 (itemPedidoQuantidade . entityVal) existente
                    preco = maybe (produtoPreco produto) (itemPedidoPrecoUnitario . entityVal) existente
                    totalNovo = toInteger (pedidoTotal pedido) + toInteger quantidade * toInteger preco
                if toInteger quantidadeAnterior + toInteger quantidade > toInteger (produtoEstoque produto)
                    then pure (Left "Quantidade maior que o estoque disponível")
                    else if totalNovo > toInteger (maxBound :: Int)
                        then pure (Left "Total do pedido acima do limite permitido")
                        else do
                            case existente of
                                Nothing -> insert_ (ItemPedido pid produtoId quantidade preco)
                                Just (Entity iid _) -> update iid [ItemPedidoQuantidade +=. quantidade]
                            recalcularTotal pid
                            pure (Right "Item adicionado ao pedido")
            responderPedido (PedidoR pid) alteracao
        _ -> renderPedido pid (Just (widget, enctype)) Nothing

postPedidoItemRemoverR :: PedidoId -> ItemPedidoId -> Handler Html
postPedidoItemRemoverR pid iid = do
    resultado <- runDB $ comPedidoAberto pid $ \_ -> do
        item <- get404 iid
        if itemPedidoPedidoId item /= pid
            then notFound
            else do
                delete iid
                recalcularTotal pid
                pure (Right "Item removido do pedido")
    responderPedido (PedidoR pid) resultado

postPedidoEnderecoR :: PedidoId -> Handler Html
postPedidoEnderecoR pid = do
    pedido <- runDB $ get404 pid
    ((resultado, widget), enctype) <- runFormPost (enderecoForm pedido)
    case resultado of
        FormSuccess eid -> do
            alteracao <- runDB $ comPedidoAberto pid $ \atual -> do
                endereco <- get eid
                if maybe False ((== pedidoClienteId atual) . enderecoClienteId) endereco
                    then do
                        update pid [PedidoEnderecoId =. Just eid]
                        pure (Right "Endereço de entrega atualizado")
                    else pure (Left "Selecione um endereço do cliente do pedido")
            responderPedido (PedidoR pid) alteracao
        _ -> renderPedido pid Nothing (Just (widget, enctype))

postPedidoFinalizarR :: PedidoId -> Handler Html
postPedidoFinalizarR pid = do
    resultado <- runDB $ comPedidoAberto pid $ \pedido -> do
        itens <- selectList [ItemPedidoPedidoId ==. pid] [Asc ItemPedidoId]
        endereco <- traverse get (pedidoEnderecoId pedido)
        let enderecoValido = maybe False ((== pedidoClienteId pedido) . enderecoClienteId) (join endereco)
        case () of
            _ | null itens -> pure (Left "Adicione pelo menos um item antes de finalizar")
              | not enderecoValido -> pure (Left "Selecione um endereço de entrega antes de finalizar")
              | otherwise -> finalizar itens
    responderPedido (PedidoR pid) resultado
  where
    finalizar itens = do
        disponiveis <- forM itens $ \(Entity _ item) -> do
            produto <- get404 (itemPedidoProdutoId item)
            pure (produtoEstoque produto >= itemPedidoQuantidade item)
        if and disponiveis
            then do
                forM_ itens $ \(Entity _ item) ->
                    update (itemPedidoProdutoId item) [ProdutoEstoque -=. itemPedidoQuantidade item]
                update pid [PedidoStatus =. Pago]
                pure (Right "Pedido pago e estoque atualizado")
            else pure (Left "Estoque insuficiente para finalizar o pedido")

postPedidoCancelarR :: PedidoId -> Handler Html
postPedidoCancelarR pid = do
    resultado <- runDB $ comPedidoAberto pid $ \_ -> do
        update pid [PedidoStatus =. Cancelado]
        pure (Right "Pedido cancelado")
    responderPedido (PedidoR pid) resultado

postPedidoExcluirR :: PedidoId -> Handler Html
postPedidoExcluirR pid = do
    resultado <- runDB $ comPedidoAberto pid $ \_ -> do
        deleteWhere [ItemPedidoPedidoId ==. pid]
        delete pid
        pure (Right "Pedido excluído")
    responderPedido (either (const (PedidoR pid)) (const PedidosR) resultado) resultado
