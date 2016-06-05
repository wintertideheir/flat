
Haskell implementation of [Flat](http://quid2.org), a minimalist binary data format ([specs](http://quid2.org/docs/Flat.pdf)).

 ### Installation

Install as part of the [quid2](https://github.com/tittoassini/quid2) project.

 ### Brief Tutorial for Haskellers

Flat is a binary data format, similar to `binary` or `cereal`.

To (de)serialise a data type it needs to be an instance of the 'Flat' class.

There is `Generics` based support to automatically define instances.

So, let's enable `Generics`:

```haskell
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE NoMonomorphismRestriction #-}
```

Import the Flat library:

```haskell
import Data.Flat
```

Define a couple of custom data types:

```haskell
data Direction = North | South | Center | East | West deriving (Show,Generic)
```

```haskell
data List a = Cons a (List a) | Nil deriving (Show,Generic)
```

Automatically derive the instances:

```haskell
instance Flat Direction
instance Flat a => Flat (List a)
```

A little utility function, `bits` encodes the value, `prettyShow` displays it nicely:

```haskell
pp :: Flat a => a -> String
pp = prettyShow . bits
```

```haskell
e1 = pp Center
```
e1 -> "<10>"

```haskell
e2 = pp (Nil::List Direction)
```
e2 -> "<1>"

```haskell
e3 = pp $ Cons North (Cons South Nil)
```
e3 -> "<0000011>"


These encodings shows a pecularity of Flat, it uses an optimal bit-encoding rather than more usual byte-oriented one.

Instances for a few common data types (Bool,Tuples, Lists, String, Text ..) are already defined (in `Data.Flat.Instances):

-- To be able to serialize them we need a Flat instance
-- No big deal, it can be derived automatically.
instance Flat Number
instance Flat Numero
instance (Flat a , Flat b) => Flat (Couple a b)

-- Serialize a value
e1 = encoded $ Couple One Due
-- One has been encoded as '00', Due as '01', the rest is byte-padding.

-- Now get it back
d1 = decoded e1 :: Decoded (Couple Number Numero)

-- One more time
d2 :: Decoded (Couple Numero Number)
d2 = decoded . Encoded . bytes $ e1

See the [source code](http://github.com/tittoassini/flat/src/README.lhs) of this file. 
