module Parser (commandParser, resultToEither, runParse, word)  where

import Control.Applicative
import Data.ByteString (ByteString)
import Data.Functor (($>))
import Data.Text (Text)
import qualified Data.Text as T
import Text.Trifecta

import Types (User(..), Command(..))


word :: Parser Text
word = token $ T.pack <$> some letter

parserGetUsers :: Parser Command
parserGetUsers = symbol "getUsers" $> GetUsers

parserGetUser :: Parser Command
parserGetUser = token $ do
    _ <- string "getUser"
    _ <- char ' '
    username' <- word
    return $ GetUser username'

parserAddUser :: Parser Command
parserAddUser = token $ do
    _ <- string "addUser"
    _ <- char ' '
    username' <- word
    password' <- word
    return $ AddUser (User 0 username' password')

parserExit :: Parser Command
parserExit = token $ do
    _ <- symbol "exit"
    return Exit

parserShutdown :: Parser Command
parserShutdown = token $ do
    _ <- symbol "shutdown"
    return Shutdown

parserLogout :: Parser Command
parserLogout = token $ do
    _ <- symbol "logout"
    return Logout

parserWhois :: Parser Command
parserWhois = token $ do
    _ <- symbol "whois"
    return Whois

parserSay :: Parser Command
parserSay = token $ do
    _ <- symbol "say"
    str <- anyChar `manyTill` (char '\r' <|> char '\n')
    return $ Say (T.pack str)

parserEcho :: Parser Command
parserEcho = token $ do
    _ <- symbol "echo"
    str <- anyChar `manyTill` (char '\r' <|> char '\n')
    return $ Echo (T.pack str)

commandParser :: Parser Command
commandParser =  parserGetUsers 
             <|> parserGetUser 
             <|> parserAddUser 
             <|> parserExit
             <|> parserShutdown
             <|> parserEcho
             <|> parserLogout
             <|> parserWhois
             <|> parserSay

runParse :: ByteString -> Either Text Command
runParse = resultToEither . parseByteString commandParser mempty
    
resultToEither :: Result a -> Either Text a
resultToEither (Failure err') = Left . T.pack $ show err'
resultToEither (Success a) = Right a