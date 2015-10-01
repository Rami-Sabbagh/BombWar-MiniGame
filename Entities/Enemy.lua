--[[
-- Player Class
-- This entity collides "sliding" over walls and floors.
--
-- It also models flying (when at full health) and jumping (when not at full health).
--
-- Health continuously regenerates. The player can survive 1 hit from a grenade, but the second one needs to happen
-- at least 4 secons later. Otherwise they player will die.
--
-- The most interesting method is :update() - it's a high level description of how the player behaves
--
-- Players need to have a Map on their constructor because they will call map:reset() before dissapearing.
--
--]]
local class  = require 'Helpers.middleclass'
local util   = require 'Engine.Util'
local media  = require 'Engine.Media'

local Entity = require 'Entities.Entity'
local Grenade  = require 'Entities.Grenade'
local Debris = require 'Entities.Debris'
local Puff   = require 'Entities.Puff'

local tween = require("Helpers.tween")
local Signal = require("Helpers.hump.signal")

local Enemy = class('Enemy', Entity)
Enemy.static.updateOrder = 1


local deadDuration  = 3   -- seconds until res-pawn
local runAccel      = 250 -- the player acceleration while going left/right
local brakeAccel    = 1000
local jumpVelocity  = 200 -- the initial upwards velocity when jumping
local width         = 16
local height        = 32
local beltWidth     = 1
local beltHeight    = 4

local Phi           = 0.61803398875
local activeRadius  = 100
local fireCoolDown  = 0.75 -- how much time the guardian takes to "regenerate a grenade"
local aimDuration   = 1.25 -- time it takes to "aim"
local targetCoolDown = 2 -- minimum time between "target acquired" chirps

local abs = math.abs

function Enemy:initialize(map, world, x,y, camera, lightworld)
  Entity.initialize(self, world, x, y, width, height)
  self.health = 1
  self.deadCounter = 0
  self.map = map
  
  self.camera = camera
  self.fireTimer = 0
  self.aimTimer  = 0
  self.timeSinceLastTargetAquired = targetCoolDown
  
  self.lightParams = {range=0}
  self.lightTween = tween.new(1,self.lightParams,{range=0})
  self.lightworld = lightworld
  if self.lightworld then self.light = self.lightworld.newLight(x+width/2, y+height, 0,0,0, 150) self.light.setGlowStrength(0.3) end
  if self.lightworld then self.lamp = self.lightworld.newLight(x+width/2, y+height, 255,255,255, 0) self.lamp.setGlowStrength(1) end
  self.signalDestroy = Signal.register("love_keypressed", function(key)
    if key == "s" then
      self.lampToggle = not self.lampToggle
    end
  end)
end

function Enemy:filter(other)
  local kind = other.class.name
  if kind == 'Guardian' or kind == "Player" or kind == 'Block' or (kind == 'Platform' and other:canPass(self.l,self.t,self.w,self.h)) then return 'slide' end
end

function Enemy:changeVelocityByKeys(dt)
  self.isJumpingOrFlying = false

  if self.isDead then return end

  local vx, vy = self.vx, self.vy

  if love.keyboard.isDown("a") then
    vx = vx - dt * (vx > 0 and brakeAccel or runAccel)
  elseif love.keyboard.isDown("d") then
    vx = vx + dt * (vx < 0 and brakeAccel or runAccel)
  else
    local brake = dt * (vx < 0 and brakeAccel or -brakeAccel)
    if math.abs(brake) > math.abs(vx) then
      vx = 0
    else
      vx = vx + brake
    end
  end

  if love.keyboard.isDown("w") and (self:canFly() or self.onGround) then -- jump/fly
    vy = -jumpVelocity
    self.isJumpingOrFlying = true
  end

  self.vx, self.vy = vx, vy
end

function Enemy:playEffects()
  if self.isJumpingOrFlying then
    if self.onGround then
      media.sfx.player_jump:play()
    else
      local lastPuff = Puff:new(self.world,
               self.l,
               self.t + self.h / 2,
               20 * (1 - math.random()),
               50,
               2, 3,self.lightworld)
      Puff:new(self.world,
               self.l + self.w,
               self.t + self.h / 2,
               20 * (1 - math.random()),
               50,
               2, 3,self.lightworld)
      if media.sfx.player_propulsion:countPlayingInstances() == 0 then
        media.sfx.player_propulsion:play()
      end
      
      if not self.lastPuff then self.lastPuff = lastPuff end
    end
  else
    media.sfx.player_propulsion:stop()
  end

  if self.achievedFullHealth then
    media.sfx.player_full_health:play()
  end
end

function Enemy:changeVelocityByBeingOnGround()
  if self.onGround then
    self.vy = math.min(self.vy, 0)
  end
end

function Enemy:checkIfOnGround(ny)
  if ny < 0 then self.onGround = true end
end

function Enemy:moveColliding(dt)
  self.onGround = false
  local world = self.world

  local future_l = self.l + self.vx * dt
  local future_t = self.t + self.vy * dt

  local next_l, next_t, cols, len = world:move(self, future_l, future_t, self.filter)

  for i=1, len do
    local col = cols[i]
    self:changeVelocityByCollisionNormal(col.normal.x, col.normal.y, bounciness)
    self:checkIfOnGround(col.normal.y)
  end

  self.l, self.t = next_l, next_t
end

function Enemy:updateHealth(dt)
  self.achievedFullHealth = false
  if self.isDead then
    self.deadCounter = self.deadCounter + dt
    if self.deadCounter >= deadDuration then
      self.map:reset()
    end
  elseif self.health < 1 then
    self.health = math.min(1, self.health + dt / 6)
    self.achievedFullHealth = self.health == 1
  end
end

