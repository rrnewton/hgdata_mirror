-----------------------------------------------------------------------------
--
-- Module      :  Network.Google
-- Copyright   :
-- License     :  AllRightsReserved
--
-- Maintainer  :
-- Stability   :
-- Portability :
--
-- |
--
-----------------------------------------------------------------------------


{-# LANGUAGE FlexibleInstances #-}


module Network.Google (
  AccessToken
, appendBody
, appendHeaders
, doRequest
, makeProjectRequest
, makeRequest
, makeRequestValue
, toAccessToken
) where


import Control.Monad.Trans.Resource (ResourceT)
import Data.Maybe (fromJust)
import Data.ByteString.Util (lbsToS)
import Data.ByteString as BS (ByteString)
import Data.ByteString.Char8 as BS8 (ByteString, append, pack)
import Data.ByteString.Lazy.Char8 as LBS8 (ByteString)
import Data.CaseInsensitive as CI (CI(..), mk)
import Network.HTTP.Conduit (Request(..), RequestBody(..), Response(..), def, httpLbs, responseBody, withManager)
import Text.XML.Light (Element, parseXMLDoc)


type AccessToken = BS.ByteString


toAccessToken :: String -> AccessToken
toAccessToken = BS8.pack


makeRequest :: AccessToken -> (String, String) -> String -> (String, String) -> Request m
makeRequest accessToken (apiName, apiVersion) method (host, path) =
  def {
    method = BS8.pack method
  , secure = True
  , host = BS8.pack host
  , port = 443
  , path = BS8.pack path
  , requestHeaders = [
      (makeHeaderName apiName, BS8.pack apiVersion)
    , (makeHeaderName "Authorization",  BS8.append (BS8.pack "OAuth ") accessToken)
    ]
  }


makeProjectRequest :: String -> AccessToken -> (String, String) -> String -> (String, String) -> Request m
makeProjectRequest projectId accessToken api method hostPath =
  appendHeaders
    [
      ("x-goog-project-id", projectId)
    ]
    (makeRequest accessToken api method hostPath)


class DoRequest a where
  doRequest :: Request (ResourceT IO) -> IO a


instance DoRequest () where
  doRequest request =
    do
      withManager $ httpLbs request
      return ()


instance DoRequest [(String, String)] where
  doRequest request =
    do
      response <- withManager $ httpLbs request
      -- TODO: replace "read . show" with a chain of packing and unpacking functions
      return $ read . show $ responseHeaders response


instance DoRequest LBS8.ByteString where
  doRequest request =
    do
      response <- withManager $ httpLbs request
      return $ responseBody response


instance DoRequest String where
  doRequest request =
    do
      result <- doRequest request
      return $ lbsToS result


instance DoRequest Element where
  doRequest request =
    do
      result <- (doRequest request :: IO LBS8.ByteString)
      return $ fromJust $ parseXMLDoc result


makeRequestValue :: String -> BS8.ByteString
makeRequestValue = BS8.pack


makeHeaderName :: String -> CI.CI BS8.ByteString
makeHeaderName = CI.mk . BS8.pack


makeHeaderValue :: String -> BS8.ByteString
makeHeaderValue = BS8.pack


appendHeaders :: [(String, String)] -> Request m -> Request m
appendHeaders headers request =
  let
    headerize :: (String, String) -> (CI.CI BS8.ByteString, BS8.ByteString)
    headerize (n, v) = (makeHeaderName n, makeHeaderValue v)
  in
    request {
      requestHeaders = requestHeaders request ++ map headerize headers
    }


appendBody :: LBS8.ByteString -> Request m -> Request m
appendBody bytes request =
  request {
    requestBody = RequestBodyLBS bytes
  }