{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeFamilies #-}
module Handler.Home where

import Import

getHomeR :: Handler Html
getHomeR = do
    usuario <- maybeAuthId
    let fotoHockey = StaticR (StaticRoute ["img", "hockey-hero.jpg"] [])
    defaultLayout $ do
        setTitle "Hockey Store"
        $(widgetFile "homepage")
