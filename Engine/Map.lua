--[[
-- Map class
-- The map is in charge of creaating the scenario where the game is played - it spawns a bunch of rocks, walls, floors and guardians, and a player.
-- Map:reset() restarts the map. It can be done when the player dies, or manually.
-- Map:update() updates the visible entities on a given rectangle (by default, what's visible on the screen). See main.lua to see how to update
-- all entities instead.
--]]
local class       = require 'Helpers.middleclass'
local bump        = require 'Helpers.bump'
local bump_debug  = require 'Helpers.bump_debug'

local media       = require 'Engine.Media'

local Enemy       = require 'Entities.Enemy'
local Player      = require 'Entities.Player'
local Block       = require 'Entities.Block'
local Guardian    = require 'Entities.Guardian'

local random = math.random

local sortByUpdateOrder = function(a,b)
  return a:getUpdateOrder() < b:getUpdateOrder()
end

local sortByCreatedAt = function(a,b)
  return a.created_at < b.created_at
end

local Map = class('Map')

function Map:initialize(width, height, camera, lightworld)
  self.width  = width
  self.height = height
  self.camera = camera
  self.lightworld = lightworld

  self:reset()
end

function Map:reset()
  local music = media.music
  music:rewind()
  music:play()

  local width, height = self.width, self.height
  self.world  = bump.newWorld()
  self.player = Player:new(self, self.world, 60, 60, self.camera, self.lightworld)
  self.enemy = Enemy:new(self, self.world, width - 80, 60, self.camera, self.lightworld)

  --[[ walls & ceiling
  Block:new(self.world,        0,         0, width,        32, true)
  Block:new(self.world,        0,        32,    32, height-64, true)
  Block:new(self.world, width-32,        32,    32, height-64, true)

  -- tiled floor
  local tilesOnFloor = 40
  for i=0,tilesOnFloor - 1 do
    Block:new(self.world, i*width/tilesOnFloor, height-32, width/tilesOnFloor, 32, true)
  end]]

end


function Map:update(dt, l,t,w,h)
  l,t,w,h = l or 0, t or 0, w or self.width, h or self.height
  local visibleThings, len = self.world:queryRect(l,t,w,h)

  table.sort(visibleThings, sortByUpdateOrder)

  for i=1, len do
    visibleThings[i]:update(dt)
  end
end

function Map:draw(drawDebug, l,t,w,h)
  if drawDebug then bump_debug.draw(self.world, l,t,w,h) end

  local visibleThings, len = self.world:queryRect(l,t,w,h)

  table.sort(visibleThings, sortByCreatedAt)

  for i=1, len do
    visibleThings[i]:draw(drawDebug)
  end
end


return Map
