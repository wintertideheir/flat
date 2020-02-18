module Main where
import           Test.Tasty
import           Test.Tasty.HUnit
import qualified DocTest.Flat.Instances.Array
import qualified DocTest.Flat.Instances.ByteString
import qualified DocTest.Flat.Instances.DList
import qualified DocTest.Flat.Instances.Containers
import qualified DocTest.Flat.Instances.Base
import qualified DocTest.Flat.Instances.Unordered
import qualified DocTest.Flat.Instances.Vector
import qualified DocTest.Flat.Instances.Mono
import qualified DocTest.Flat.Instances.Text
import qualified DocTest.Flat.Decoder.Prim
import qualified DocTest.Data.FloatCast
import qualified DocTest.Flat.Endian
import qualified DocTest.Data.ZigZag

main = (testGroup "DocTests" <$> sequence [DocTest.Flat.Instances.Array.tests,DocTest.Flat.Instances.ByteString.tests,DocTest.Flat.Instances.DList.tests,DocTest.Flat.Instances.Containers.tests,DocTest.Flat.Instances.Base.tests,DocTest.Flat.Instances.Unordered.tests,DocTest.Flat.Instances.Vector.tests,DocTest.Flat.Instances.Mono.tests,DocTest.Flat.Instances.Text.tests,DocTest.Flat.Decoder.Prim.tests,DocTest.Data.FloatCast.tests,DocTest.Flat.Endian.tests,DocTest.Data.ZigZag.tests]) >>= defaultMain
