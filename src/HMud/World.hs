module HMud.World where

import qualified Data.Map.Strict as M
import HMud.Types

frontHallDescription :: Description
frontHallDescription =
  "Light shines down on you through lace curtained window. The oaken floor\
  \creaks as you adjust your weight. Dust piles up in the corners and you\
  \sense a great tragedy occured here once, many years ago\
  \To the north you see a door to the kitchen."

frontHall :: Room
frontHall = Room
  { roomName = "The Fronthall"
  , roomDescription = frontHallDescription
  , roomRoomId = RoomId 1
  , roomAdjacent = M.fromList [(N, RoomId 2)]
  }

kitchenDescription :: Description
kitchenDescription =
  "You are standing in kitchen. The floor is tiled with black and white\
  \linoleum. There is a propane stove, and a Kitchenmade Refrigerator."

kitchen :: Room
kitchen = Room
  { roomName = "The Kitchen"
  , roomDescription = kitchenDescription
  , roomRoomId = RoomId 2
  , roomAdjacent = M.fromList [(S, RoomId 1)]
  }

rooms :: [Room]
rooms = [kitchen, frontHall]

world :: WorldMap
world = M.fromList $ fmap f rooms
    where f room = (roomRoomId room, room)

playerMap :: PlayerMap
playerMap = M.map (const []) world
