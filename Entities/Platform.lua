local class  = require 'Helpers.middleclass'
local util   = require 'Engine.util'

local Entity = require 'Entities.Entity'

local Platform = class('Platform', Entity)
Platform.static.updateOrder = 0

function Platform:initialize(world, x, y, width, height,direction)
  self.w, self.h, self.d = width, height, direction

  Entity.initialize(self, world, x,y, width, height)
  
  self.world:update(self, self.l, self.t)
end

function Platform:canPass(l,t,w,h)
  if self.d == "up" and self.t >= t + h then
    return true
  elseif self.d == "down" and self.t-self.h >= t then
    return true
  elseif self.d == "left" and self.l <= l + w then
    return true
  elseif self.d == "right" and self.l+self.w >= l then
    return true
  end
end

function Platform:filter(other)
  if other.class.name == 'Player' and self:canPass(other.l, other.t, other.w, other.h) then
    return 'cross'
  end
end

function Platform:update(dt)

  local _,_, cols, len = self.world:move(self, self.l, self.t, self.filter)

  self.vx, self.vy = self.l/dt, self.t/dt

  for i=1,len do
    local col = cols[i]
    if col.normal.t and col.normal.t > 0 then
      col.other:setGround(self)
    end
  end
end

function Platform:draw(drawDebug)
  if not drawDebug then return end

  util.drawFilledRectangle(self.l, self.t, self.w, self.h, 0, 200, 0)
  
  love.graphics.setColor(200,0,0)
  
  love.graphics.setLineWidth(1)
  if self.d == "up" then
    love.graphics.line(self.l,self.t,self.l+self.w,self.t)
  elseif self.d == "down" then
    love.graphics.line(self.l,self.t+self.h,self.l+self.w,self.t+self.h)
  elseif self.d == "left" then
    love.graphics.line(self.l,self.t,self.l,self.t+self.h)
  elseif self.d == "right" then
    love.graphics.line(self.l+self.w,self.t,self.l+self.w,self.t+self.h)
  end
end

return Platform
