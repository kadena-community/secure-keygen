{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE OverloadedStrings #-}
module Main where

------------------------------------------------------------------------------
import           Control.Monad
import           Control.Monad.IO.Class
import           Control.Monad.Trans.State
import           Crypto.Error
import           Crypto.PubKey.Ed25519
import           Crypto.Random.Types
import qualified Data.ByteString.Base64.URL as B64
import           Data.ByteArray (ByteArray)
import qualified Data.ByteArray as BA
import           Data.ByteArray.Encoding
import           Data.ByteString (ByteString)
import qualified Data.ByteString as B
import qualified Data.ByteString.Char8 as CB
import qualified Data.ByteString.Lazy as LB
import           Data.ByteString.Builder
import           Data.Char
import           Data.Map (Map)
import qualified Data.Map as M
import           Data.Functor.Identity
import           Data.Word
import           Options.Applicative
import           System.Environment
import           System.IO
import           Text.PrettyPrint.ANSI.Leijen (string)
import           Text.Printf
------------------------------------------------------------------------------

verifySig
  :: ByteString
  -- ^ Public key in hex
  -> ByteString
  -- ^ Signature in hex
  -> ByteString
  -- ^ base64url-encoded message
  -> Bool
verifySig keyHex sigHex msgBase64 = verify pubkey msg sig
  where
    msg = B64.decodeLenient msgBase64
    CryptoPassed pubkey = publicKey $ LB.toStrict $ toLazyByteString $ hexToRaw keyHex
    CryptoPassed sig = signature $ LB.toStrict $ toLazyByteString $ hexToRaw sigHex

instance ByteArray ba => MonadRandom (StateT ba Identity) where
    getRandomBytes n = StateT $ \bs ->
      let (firstN, rest) = BA.splitAt n bs
       in Identity (BA.convert firstN, rest)

supplyEntropy :: StateT ByteString Identity a -> ByteString -> a
supplyEntropy m bs = runIdentity $ evalStateT m bs

conserveEntropy :: StateT ByteString Identity a -> ByteString -> (a, ByteString)
conserveEntropy m bs = runIdentity $ runStateT m bs

data Options
  = DiceToHex
  | HexToEntropy
  | MakeKeyPair
  deriving (Eq,Ord,Show,Read)

d2h :: Mod CommandFields Options
d2h = command "d2h" $ info (pure DiceToHex <**> helper) i
  where
    i = fullDesc
        <> header synopsis
        <> progDesc synopsis
    synopsis = "Convert dice roll data to hex entropy"

h2e :: Mod CommandFields Options
h2e = command "h2e" $ info (pure HexToEntropy <**> helper) i
  where
    i = fullDesc
        <> header synopsis
        <> progDesc synopsis
    synopsis = "Convert hex data to raw entropy"

mkp :: Mod CommandFields Options
mkp = command "keys" $ info (pure MakeKeyPair <**> helper) i
  where
    i = fullDesc
        <> header synopsis
        <> progDesc synopsis
    synopsis = "Generate keys from raw entropy"

commandOpt :: Parser Options
commandOpt = subparser $
    d2h <> h2e <> mkp

main :: IO ()
main = do
    cmd <- customExecParser p opts
    case cmd of
      DiceToHex -> diceToHexFile
      HexToEntropy -> hexToEntropyFile
      MakeKeyPair -> do
        sk <- supplyEntropy generateSecretKey <$> B.hGetContents stdin
        CB.putStrLn $ "public: " <> convertToBase Base16 (toPublic sk)
        CB.putStrLn $ "secret: " <> convertToBase Base16 sk
  where
    opts = info (commandOpt <**> helper) mods
    mods = progDescDoc $ Just $ string $ unlines
      [ "Deterministic ED25519 Key Generation"
      , ""
      , "Each command gets input from stdin and writes output to stdout."
      ]
    p = prefs showHelpOnEmpty

isWhitespace :: Word8 -> Bool
isWhitespace 10 = True
isWhitespace 13 = True
isWhitespace 32 = True
isWhitespace _ = False

diceToHexFile :: IO ()
diceToHexFile = do
    rolls <- B.filter (not . isWhitespace) <$> B.hGetContents stdin
    if B.all isDiceRoll rolls
      then LB.hPut stdout $ toLazyByteString $ binToHex $ LB.toStrict $ toLazyByteString $ diceToEntropy rolls
      else putStrLn "File contains invalid dice rolls.  Every character must be a digit in the range 1-6."

isHex :: Word8 -> Bool
isHex = isHexDigit . chr . fromIntegral

hexToEntropyFile :: IO ()
hexToEntropyFile = do
    hexBytes <- B.filter (not . isWhitespace) <$> B.hGetContents stdin
    if B.all isHex hexBytes
      then LB.hPut stdout $ toLazyByteString $ hexToRaw hexBytes
      else putStrLn "File contains invalid hex characters.  Every character must be a digit in the range 0-f."

diceToEntropy :: ByteString -> Builder
diceToEntropy bs =
    if B.length cur <= 1
      then mempty
      else case M.lookup cur diceTable of
             Nothing -> error ("Dice data contained invalid characters: " <> show cur)
             Just bin -> byteString bin <> diceToEntropy rest
  where
    (cur, rest) = B.splitAt 2 bs

binToHex :: ByteString -> Builder
binToHex bs =
    if B.length cur < 4
      then mempty
      else case M.lookup cur binHex of
             Nothing -> error ("Binary data contained invalid characters: " <> show cur)
             Just bin -> byteString bin <> binToHex rest
  where
    (cur, rest) = B.splitAt 4 bs

hexToRaw :: ByteString -> Builder
hexToRaw bs =
    if B.length cur < 2
      then mempty
      else case rawByte of
             Nothing -> error ("Hex data contained invalid characters: " <> show cur)
             Just bin -> word8 bin <> hexToRaw rest
  where
    (cur, rest) = B.splitAt 2 bs
    rawByte = do
        a <- M.lookup (B.index cur 0) hexToWord
        b <- M.lookup (B.index cur 1) hexToWord
        return (a * 16 + b)

hexToWord :: Map Word8 Word8
hexToWord = M.fromList $ zip ([48..57] <> [97..102]) [0..15]

binaryChar 0 = '0'
binaryChar 1 = '1'

diceTable :: Map ByteString ByteString
diceTable = M.fromList
  [ ("11","00000")
  , ("12","00001")
  , ("13","00010")
  , ("14","00011")
  , ("15","00100")
  , ("16","00101")
  , ("21","00110")
  , ("22","00111")
  , ("23","01000")
  , ("24","01001")
  , ("25","01010")
  , ("26","01011")
  , ("31","01100")
  , ("32","01101")
  , ("33","01110")
  , ("34","01111")
  , ("35","10000")
  , ("36","10001")
  , ("41","10010")
  , ("42","10011")
  , ("43","10100")
  , ("44","10101")
  , ("45","10110")
  , ("46","10111")
  , ("51","11000")
  , ("52","11001")
  , ("53","11010")
  , ("54","11011")
  , ("55","11100")
  , ("56","11101")
  , ("61","11110")
  , ("62","11111")
  , ("63","")
  , ("64","")
  , ("65","")
  , ("66","")
  ]

binHex :: Map ByteString ByteString
binHex = M.fromList
  [ ("0000", "0")
  , ("0001", "1")
  , ("0010", "2")
  , ("0011", "3")
  , ("0100", "4")
  , ("0101", "5")
  , ("0110", "6")
  , ("0111", "7")
  , ("1000", "8")
  , ("1001", "9")
  , ("1010", "a")
  , ("1011", "b")
  , ("1100", "c")
  , ("1101", "d")
  , ("1110", "e")
  , ("1111", "f")
  ]

isDiceRoll :: Word8 -> Bool
isDiceRoll r = r >= 49 && r <= 54
