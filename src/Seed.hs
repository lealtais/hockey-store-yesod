{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}
module Seed (semear) where

import Import

semear :: MonadIO m => SqlPersistT m ()
semear = do
    total <- count ([] :: [Filter Categoria])
    when (total == 0) $ do
        tacos <- insert (Categoria "Tacos")
        patins <- insert (Categoria "Patins")
        capacetes <- insert (Categoria "Capacetes")
        luvas <- insert (Categoria "Luvas")
        protecoes <- insert (Categoria "Proteções")
        bauer <- insert (Marca "Bauer" (Just "Canadá"))
        ccm <- insert (Marca "CCM" (Just "Canadá"))
        warrior <- insert (Marca "Warrior" (Just "EUA"))
        true <- insert (Marca "True" (Just "EUA"))
        _ <- insert (Produto "Taco Bauer Nexus" (Just "Taco composto, flex 77") 129990 15 tacos bauer)
        _ <- insert (Produto "Taco CCM Jetspeed" (Just "Taco leve, flex 70") 109900 12 tacos ccm)
        _ <- insert (Produto "Patins Bauer Vapor" (Just "Patins para jogador de linha") 249900 8 patins bauer)
        _ <- insert (Produto "Patins True Catalyst" (Just "Patins de alta performance") 289900 5 patins true)
        _ <- insert (Produto "Capacete Warrior Covert" (Just "Com grade removível") 65000 20 capacetes warrior)
        _ <- insert (Produto "Luvas CCM Tacks" (Just "Luvas de couro sintético") 48000 18 luvas ccm)
        _ <- insert (Produto "Caneleira Bauer Supreme" (Just "Proteção de canela") 39000 25 protecoes bauer)
        pure ()
