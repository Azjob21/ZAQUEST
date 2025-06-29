anim8 = require "lib.anim8"
wf = require 'lib.windfield'
local sword = {}

function sword.load()
    sword.power = 1000
    sword.sprite_sheet = love.graphics.newImage("assets/weapons/Sprite-Sheet-sword.png")
    sword.sprite_sheet_attack = love.graphics.newImage("assets/weapons/Sprite-Sheet-sword-attack.png")
    sword.grid = anim8.newGrid(32, 64, sword.sprite_sheet:getWidth(), sword.sprite_sheet:getHeight())
    sword.grid_attack = anim8.newGrid(32, 64, sword.sprite_sheet_attack:getWidth(), sword.sprite_sheet_attack:getHeight())
    
    sword.animations = {
        -- Normal walking animations (using regular sprite sheet)
        walk_front = anim8.newAnimation(sword.grid('1-4', 1), 0.15),
        walk_right = anim8.newAnimation(sword.grid('1-4', 2), 0.2),
        walk_left = anim8.newAnimation(sword.grid('1-4', 3), 0.2),
        walk_back = anim8.newAnimation(sword.grid('1-4', 4), 0.15),
        
        -- Attack animations (using attack sprite sheet)
        attack_front = anim8.newAnimation(sword.grid_attack('1-7', 1), 0.04),
        attack_right = anim8.newAnimation(sword.grid_attack('1-7', 2), 0.04),
        attack_left = anim8.newAnimation(sword.grid_attack('1-7', 3), 0.04),
        attack_back = anim8.newAnimation(sword.grid_attack('1-7', 4), 0.04),
    }
    
    -- Make attack animations play once (don't loop)
    sword.animations.attack_front.onLoop = function() end
    sword.animations.attack_right.onLoop = function() end
    sword.animations.attack_left.onLoop = function() end
    sword.animations.attack_back.onLoop = function() end
end

function sword.resetAttackAnimation(direction)
    -- Map player directions to sword attack animations
    local direction_map = {
        down = "attack_front",
        right = "attack_right", 
        left = "attack_left",
        up = "attack_back"
    }
    
    local sword_anim_name = direction_map[direction] or "attack_front"
    local anim = sword.animations[sword_anim_name]
    
    if anim then
        anim:gotoFrame(1)
    end
end

function sword.update(dt) 
    for _, anim in pairs(sword.animations) do
        anim:update(dt)
    end
    
    -- Update sword position based on player position with hand offsets
    if player then
        local hand_offsets, attack_offsets
        
        -- Different offsets for walking vs attacking
        if player.isAttacking then
            -- Attack position offsets (sword extends further)
            attack_offsets = {
                down = {x = 10, y = 50},    -- Front attack - sword swings down
                right = {x = 53, y = 25},   -- Right attack - sword extends right
                left = {x = -8, y = 25},   -- Left attack - sword extends left  
                up = {x = 15, y = 20}       -- Back attack - sword swings up
            }
            hand_offsets = attack_offsets
        else
            -- Normal walking position offsets
            hand_offsets = {
                down = {x = 15, y = 50},    -- Front facing - right hand position
                right = {x = 20, y = 50},   -- Right facing - extended hand
                left = {x = 25, y = 50},    -- Left facing - extended hand  
                up = {x = 19, y = 50}       -- Back facing - right hand position
            }
        end
        
        local offset = hand_offsets[player.last_direction] or hand_offsets.down
        sword.x = player.x + offset.x
        sword.y = player.y + offset.y
    end
end

function sword.draw()
    if player then
        local sword_anim_name, sprite_sheet
        
        -- Choose animation and sprite sheet based on player state
        if player.isAttacking then
            -- Map player directions to sword attack animations
            local attack_direction_map = {
                down = "attack_front",
                right = "attack_right", 
                left = "attack_left",
                up = "attack_back"
            }
            sword_anim_name = attack_direction_map[player.last_direction] or "attack_front"
            sprite_sheet = sword.sprite_sheet_attack
        else
            -- Map player directions to sword walking animations
            local walk_direction_map = {
                down = "walk_front",
                right = "walk_right", 
                left = "walk_left",
                up = "walk_back"
            }
            sword_anim_name = walk_direction_map[player.last_direction] or "walk_front"
            sprite_sheet = sword.sprite_sheet
        end
        
        local anim = sword.animations[sword_anim_name]
        
        if anim then
            -- Draw sword bigger (scale = 2.0) and with proper origin offset
            local scale = 2.0
            anim:draw(sprite_sheet, sword.x, sword.y, 0, scale, scale, 16, 32)
        end
    end   
end       

return sword