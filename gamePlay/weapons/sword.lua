anim8 = require "lib.anim8"
wf = require 'lib.windfield'
local sword = {}
function sword.load()
    sword.power =10
    sword.sprite_sheet = love.graphics.newImage("assets/weapons/Sprite-Sheet-sword.png")
    sword.grid = anim8.newGrid(32, 64, sword.sprite_sheet:getWidth(), sword.sprite_sheet:getHeight())
    sword.animations ={
        walk_front= anim8.newAnimation(sword.grid('1-4', 1), 0.15),
        walk_right= anim8.newAnimation(sword.grid('1-4', 2), 0.2),
        walk_left= anim8.newAnimation(sword.grid('1-4', 3), 0.2),
        walk_back= anim8.newAnimation(sword.grid('1-4', 4), 0.15),
    }
end
function sword.update(dt) 
    for _, anim in pairs(sword.animations) do
        anim:update(dt)
    end
    -- Update sword position based on player position with hand offsets
    if player then
        -- Hand position offsets for each direction (adjust these values to match your sprites)
        local hand_offsets = {
            down = {x = 15, y = 50},    -- Front facing - right hand position
            right = {x = 20, y = 50},  -- Right facing - extended hand
            left = {x = 25, y = 50},   -- Left facing - extended hand  
            up = {x = 19, y =50}       -- Back facing - right hand position
        }
        
        local offset = hand_offsets[player.last_direction] or hand_offsets.down
        sword.x = player.x + offset.x
        sword.y = player.y + offset.y
    end
end
function sword.draw()
    if player then
        -- Map player directions to sword animations
        local direction_map = {
            down = "walk_front",
            right = "walk_right", 
            left = "walk_left",
            up = "walk_back"
        }
        
        local sword_anim_name = direction_map[player.last_direction] or "walk_front"
        local anim = sword.animations[sword_anim_name]
        
        if anim then
            -- Draw sword bigger (scale = 2.0) and with proper origin offset
            local scale = 2.0
            anim:draw(sword.sprite_sheet, sword.x, sword.y, 0, scale, scale, 16, 32)
        end
    end   
end       

return sword