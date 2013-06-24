module Bitcoin.LevelDB
( BlockIndex(..)
, openHandle
, buildBlockIndex
, writeBlock
, readBlock
) where

import Data.Default

import Bitcoin.Protocol
import Bitcoin.Protocol.Block
import Bitcoin.Protocol.BlockHeader
import Bitcoin.Util

import Control.Monad
import Control.Monad.State
import Control.Monad.IO.Class
import Control.Monad.Trans.Resource
import Control.Applicative

import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as BSC

import qualified Database.LevelDB as DB

data BlockIndex = BlockIndex 
    { biHash      :: Word256
    , biPrev      :: Word256
    , biHeight    :: Word32
    , biTx        :: Word32
    , biChainWork :: Word256
    , biChainTx   :: Word32
    , biFile      :: Word32
    , biDataPos   :: Word32
    , biUndoPos   :: Word32
    , biStatus    :: Word32
    } deriving (Eq, Read, Show)

instance BitcoinProtocol BlockIndex where

    bitcoinGet = BlockIndex <$> getWord256be
                            <*> getWord256be
                            <*> getWord32le
                            <*> getWord32le
                            <*> getWord256be
                            <*> getWord32le
                            <*> getWord32le
                            <*> getWord32le
                            <*> getWord32le
                            <*> getWord32le

    bitcoinPut (BlockIndex h p he tx cw ct f d u s) = do
        putWord256be h
        putWord256be p
        putWord32le  he
        putWord32le  tx
        putWord256be cw
        putWord32le  ct
        putWord32le  f
        putWord32le  d
        putWord32le  u
        putWord32le  s

openHandle :: ResourceT IO DB.DB
openHandle = do
    db <- DB.open "blockindex"
        DB.defaultOptions
            { DB.createIfMissing = True
            , DB.cacheSize = 2048
            }
    return db

buildBlockIndex :: Block -> BlockIndex
buildBlockIndex b = 
    BlockIndex (fromIntegral 1234)
        (prevBlock h)
        (fromIntegral 1)
        (fromIntegral 2)
        (fromIntegral 3)
        (fromIntegral 4)
        (fromIntegral 5)
        (fromIntegral 6)
        (fromIntegral 7)
        (fromIntegral 8)
    where h  = blockHeader b

readBlock :: MonadResource m => DB.DB -> Word256 -> m (Maybe BlockIndex)
readBlock db w = do
    let key = toStrictBS . runPut . putWord256be $ w
    val <- DB.get db def (bsToBSC key)
    return $ val >>= return . (runGet bitcoinGet) . toLazyBS . bscToBS

writeBlock :: MonadResource m => DB.DB -> BlockIndex -> m ()
writeBlock db bi = do
    let key = toStrictBS . runPut . putWord256be $ biHash bi
    let payload = toStrictBS . runPut . bitcoinPut $ bi
    DB.put db def (bsToBSC key) (bsToBSC payload)
    return ()

