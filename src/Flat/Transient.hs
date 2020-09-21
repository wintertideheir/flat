module Flat.Transient where

import Flat
import Flat.Decoder.Types

data Transient a = Transient a

instance Flat.Flat (Transient a) where
    encode _ = encode ()
    decode   = (Transient $ error "Transient value was never initialized.") <$ (decode :: Get ())
    size   _ = size ()
