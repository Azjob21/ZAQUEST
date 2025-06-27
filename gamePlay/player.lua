local player = {}
anim8 = require("lib.anim8")
wf = require 'lib/windfield'
world = wf.newWorld(0, 0)
 world:addCollisionClass('Player') 

function player.load(cam)
    player.cam = cam
    player.x = 100
    player.y = 100
    player.height = 64
    player.width = 32
    player.speed = 250
    player.sprite_sheet_idle_states = love.graphics.newImage("assets/player-movement/Sprite-Sheet-idle-states1.png")
    player.sprite_sheet_walk_states = love.graphics.newImage("assets/player-movement/Sprite-Sheet-walk-states1.png")
    player.state = "idle_front"
    player.last_direction = "down"
    player.is_moving = false
    player.prev_state = "idle_front"
    player.life = 50
    player.max_life = 100
    player.spirit = 100
    player.max_spirit = 100
    player.grid_idle = anim8.newGrid(32, 64, player.sprite_sheet_idle_states:getWidth(), player.sprite_sheet_idle_states:getHeight())
    player.grid_walk = anim8.newGrid(32, 64, player.sprite_sheet_walk_states:getWidth(), player.sprite_sheet_walk_states:getHeight())
    
    -- Create a small rectangle collider at player's feet (bottom center)
    local feet_collider_width = 30
    local feet_collider_height = 20
    local feet_x = player.x + player.width / 2
    local feet_y = player.y + player.height -10 -- 5px up from bottom
    
    player.collider = world:newRectangleCollider(
        feet_x, feet_y, 
        feet_collider_width, feet_collider_height
    )
    player.collider:setFixedRotation(true)
    player.collider:setCollisionClass('Player')
    
    -- Store offset between player position and collider position
    player.collider_offset_x = feet_x - player.x
    player.collider_offset_y = feet_y - player.y

    player.animations = {
        idle_front = anim8.newAnimation(player.grid_idle('1-4', 1), 0.15),
        idle_right = anim8.newAnimation(player.grid_idle('1-4', 2), 0.2),
        idle_left = anim8.newAnimation(player.grid_idle('1-4', 3), 0.2),
        idle_back = anim8.newAnimation(player.grid_idle('1-4', 4), 0.15),
        walk_down = anim8.newAnimation(player.grid_walk('1-4', 1), 0.15),
        walk_right = anim8.newAnimation(player.grid_walk('1-4', 2), 0.2),
        walk_left = anim8.newAnimation(player.grid_walk('1-4', 3), 0.2),
        walk_up = anim8.newAnimation(player.grid_walk('1-4', 4), 0.15)
    }
    
    for _, anim in pairs(player.animations) do
        anim:gotoFrame(1)
    end
end

function player.handleMovement(dt)
    player.is_moving = false
    local dx, dy = 0, 0
    local keys_pressed = 0

    -- Track key presses and movement directions
    if love.keyboard.isDown("left") then
        dx = dx - 1
        player.last_direction = "left"
        keys_pressed = keys_pressed + 1
    end
    if love.keyboard.isDown("right") then
        dx = dx + 1
        player.last_direction = "right"
        keys_pressed = keys_pressed + 1
    end
    if love.keyboard.isDown("up") then
        dy = dy - 1
        player.last_direction = "up"
        keys_pressed = keys_pressed + 1
    end
    if love.keyboard.isDown("down") then
        dy = dy + 1
        player.last_direction = "down"
        keys_pressed = keys_pressed + 1
    end

    -- Only consider moving if we have net movement
    if keys_pressed > 0 and (dx ~= 0 or dy ~= 0) then
        player.is_moving = true
        
        -- Normalize diagonal movement
        local length = math.sqrt(dx * dx + dy * dy)
        if length > 0 then
            dx = dx / length
            dy = dy / length

            player.collider:setLinearVelocity(dx * player.speed, dy * player.speed)
        else
            player.collider:setLinearVelocity(0, 0)
        end

        -- Set walking state based on primary direction
        if math.abs(dx) > math.abs(dy) then
            if dx > 0 then
                player.state = "walk_right"
            else
                player.state = "walk_left"
            end
        else
            if dy > 0 then
                player.state = "walk_down"
            else
                player.state = "walk_up"
            end
        end
    else
        player.collider:setLinearVelocity(0, 0)
    end

    -- Sync player position with collider position using the offset
    local colliderX, colliderY = player.collider:getPosition()
    player.x = colliderX - player.collider_offset_x-8
    player.y = colliderY - player.collider_offset_y-10
end

function player.updateState()
    if not player.is_moving then
        local newState
        if player.last_direction == "right" then
            newState = "idle_right"
        elseif player.last_direction == "left" then
            newState = "idle_left"
        elseif player.last_direction == "down" then
            newState = "idle_front"
        elseif player.last_direction == "up" then
            newState = "idle_back"
        else
            newState = "idle_front"
        end

        if player.state ~= newState then
            player.prev_state = player.state
            player.state = newState
            player.animations[newState]:gotoFrame(1)
        end
    end
end

function player.update(dt)
    player.handleMovement(dt)
    player.updateState()
    
    if player.animations[player.state] then
        player.animations[player.state]:update(dt)
    end
end

function player.draw()
    local scale = 1.5
    local offsetX, offsetY = 0, 0

    -- Draw the current animation
    if player.animations[player.state] then
        local sprite_sheet = player.state:match("^walk_") and 
                           player.sprite_sheet_walk_states or 
                           player.sprite_sheet_idle_states
        player.animations[player.state]:draw(
            sprite_sheet, 
            player.x + offsetX, 
            player.y + offsetY, 
            nil, 
            scale
        )
    else
        -- Fallback if animation state is invalid
        player.animations.idle_front:draw(
            player.sprite_sheet_idle_states,
            player.x + offsetX,
            player.y + offsetY,
            nil, 
            scale
        )
    end
    
    -- Debug draw for collider (optional)
    if DEBUG then
        love.graphics.setColor(1, 0, 0, 0.5)
        local cx, cy = player.collider:getPosition()
        local cw, ch = player.collider:getFixtures()[1]:getShape():getDimensions()
        love.graphics.rectangle("fill", cx - cw/2, cy - ch/2, cw, ch)
        love.graphics.setColor(1, 1, 1)
    end
end

return player