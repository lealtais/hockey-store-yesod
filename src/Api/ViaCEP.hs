{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}

module Api.ViaCEP
    ( EnderecoViaCEP (..)
    , normalizarCep
    , buscarCep
    ) where

import Data.Aeson (Result (..), eitherDecode, fromJSON, withObject, (.:?), (.!=))
import qualified Data.Aeson.KeyMap as KM
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
    } deriving (Show, Eq)

instance FromJSON EnderecoViaCEP where
    parseJSON = withObject "EnderecoViaCEP" $ \o -> EnderecoViaCEP
        <$> o .: "cep"
        <*> o .:? "logradouro" .!= ""
        <*> o .:? "complemento"
        <*> o .:? "bairro" .!= ""
        <*> o .:? "localidade" .!= ""
        <*> o .: "uf"

normalizarCep :: Text -> Maybe Text
normalizarCep raw =
    let digitos = T.filter isDigit raw
    in if T.length digitos == 8 then Just digitos else Nothing

buscarCep :: Manager -> Text -> IO (Either Text EnderecoViaCEP)
buscarCep manager raw =
    case normalizarCep raw of
        Nothing -> return $ Left "CEP inválido: informe os 8 dígitos"
        Just digitos -> do
            let url = "https://viacep.com.br/ws/" <> digitos <> "/json/"
            req <- HTTP.parseRequest $ T.unpack url
            resultado <-
                (try (HTTP.httpLBS (HTTP.setRequestManager manager req))
                 :: IO (Either HTTP.HttpException (HTTP.Response LByteString)))
            case resultado of
                Left _ -> return $ Left "Não foi possível consultar o ViaCEP agora"
                Right res -> do
                    let status = HTTP.getResponseStatusCode res
                    if status /= 200
                        then return $ Left $ "ViaCEP respondeu com status " <> tshow status
                        else case eitherDecode (HTTP.getResponseBody res) of
                            Left _ -> return $ Left "Resposta inesperada do ViaCEP"
                            Right (Object o) | KM.member "erro" o ->
                                return $ Left "CEP não encontrado"
                            Right val -> case fromJSON val of
                                Error _ -> return $ Left "Resposta inesperada do ViaCEP"
                                Success endereco -> return $ Right endereco