function Enemy:update(dt)
  self:updateHealth(dt)
  self:changeVelocityByKeys(dt)
  self:changeVelocityByGravity(dt)
  self:playEffects()

  self:moveColliding(dt)
  self:changeVelocityByBeingOnGround(dt)
  
  self.lightTween:update(dt)
  
  self.isNearTarget         = false
  self.isLoading            = false
  self.laserX, self.laserY  = nil,nil

  self.timeSinceLastTargetAquired = self.timeSinceLastTargetAquired + dt
  
  if self.fireTimer < fireCoolDown then
    self.fireTimer = self.fireTimer + dt
    self.isLoading = true
  elseif self.target then
    local cx,cy = self:getCenter()
    local tx,ty = self.target:getCenter()

    local dx,dy = cx-tx, cy-ty
    local distance2 = dx*dx + dy*dy

    if distance2 <= activeRadius * activeRadius then
      self.isNearTarget = true
      local itemInfo, len = self.world:querySegmentWithCoords(cx,cy,tx,ty)
      -- ignore itemsInfo[1] because that's always self
      local info = itemInfo[2]
      if info then
        self.laserX = info.x1
        self.laserY = info.y1
        if info.item == self.target then
          if self.aimTimer == 0 and self.timeSinceLastTargetAquired >= targetCoolDown then
            media.sfx.guardian_target_acquired:play()
            self.timeSinceLastTargetAquired = 0
          end
          self.aimTimer = self.aimTimer + dt
          if self.aimTimer >= aimDuration then
            self:fire()
          end
        else
          self.aimTimer = 0
        end
      end
    else
      self.aimTimer = 0
    end
  end
  
  if self.lampToggle and self.health == 1 then
    self.lamp.setPosition(self.l+self.w/2, self.t+self.h/2)
    self.lamp.setRange(150)
  else
    self.lamp.setRange(0)
  end
  
  if self.lastPuff and self.light then
    if self.lastPuff.lived >= self.lastPuff.lifeTime/4  then
      self.light.setRange(0)
      self.lastPuff = nil
      return
    end
    
    self.lightTween = tween.new(0.2,self.lightParams,{range=150*(self.lastPuff.lifeTime-self.lastPuff.lived)})
    
    self.light.setPosition(self.l+self.w/2, self.t+self.h)
    --[[self.light.setColor(self.lastPuff:getColor())
    self.light.setRange(150*(self.lastPuff.lifeTime-self.lastPuff.lived))]]
    self.light.setColor(223, 145, 49)
    self.light.setRange(self.lightParams.range)
  end
end

function Enemy:takeHit()
  if self.isDead then return end
  if self.health == 1 then
    for i=1,3 do
      Debris:new(self.world,
                 math.random(self.l, self.l + self.w),
                 self.t + self.h / 2,
                 255,255,255)

    end
  end
  self.health = self.health - 0.7
  if self.health <= 0 then
    self:die()
  end
end

function Enemy:die()
  self.signalDestroy()
  media.music:stop()

  self.isDead = true
  self.health = 0
  for i=1,20 do
    Debris:new(self.world,
               math.random(self.l, self.l + self.w),
               math.random(self.t, self.t + self.h),
               255,0,0)
  end
  local cx,cy = self:getCenter()
  self.w = math.random(8, 10)
  self.h = math.random(8, 10)
  self.l = cx + self.w / 2
  self.t = cy + self.h / 2
  self.vx = math.random(-100, 100)
  self.vy = math.random(-100, 100)
  self.world:remove(self)
  self.world:add(self, self.l, self.t, self.w, self.h)
end

function Enemy:getColor()
  local g = math.floor(255 * self.health)
  local r = 0 - g
  local b = 255
  return r,g,b
end

function Enemy:canFly()
  return self.health == 1
end

function Enemy:draw(drawDebug)
  local r,g,b = self:getColor()
  util.drawFilledRectangle(self.l, self.t, self.w, self.h, r,g,b)

  if drawDebug then
    if self.onGround then
      util.drawFilledRectangle(self.l, self.t + self.h - 4, self.w, 4, 255,255,255)
    end
  end
  
  local cx,cy = self:getCenter()
  love.graphics.setColor(255,0,0)
  local radius = Grenade.radius
  if self.isLoading then
    local percent = self.fireTimer / fireCoolDown
    local alpha = math.floor(255 * percent)
    radius = radius * percent

    love.graphics.setColor(0,100,200,alpha)
    love.graphics.circle('fill', cx, cy, radius)
    love.graphics.setColor(0,100,200)
    love.graphics.circle('line', cx, cy, radius)
  else
    if self.aimTimer > 0 then
      love.graphics.setColor(255,0,0)
    else
      love.graphics.setColor(0,100,200)
    end
    love.graphics.circle('line', cx, cy, radius)
    love.graphics.circle('fill', cx, cy, radius)

    if drawDebug then
      love.graphics.setColor(255,255,255,100)
      love.graphics.circle('line', cx, cy, activeRadius)
    end

    if self.isNearTarget then
      local tx,ty = self.target:getCenter()

      if drawDebug then
        love.graphics.setColor(255,255,255,100)
        love.graphics.line(cx, cy, tx, ty)
      end

      if self.aimTimer > 0 then
        love.graphics.setColor(255,100,100,200)
      else
        love.graphics.setColor(0,100,200,100)
      end
      love.graphics.setLineWidth(2)
      love.graphics.line(cx, cy, self.laserX, self.laserY)
      love.graphics.setLineWidth(1)
    end
  end
  
  if self:canFly() then
    util.drawFilledRectangle(self.l - beltWidth, self.t + self.h/2 , self.w + 2 * beltWidth, beltHeight, 255,255,255)
  end
end

return Enemy