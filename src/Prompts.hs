{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE OverloadedStrings #-}
module Prompts where

import Control.Concurrent.STM
import Control.Monad.Except
import Control.Monad.Reader
import qualified Data.Map.Strict as M
import Data.Text (Text)
import qualified Data.Text as T

import Account
import Commands
import Dispatch
import Errors
import Parser
import State
import SqliteLib (User(..))
import Types
  ( GameState(..)
  , HasConnectionHandle(..)
  , MonadDB(..)
  , MonadGameState(..)
  , MonadPlayer(..)
  , MonadThread(..)
  , MonadPrompt(..)
  , MonadTChan(..)
  , UserEnv(..)
  , Response(..)
  )
import World


mainMenuPrompt ::
  ( MonadReader UserEnv m
  , MonadIO m
  , MonadThread m
  , MonadGameState m
  , MonadPrompt m
  , MonadTChan m
  , MonadPlayer m
  , MonadDB m
  ) => m (Either AppError Response)
mainMenuPrompt = do
  env <- ask
  respTChan <- asks userEnvRespTchan
  mapM_ (writeChannel respTChan . RespAnnounce) ["Welcome to hMud", "Options: register, login, exit"]

  cmdTchan  <- asks userEnvCmdTChan
  writeChannel respTChan $ Prompt "> "
  resp <- readChannel cmdTchan

  case resp of
    Right Exit -> do
      socket <- asks userEnvHandle
      threadId <- getThread
      pure . Right $ RespExit threadId socket
    Right Login    -> runExceptT $ runReaderT loginPrompt env
    Right Register -> runExceptT $ runReaderT registerPrompt env
    _ -> return $ Left InvalidCommand

loginPrompt ::
  ( MonadReader UserEnv m
  , MonadDB m
  , MonadGameState m
  , MonadPrompt m
  , MonadTChan m
  , MonadPlayer m
  , MonadError AppError m
  ) => m Response
loginPrompt = do
  activeUsers <- globalActiveUsers <$> readState
  playerMap'  <- globalPlayerMap <$> readState
  respTChan   <- asks userEnvRespTchan
  cmdTchan    <- asks userEnvCmdTChan
  handle      <- asks getConnectionHandle
  users       <- selectAllUsers handle

  writeChannel respTChan $ Prompt "Login: "
  username <- readCmd cmdTchan
  writeChannel respTChan $ Prompt "Password: "
  suppressEcho
  password <- readCmd cmdTchan
  unsuppressEcho
  let loginResult = verifyLogin username password users

  case loginResult of
    Left e -> throwError e
    Right user ->
      if userIsLoggedIn activeUsers (userUserId user)
      then loginPrompt
      else do
        let uid = userUserId user
            activeUsersMap = M.insert (userUserId user) user activeUsers
            playerMap'' = addPlayer uid 1 playerMap'
        setUser uid
        setState $ GameState activeUsersMap world playerMap''
        return . RespAnnounce $ userUsername user `T.append` " Logged In"

-- TODO: Replace with Lens
verifyLogin :: Command -> Command -> [User] -> Either AppError User
verifyLogin username password users =
  case (username, password) of
    (Word username', Word password') -> do
      user <- findUserByName users username'
      checkPassword password' user
    _ -> Left InvalidCommand

usernameRegPrompt ::
  ( MonadReader UserEnv m
  , MonadDB m
  , MonadPrompt m
  ) => m (Either AppError Text)
usernameRegPrompt = do
  conn <- asks getConnectionHandle
  users <- selectAllUsers conn
  usernameBS <- prompt "username: "
  return $ validateUsername users usernameBS

passwordRegPrompt ::
  ( MonadReader UserEnv m
  , MonadPrompt m
  ) => m (Either AppError Text)
passwordRegPrompt = do
  suppressEcho
  password  <- prompt "password: "
  password' <- prompt "repeat password: "
  unsuppressEcho
  return $ validatePassword password password'

registerPrompt ::
  ( MonadReader UserEnv m
  , MonadDB m
  , MonadGameState m
  , MonadPlayer m
  , MonadPrompt m
  , MonadError AppError m
  , MonadIO m
  , MonadTChan m
  ) => m Response
registerPrompt = do
  handle <- asks getConnectionHandle
  users <- selectAllUsers handle
  --username <- prompt "username: " >>= usernameIsAvailable users

  respTChan   <- asks userEnvRespTchan
  cmdTchan    <- asks userEnvCmdTChan

  writeChannel respTChan $ Prompt "Username: "
  username' <- readCmd cmdTchan
  writeChannel respTChan $ Prompt "Password: "
  suppressEcho
  password1' <- readCmd cmdTchan
  unsuppressEcho
  writeChannel respTChan $ Prompt "Repeat Password: "
  suppressEcho
  password2' <- readCmd cmdTchan
  unsuppressEcho

  case (username', password1', password2') of
    (Word username, Word password1, Word password2) ->
      if not $ usernameRegistered users username
        then
          if password1 == password2
            then do
              insertUser handle (User 0 username password1)
              pure $ RespRegister username
            else throwError PasswordsDontMatch
        else throwError UsernameAlreadyExists
    _ -> registerPrompt

  --case  username of
  --  -- TODO: Handle bad username/password notification
  --  Left err -> liftIO (print err) >> registerPrompt
  --  Right username' -> pure $ RespRegister username' -- do
  --        passwordM <- passwordRegPrompt
  --        case passwordM of
  --            -- TODO: Only require the user to re-enter password
  --            Left _     -> registerPrompt
  --            Right pass -> do
  --              insertUser conn (User 0 username' pass)
  --              pure $ RespRegister username'

gamePrompt ::
  forall m.
  ( MonadReader UserEnv m
  , MonadIO m
  --, MonadPrompt m
  , MonadGameState m
  , MonadTChan m
  ) => m (Either AppError Response)
gamePrompt = do
  env       <- ask
  cmdTchan  <- asks userEnvCmdTChan
  respTChan <- asks userEnvRespTchan
  writeChannel respTChan $ Prompt "> "
  resp      <- readChannel cmdTchan
  case resp of
    Right cmd -> runExceptT $ runReaderT (execCommand cmd) env
    Left err  -> return $ Left err


readCmd ::
  ( MonadTChan m
  , MonadError AppError m
  ) => TChan (Either AppError Command) -> m Command
readCmd tchan = do
  resp <- readChannel tchan
  case resp of
    Left err -> throwError err
    Right cmd -> return cmd
