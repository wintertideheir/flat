{-# LANGUAGE BangPatterns              #-}
{-# LANGUAGE CPP                       #-}
{-# LANGUAGE DeriveGeneric             #-}
{-# LANGUAGE NoMonomorphismRestriction #-}
module Data.Flat.Instances (
    -- ,ASCII(..),Word7
    ) where

import           Data.Binary.Bits.Get
import qualified Data.ByteString      as B
--import           Data.ByteString.Builder.Extra hiding (builder, tag8)
import qualified Data.ByteString.Lazy as L
import           Data.Char
import qualified Data.DList           as DL
import           Data.Flat.Class
import           Data.Flat.Encoding
import           Data.Flat.Filler
import           Data.Int
import           Data.Monoid
import qualified Data.Text            as T
import qualified Data.Text.Encoding   as T
import           Data.Typeable
import           Data.Word
import           Data.ZigZag
--import           Data.Word.Odd                 (Word7)
--import           Data.Flat.IEEE754
#include "MachDeps.h"

---------- Flat Instances
instance Flat a => Flat (Maybe a)

instance (Flat a,Flat b) => Flat (Either a b)

instance Flat () where
  encode = mempty
  decode = pure ()

instance Flat Bool where
  encode = eBool
  decode = dBool


------------------- Lists

{-
-- Bit list
data List a = Nil | Cons a (List a)
eList :: Flat a => [a] -> Encoding
eList = foldr (\x r -> eTrue <> encode x <> r) eFalse

-- Byte List, more efficient for longer lists 1 byte per 255 elems
data List a = L0 | L1 a1 (List a) | L2 a1 a2 (List a) | L255 a1 .. a255 (List a)

ByteString == BLOB
-}

-- Indicates UTF-8 coding
-- data UTF8 a = UTF8 a deriving (Show,Eq,Typeable,Generic)
-- instance Flat a => Flat (UTF8 a)
data UTF8 = UTF8 deriving (Show,Eq,Typeable,Generic)
instance Flat UTF8

data NoEnc = NoEnc deriving (Show,Eq,Typeable,Generic)
instance Flat NoEnc

-- data Text e = Text (PreAligned (e (List255 Word8)))

#if defined(LIST_BYTE)
-- data BLOB encoding = BLOB (PreAligned (encoding (List255 Word8))) deriving (Typeable,Generic)
-- or simply, to avoid higher-order kinds:
data BLOB encoding = BLOB encoding (PreAligned (List255 Word8)) deriving (Typeable,Generic)
-- data BLOB = BLOB (PreAligned (List255 Word8))
-- data Encoded encoding = CLOB encoding BLOB

instance Flat e => Flat (BLOB e)

data List255 a = List255 [a]

instance Flat a => Flat (List255 a) where
    encode (List255 l) = encodeList l
    decode = List255 <$> decodeList
#endif

dList = do
    tag <- dBool
    if tag
      then (:) <$> decode <*> dList
      else return []

-- 1 2 3 -> 3 : 2 : 1
dListReverse = go []
    where go !acc = do
            tag <- dBool
            if tag
              then do
                x <- decode
                go (x:acc)
              else return $! reverse acc

ee = encode "abc" -- [True,True,True]

-- #define LIST_BYTE
-- #define ENCLIST_DIV

-- Different implementations of encoding for List255 (none very good)
#ifdef ENCLIST_GO
encodeList :: Flat a => [a] -> Encoding
encodeList l = go mempty l (length l)
    where
      go e !l 0 = e <> eWord8 0
      go e !l n = let c = min 255 n
                      n' = n-c
                      (e',!l') = goElems (e <> (eWord8 $ fromIntegral c)) l c
                 in go e' l' n'
      goElems e !l      0 = (e,l)
      goElems e (!x:xs) n = goElems (e <> encode x) xs (n-1)

#elif defined (ENCLIST_DIV)
encodeList l = let (d,m) = length l `divMod` 255
                   ns = cons d $ if m==0 then [0] else [m,0]
                   cons 0 t = t
                   cons n t = cons (n-1) (255:t)
               in gos ns l
  where
    gos [] [] = mempty
    gos (n:ns) l = eWord8 (fromIntegral n) <> go ns n l
    go ns 0 l = gos ns l
    go ns n (h:t) = encode h <> go ns (n-1) t

#elif defined(ENCLIST_FOLDL2)
encodeList :: Flat a => [a] -> Encoding
encodeList l = let (e,0,_) = encList l in e <> eWord8 0

encList l  = foldl' (\(!r,!l,!s) x ->
                      if s==0
                      then (r <> eWord8 (fromIntegral (min l 255)) <> encode x,l-1,254)
                      else (r <> encode x,l-1,s-1)
                    )
             (mempty,length l,0) l
#endif

decodeList = DL.toList <$> getAsL_

-- TODO: test if it would it be faster with DList.unfoldr :: (b -> Maybe (a, b)) -> b -> Data.DList.DList a
getAsL_ = do
    tag <- dWord8
{-
    h <- gets tag
    t <- getAsL_
    return (DL.append h t)
-}

    case tag of
         0 -> return DL.empty
         _ -> do
           h <- gets tag
           t <- getAsL_
           return (DL.append h t)

  where
    gets 0 = return DL.empty
    gets n = DL.cons <$> decode <*> gets (n-1)

-- #define LIST_TAG

instance Flat a => Flat [a] where
#ifdef LIST_BIT
    encode = foldr (\x r -> eTrue <> encode x <> r) eFalse
#elif defined(LIST_TAG)
    encode = eBitList . map encode
#ifdef ARRDEC_DIRECT
    decode = dList
#elif defined(ARRDEC_REVERSE)
    decode = dListReverse
#endif

#elif defined(LIST_BYTE)
    encode = encodeList
    decode = decodeList
#endif

#ifdef LIST_BYTE
instance Flat T.Text where
  -- 100 times slower
  -- encode l = (mconcat . map (\t -> T.foldl' (\r x -> r <> encode x) (eWord8 . fromIntegral . T.length$ t) t) . T.chunksOf 255 $ l) <> eWord8 0
    -- -- 200 times slower
    -- encode = encode . T.unpack
    -- decode = T.pack <$> decodeList
   -- 4 times slower
   encode = encode . T.encodeUtf8
   decode = T.decodeUtf8 <$> decode
#endif

b = T.chunksOf 255 (T.pack "")

-- maps to BLOB NoEnc
instance Flat B.ByteString where
  encode bs = eFiller <> eBytes bs
  decode = (decode :: Get Filler) >> dBytes

instance Flat L.ByteString where
  encode bs = eFiller <> eLazyBytes bs
  decode = (decode :: Get Filler) >> dLazyBytes

--------------- Numbers (TODO:Floats)
-- See https://hackage.haskell.org/package/arith-encode

---------- Words and Ints

-- x = map (\v -> showEncoding $ encode (v::Word32)) [3,255,258]
{-
-- Little Endian encoding
| Coding                             | Min Len | Max Len   |
| data Unsigned = NonEmptyList Word7 | 8       | 10*8=80   | ascii equivalent,byte align
| data Unsigned = NonEmptyList Word8 | 9       | 8*9=72    |
| data Unsigned = List Word7         | 1       | 10*8+1=81 | ascii equivalent

data Integer = Integer (ZigZag VarWord)

data Int16 = Int16 (ZigZag Word16)

data Int8 = Int8 (ZigZag Word8)

data ZigZagEncoding a = ZigZagEncoding a

data Word16 = Word16 VarWord

-}
-- Encoded as: data Word8 = U0 | U1 .. | U255
instance Flat Word8 where
  encode = eWord8
  decode = dWord8

-- Word16 to Word64 are encoded as:
-- data VarWord = VarWord (NonEmptyList Word7)
-- data NonEmptyList a = Elem a | Cons a (NonEmptyList a)
-- data Word7 = U0 .. U127
-- VarWord is a sequence of bytes, where every byte except the last one has the most significant bit (msb) set.

instance Flat Word16 where
  encode = eUnsigned
  decode = dUnsigned

instance Flat Word32 where
  encode = eUnsigned
  decode = dUnsigned

instance Flat Word64 where
  encode = eUnsigned
  decode = dUnsigned

instance Flat Word where
  encode = eUnsigned
  decode = dUnsigned

-- Encoded as data Int8 = Z | N1 |P1| N2 |P2 | N3 .. |P127 | N128
instance Flat Int8 where
  encode = encode . zzEncode8
  decode = zzDecode8 <$> decode

-- Ints and Integer are encoded as
-- Encoded as ZigZag Word16
-- ZigZag indicates ZigZag encoding
-- where data ZigZag a = ZigZag a
instance Flat Int16 where
  encode = encode . zzEncode16
  decode = zzDecode16 <$> decode

instance Flat Int32 where
  encode = encode . zzEncode32
  decode = zzDecode32 <$> decode

instance Flat Int64 where
  encode = encode . zzEncode64
  decode = zzDecode64 <$> decode

instance Flat Int where

#if WORD_SIZE_IN_BITS == 64
  encode = encode . (fromIntegral :: Int -> Int64)
  decode = (fromIntegral :: Int64 -> Int) <$> decode

#elif WORD_SIZE_IN_BITS == 32
  encode = encode . (fromIntegral :: Int -> Int32)
  decode = (fromIntegral :: Int32 -> Int) <$> decode

#else
#error expected WORD_SIZE_IN_BITS to be 32 or 64
#endif

instance Flat Integer where
  encode = eUnsigned . zzEncodeInteger
  decode = zzDecodeInteger <$> dUnsigned

-- instance Flat Word7 where
--     encode = eBits 7 . fromIntegral . fromEnum
--     decode = toEnum . fromIntegral <$> dBits 7

----------------- Characters
-- data ASCII = ASCII Word7 deriving (Eq,Show,Generic)

-- instance Flat ASCII

-- -- BUG
-- w :: Word7
-- w =  toEnum 200 :: Word7

-- -- t2 = let i = 240 in (fromIntegral i :: Word7) <= (maxBound :: Word7)

-- g :: (Word7,Word7)
-- g = (minBound,maxBound)

-- t3 = fromASCII . toASCII $ 'à' -- '经'

-- toASCII :: Char -> ASCII
-- toASCII = ASCII . toEnum . ord

-- fromASCII :: ASCII -> Char
-- fromASCII (ASCII w7) = chr . fromIntegral $ w7

-- data Unicode = C0 .. C127 | Unicode Word32

{-
toUnicode c | ord c <=127 = C0
            | otherwise = Unicode . fromIntegral . ord $ c
-}
-- data Char = Char Word32
instance Flat Char where
  encode c = encode (fromIntegral . ord $ c :: Word32)
  decode =  chr . fromIntegral <$> (decode :: Get Word32)

  -- encode c | ord c <=127 = eFalse <> eBits 7 (fromIntegral . ord $ c)
  --          | otherwise   = eTrue  <> encode (fromIntegral . ord $ c :: Word32)

  -- decode =  do
  --     tag <- dBool
  --     if tag
  --       then chr . fromIntegral <$> (decode :: Get Word32)
  --       else chr . fromIntegral <$> dBits 7

{-
-- data Unicode = Unicode Word32
instance Flat Char where
  encode c = encode (fromIntegral . ord $ c :: Word32)

  decode = do
    w :: Word32 <- decode
    if w > 0x10FFFF
      then error $ "Not a valid Unicode code point: " ++ show w
      else return . chr .fromIntegral $ w
-}


---------- Tuples

instance (Flat a, Flat b) => Flat (a,b) where
  encode (a,b)           = encode a <> encode b
  decode                 = (,) <$> decode <*> decode

instance (Flat a, Flat b, Flat c) => Flat (a,b,c) where
    encode (a,b,c)         = encode a <> encode b <> encode c
    decode                 =  (,,) <$> decode <*> decode <*> decode

instance (Flat a, Flat b, Flat c, Flat d) => Flat (a,b,c,d) where
    encode (a,b,c,d)       = encode a <> encode b <> encode c <> encode d
    decode                 = (,,,) <$> decode <*> decode <*> decode <*> decode

instance (Flat a, Flat b, Flat c, Flat d, Flat e) => Flat (a,b,c,d,e) where
    encode (a,b,c,d,e)     = encode a <> encode b <> encode c <> encode d <> encode e
    decode                 = (,,,,) <$> decode <*> decode <*> decode <*> decode <*> decode

instance (Flat a, Flat b, Flat c, Flat d, Flat e, Flat f)
        => Flat (a,b,c,d,e,f) where
    encode (a,b,c,d,e,f)   = encode (a,(b,c,d,e,f))
    decode                 = (,,,,,) <$> decode <*> decode <*> decode <*> decode <*> decode <*> decode

instance (Flat a, Flat b, Flat c, Flat d, Flat e, Flat f, Flat g)
        => Flat (a,b,c,d,e,f,g) where
    encode (a,b,c,d,e,f,g) = encode (a,(b,c,d,e,f,g))
    decode                 = (,,,,,,) <$> decode <*> decode <*> decode <*> decode <*> decode <*> decode <*> decode

instance (Flat a, Flat b, Flat c, Flat d, Flat e,
          Flat f, Flat g, Flat h)
        => Flat (a,b,c,d,e,f,g,h) where
    encode (a,b,c,d,e,f,g,h) = encode (a,(b,c,d,e,f,g,h))
    decode                   = (,,,,,,,) <$> decode <*> decode <*> decode <*> decode <*> decode <*> decode <*> decode <*> decode

instance (Flat a, Flat b, Flat c, Flat d, Flat e,
          Flat f, Flat g, Flat h, Flat i)
        => Flat (a,b,c,d,e,f,g,h,i) where
    encode (a,b,c,d,e,f,g,h,i) = encode (a,(b,c,d,e,f,g,h,i))
    decode                     = (,,,,,,,,) <$> decode <*> decode <*> decode <*> decode <*> decode <*> decode <*> decode <*> decode <*> decode

instance (Flat a, Flat b, Flat c, Flat d, Flat e,
          Flat f, Flat g, Flat h, Flat i, Flat j)
        => Flat (a,b,c,d,e,f,g,h,i,j) where
    encode (a,b,c,d,e,f,g,h,i,j) = encode (a,(b,c,d,e,f,g,h,i,j))
    decode                       = (,,,,,,,,,) <$> decode <*> decode <*> decode <*> decode <*> decode <*> decode <*> decode <*> decode <*> decode <*> decode