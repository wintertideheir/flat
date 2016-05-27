{-# LANGUAGE DeriveGeneric #-}
module Data.Flat.Filler(Filler(..),fillerLength
                       ,PreAligned(..),preAligned,postAligned,PostAligned(..)
                       ) where

import           Data.Flat.Class
import           Data.Flat.Encoding
import           Data.Flat.Run
import           Data.Typeable

-- |A meaningless sequence of 0 bits terminated with a 1 bit (easier to implement than the reverse)
data Filler = FillerBit Filler
            | FillerEnd deriving (Show,Eq,Typeable,Generic)

-- |Length of a filler in bits.
fillerLength :: Num a => Filler -> a
fillerLength FillerEnd = 1
fillerLength (FillerBit f) = 1 + fillerLength f

instance Flat Filler where encode _ = eFiller

-- |Prealigned and post aligned types
postAligned :: a -> PostAligned a
postAligned a = PostAligned a FillerEnd

data PostAligned a = PostAligned a Filler deriving (Show,Eq,Typeable,Generic)
instance Flat a => Flat (PostAligned a)

preAligned :: a -> PreAligned a
preAligned a = PreAligned FillerEnd a

data PreAligned a = PreAligned Filler a deriving (Show,Eq,Typeable,Generic)
instance Flat a => Flat (PreAligned a)
