--This file is part of PixelizerBox--
--[[
  * Copyright 2015 RamiLego4Game
  * 
  * Licensed under the Apache License, Version 2.0 (the "License");
  * you may not use this file except in compliance with the License.
  * You may obtain a copy of the License at
  * 
  *     http://www.apache.org/licenses/LICENSE-2.0
  * 
  * Unless required by applicable law or agreed to in writing, software
  * distributed under the License is distributed on an "AS IS" BASIS,
  * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  * See the License for the specific language governing permissions and
  * limitations under the License.
--]]

io.stdout:setvbuf("no")
print("Game Started") --DEBUG

--Requirements--
local GameSetup = require("Engine.SetupGame")
local Gamestate = require("Helpers.hump.gamestate")
local Signal = require("Helpers.hump.signal")
--local Splash = require("States.Splash")
local Play = require("States.play")

function love.load(args)
  GameSetup:init()
  
  Gamestate.registerEvents()
  Gamestate.switch(Play)
end

function love.update(dt)
  love.window.setTitle("BombWar MiniGame V".._Version.." [".._State.."] FPS:"..love.timer.getFPS())
  
  Signal.emit("love_update",dt)
end

function love.draw()
  Signal.emit("love_draw")
end

function love.textinput(text)
  Signal.emit("love_textinput",text)
end

function love.keypressed(key, isrepeat)
  if key == "f3" then _DebugKey = not _DebugKey end
  Signal.emit("love_keypressed",key,isrepeat)
  if key == "escape" then love.event.quit() end
end

function love.keyreleased(key)
  Signal.emit("love_keyreleased",key)
end

function love.mousepressed(x, y, button)
  Signal.emit("love_mousepressed",x,y,button)
end

function love.mousereleased(x, y, button)
  Signal.emit("love_mousereleased",x,y,button)
end

function love.focus(f)
  Signal.emit("love_focus",f)
end

function love.visible(v)
  Signal.emit("love_visible",v)
end

function love.mousefocus(f)
  Signal.emit("love_mousefocus",f)
end

function love.quit()
  print("Game Quit") --DEBUG
  Signal.emit("love_quit")
end