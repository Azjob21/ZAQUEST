local player = {}
anim8 = require("lib.anim8")


function player.load(cam)
    player.cam = cam
    player.x = 100
    player.y = 100
    player.speed = 200
    player.sprite_sheet_idle_states = love.graphics.newImage("assets/player-movement/Sprite-Sheet-idle-states.png")
    player.sprite_sheet_walk_states = love.graphics.newImage("assets/player-movement/Sprite-Sheet-walk-states.png")
    player.state = "idle_front"
    player.last_direction = "down"
    player.is_moving = false
    player.prev_state = "idle_front" -- Track previous state
    player.life = 50
    player.max_life = 100
    player.spirit= 100
    player.max_spirit = 100
    player.grid_idle = anim8.newGrid(31, 57, player.sprite_sheet_idle_states:getWidth(), player.sprite_sheet_idle_states:getHeight())
    player.grid_walk = anim8.newGrid(31, 57, player.sprite_sheet_walk_states:getWidth(), player.sprite_sheet_walk_states:getHeight())

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

            player.x = player.x + dx * player.speed * dt
            player.y = player.y + dy * player.speed * dt
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
    end
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
    
    -- Handle health and spirit regeneration here if needed
    -- (player.life and player.spirit are numbers, not objects)
end

function player.draw()
    
    player.drawLifeBar()
    player.drawSpiritBar()

    local scale = 2
    local offsetX, offsetY = 0, 0

    -- Special cases for different animations
    if player.state == "idle_right" or player.state == "walk_right" then
        scale = 1.8
        offsetY = 10
    elseif player.state == "idle_left" or player.state == "walk_left" then
        scale = 1.8
        offsetX, offsetY = 10, 10
    elseif player.state == "idle_back" or player.state == "walk_up" then
        scale = 2.1
    end

    -- Choose the correct sprite sheet
    local sprite_sheet = player.state:match("^walk_") and 
                        player.sprite_sheet_walk_states or 
                        player.sprite_sheet_idle_states

    -- Draw the current animation
    if player.animations[player.state] then
        player.animations[player.state]:draw(sprite_sheet, 
                                           player.x + offsetX, 
                                           player.y + offsetY, 
                                           nil, scale)
    else
        -- Fallback if animation state is invalid
        player.animations.idle_front:draw(player.sprite_sheet_idle_states,
                                        player.x,
                                        player.y,
                                        nil, 2)
    end
end

function player.drawLifeBar()
    -- Draw a simple life bar above the player

    local lifeRatio = math.max(0, math.min(1, player.life / player.max_life))

    -- Draw the life bar fixed at the top left corner, bigger size
    local barWidth = 200
    local barHeight = 20
    local x = 20
    local y = 20
    love.graphics.setColor(1, 0, 0) -- Set color to red
    love.graphics.rectangle("fill", x, y, barWidth * lifeRatio, barHeight)
    love.graphics.setColor(1, 1, 1)
end

function player.drawSpiritBar()
    -- Draw a simple spirit bar at the top left corner, below the life bar
    local barWidth = 200
    local barHeight = 14
    local x = 20
    local y = 44
    local spiritRatio = math.max(0, math.min(1, player.spirit / player.max_spirit))
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle("fill", x, y, barWidth, barHeight)
    love.graphics.setColor(0, 0.5, 1)
    love.graphics.rectangle("fill", x, y, barWidth * spiritRatio, barHeight)
    love.graphics.setColor(1, 1, 1)
end

return player