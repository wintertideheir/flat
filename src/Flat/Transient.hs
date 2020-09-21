module Flat.Transient where

import Flat
import Flat.Decoder.Types

data Transient a = Transient a

class HasDefault a where
    defaultValue :: a

instance (HasDefault a) => Flat.Flat (Transient a) where
    encode _ = encode ()
    decode   = (Transient defaultValue) <$ (decode :: Get ())
    size   _ = size ()

instance HasDefault [a]       where defaultValue = []
instance HasDefault (Maybe a) where defaultValue = Nothing
instance HasDefault Int       where defaultValue = 0
instance HasDefault Integer   where defaultValue = 0
instance HasDefault Float     where defaultValue = 0.0
instance HasDefault Double    where defaultValue = 0.0
instance HasDefault Char      where defaultValue = '\0'
