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
