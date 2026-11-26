{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}

module Api.ViaCEP
    ( EnderecoViaCEP (..)
    , normalizarCep
    , buscarCep
    ) where

import Control.Exception (try)
import Data.Aeson (FromJSON, eitherDecode, withObject, (.:), (.:?))
import Data.Char (isDigit)
import qualified Data.Text as T
import qualified Network.HTTP.Simple as HTTP
import Import

data EnderecoViaCEP = EnderecoViaCEP
    { viaCepCep :: Text
    , viaCepLogradouro :: Text
    , viaCepComplemento :: Maybe Text
    , viaCepBairro :: Text
    , viaCepLocalidade :: Text
    , viaCepUf :: Text
    , viaCepErro :: Maybe Bool
    } deriving (Show, Eq)

instance FromJSON EnderecoViaCEP where
    parseJSON = withObject "EnderecoViaCEP" $ \o -> EnderecoViaCEP
        <$> o .: "cep"
        <*> o .: "logradouro"
        <*> o .:? "complemento"
        <*> o .: "bairro"
        <*> o .: "localidade"
        <*> o .: "uf"
        <*> o .:? "erro"

normalizarCep :: Text -> Maybe Text
normalizarCep raw =
    let digitos = T.filter isDigit raw
    in if T.length digitos == 8 then Just digitos else Nothing

buscarCep :: HTTP.Manager -> Text -> IO (Either Text EnderecoViaCEP)
buscarCep manager raw =
    case normalizarCep raw of
        Nothing -> return $ Left "CEP inválido: informe os 8 dígitos"
        Just digitos -> do
            let url = "https://viacep.com.br/ws/" <> digitos <> "/json/"
            req <- HTTP.parseRequest $ T.unpack url
            resultado <-
                (try (HTTP.httpLBS (HTTP.setRequestManager manager req))
                 :: IO (Either HTTP.HttpException (HTTP.Response ByteString)))
            case resultado of
                Left ex -> return $ Left $ "Não foi possível consultar o ViaCEP: " <> tshow ex
                Right res -> do
                    let status = HTTP.getResponseStatusCode res
                    if status /= 200
                        then return $ Left $ "ViaCEP respondeu com status " <> tshow status
                        else case eitherDecode (HTTP.getResponseBody res) of
                            Left err -> return $ Left $ "Resposta inesperada do ViaCEP: " <> T.pack err
                            Right endereco
                                | viaCepErro endereco == Just True -> return $ Left "CEP não encontrado"
                                | otherwise -> return $ Right endereco
