module HMud.Account where

import Control.Monad.Except
import Data.ByteString (ByteString)
import qualified Data.Map.Strict as M
import Data.List (find)
import Data.Text (Text)
import qualified Data.Text as T

import HMud.Parser.Commands
import HMud.Errors
import HMud.SqliteLib (User(..), UserId)
import HMud.Types (ActiveUsers)

-- DUPLICATE from state.hs, should be moved somewhere more general
maybeToEither :: a -> Maybe b -> Either a b
maybeToEither _ (Just b) = Right b
maybeToEither a Nothing = Left a

checkPassword :: Text -> User -> Either AppError User
checkPassword pass user
    | pass /= userPassword user = Left InvalidPassword
    | otherwise = Right user

-- TODO: Add minimum password strength req
--validatePassword :: ByteString -> ByteString -> Either AppError Text
--validatePassword pass1BS pass2BS = do
--  let parsedPass1 = resultToEither $ parseByteString word mempty pass1BS
--  let parsedPass2 = resultToEither $ parseByteString word mempty pass2BS
--  case (parsedPass1, parsedPass2) of
--    (Right pass1, Right pass2) | pass1 == pass2 -> Right pass1
--                               | otherwise -> Left PasswordsDontMatch
--    (Right _, Left _) -> Left InvalidCommand
--    (Left _, _) -> Left InvalidCommand

usernameRegistered :: [User] -> Text -> Bool
usernameRegistered users user =
  let users' = userUsername <$> users
      user' = T.strip user
  in case find (== user') users' of
    Just _ -> True
    Nothing -> False

findUserByName :: [User] -> Text -> Either AppError User
findUserByName users acc =
  maybeToEither NoSuchUser $ find (\user -> userUsername user == acc) users

--validateUsername :: [User] -> ByteString -> Either AppError Text
--validateUsername users usernameBS = do
--  username <- resultToEither $ parseByteString word mempty usernameBS
--  if usernameRegistered users username
--    then Right username
--    else Left NoSuchUser

usernameIsAvailable :: MonadError AppError m => [User] -> ByteString -> m Text
usernameIsAvailable users usernameBS = do
  username <- runWordParse usernameBS
  if usernameRegistered users username
    then throwError UsernameAlreadyExists
    else pure username

userIsLoggedIn :: ActiveUsers -> UserId -> Bool
userIsLoggedIn activeUsers userId =
  case M.lookup userId activeUsers of
    Just _ -> True
    Nothing -> False