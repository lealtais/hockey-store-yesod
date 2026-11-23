{-# LANGUAGE TemplateHaskell #-}
module Model.StatusPedido where

import Prelude
import Database.Persist.TH

data StatusPedido
    = Aberto
    | Pago
    | Enviado
    | Cancelado
    deriving (Show, Read, Eq, Ord, Enum, Bounded)

derivePersistField "StatusPedido"
