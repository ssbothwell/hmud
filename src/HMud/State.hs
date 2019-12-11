module HMud.State where

import qualified Data.Map.Strict as M
import Data.List (intersperse, find)
import Data.Text (Text)
import qualified Data.Text as T

import HMud.Errors
import HMud.SqliteLib
  (formatUser
  , User(..)
  , UserId
  )
import HMud.Types
  ( ActiveUsers
  , GameState(..)
  , PlayerMap
  , RoomId
  )


maybeToEither :: a -> Maybe b -> Either a b
maybeToEither _ (Just b) = Right b
maybeToEither a Nothing = Left a

----------------------------------
---- GameState Manipulation ----
----------------------------------

--- ActiveUsers ---

removeUser :: UserId -> ActiveUsers -> ActiveUsers
removeUser = M.delete

addUser :: User -> ActiveUsers -> ActiveUsers
addUser user activeUsers =
  let uid = userUserId user
  in M.insert uid user activeUsers

whois :: GameState -> Text
whois state =
 let users = M.elems $ globalActiveUsers state
     formatedUsers = formatUser <$> users
 in T.concat . intersperse (T.pack "\n") $ formatedUsers

--- PlayerMap ---

replacePlayerMap :: GameState -> PlayerMap -> GameState
replacePlayerMap (GameState activeUsers' world _) =
  GameState activeUsers' world

removePlayer :: UserId -> RoomId -> PlayerMap -> PlayerMap
removePlayer uid =
  M.adjust (filter (/= uid))

addPlayer :: UserId -> RoomId -> PlayerMap -> PlayerMap
addPlayer uid =
  M.adjust ((:) uid)

lookupPlayer :: UserId -> ActiveUsers -> Either AppError User
lookupPlayer uid activeUsers' =
  let user = M.lookup uid activeUsers'
  in maybe (Left NoSuchUser) Right user

swapPlayer :: UserId -> RoomId -> RoomId -> PlayerMap -> PlayerMap
swapPlayer uid rid rid' =
  addPlayer uid rid' . removePlayer uid rid

findPlayer :: UserId -> PlayerMap -> Either AppError (RoomId, UserId)
findPlayer uid playerMap' =
  let f :: (RoomId, [UserId]) -> [(RoomId, UserId)]
      f (i, xs) = (,) i <$> xs
      players :: [(RoomId, UserId)]
      players = concatMap f (M.toList playerMap')
      g :: (RoomId, UserId) -> Bool
      g (_, uid') = uid == uid'
      player :: Maybe (RoomId, UserId)
      player = find g players
  in maybeToEither UserNotInPlayerMap player

findAndSwapPlayer :: UserId -> RoomId -> PlayerMap -> PlayerMap
findAndSwapPlayer uid rid playerMap' =
  case findPlayer uid playerMap' of
    Right (rid', _) -> swapPlayer uid rid' rid playerMap'
    _ -> addPlayer uid rid playerMap'