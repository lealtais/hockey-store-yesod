{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeFamilies #-}
-- | Common handler functions.
module Handler.Common where

import Data.FileEmbed (embedFile)
import Import

-- These handlers embed files in the executable at compile time to avoid a
-- runtime dependency, and for efficiency.

getFaviconR :: Handler TypedContent
getFaviconR = do cacheSeconds $ 60 * 60 * 24 * 30 -- cache for a month
                 return $ TypedContent "image/x-icon"
                        $ toContent $(embedFile "config/favicon.ico")

getRobotsR :: Handler TypedContent
getRobotsR = return $ TypedContent typePlain
                    $ toContent $(embedFile "config/robots.txt")

mensagemSucesso :: Text -> Handler ()
mensagemSucesso texto = setMessage [shamlet|<div .alert.alert-success role=status>#{texto}|]

mensagemErro :: Text -> Handler ()
mensagemErro texto = setMessage [shamlet|<div .alert.alert-danger role=alert>#{texto}|]

inteiroLimitadoField :: Field Handler Int
inteiroLimitadoField = checkMMap converter toInteger intField
  where
    converter valor
        | valor < toInteger (minBound :: Int) || valor > toInteger (maxBound :: Int) =
            pure (Left ("Número acima ou abaixo do limite permitido" :: Text))
        | otherwise = pure (Right (fromInteger valor))
