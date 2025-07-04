movement = {}

function movement.handleMovement(player, dt)
    -- Don't allow normal movement during attack (unless can_move_while_attacking is true)
    if player.isAttacking and not player.can_move_while_attacking then
        -- Stop movement during attack
        player.collider:setLinearVelocity(0, 0)
        player.velocity_x = 0
        player.velocity_y = 0
        player.is_moving = false
        -- Sync position
        local colliderX, colliderY = player.collider:getPosition()
        player.x = colliderX - player.collider_offset_x - 8
        player.y = colliderY - player.collider_offset_y - 10
        return
    end
    
    -- During dash, don't allow input movement but sync position
    if player.isDashing then
        player.is_moving = false
        -- Update velocity from collider during dash
        player.velocity_x, player.velocity_y = player.collider:getLinearVelocity()
        -- Sync player position with collider during dash
        local colliderX, colliderY = player.collider:getPosition()
        player.x = colliderX - player.collider_offset_x - 8
        player.y = colliderY - player.collider_offset_y - 10
        return
    end
    
    -- DIRECT MOVEMENT INPUT (like player.lua)
    local dirX = 0
    local dirY = 0
    player.is_moving = false

    -- Check movement input (matching player.lua style)
    if love.keyboard.isDown("right") then
        dirX = 1
    end

    if love.keyboard.isDown("left") then
        dirX = -1
    end

    if love.keyboard.isDown("down") then
        dirY = 1
    end

    if love.keyboard.isDown("up") then
        dirY = -1
    end

    -- DIRECT VELOCITY APPLICATION (like player.lua)
    if dirX ~= 0 or dirY ~= 0 then
        player.is_moving = true
        
        -- Create normalized movement vector
        local length = math.sqrt(dirX * dirX + dirY * dirY)
        if length > 0 then
            dirX = dirX / length
            dirY = dirY / length
        end
        
        -- Calculate target speed (considering running state if you want to keep it)
        local target_speed = player.speed
        if player.is_running then
            target_speed = target_speed * player.run_speed_multiplier
        end
        
        -- DIRECT velocity setting (no acceleration/momentum)
        player.velocity_x = dirX * target_speed
        player.velocity_y = dirY * target_speed
        
        -- Apply velocity directly to collider
        player.collider:setLinearVelocity(player.velocity_x, player.velocity_y)
        
        -- Set animation state based on primary direction
        local state_prefix = player.is_running and "run_" or "walk_"
        
        if math.abs(dirX) > math.abs(dirY) then
            if dirX > 0 then
                player.state = state_prefix .. "right"
            else
                player.state = state_prefix .. "left"
            end
        else
            if dirY > 0 then
                player.state = state_prefix .. "down"
            else
                player.state = state_prefix .. "up"
            end
        end
    else
        -- IMMEDIATE STOP (no friction/sliding)
        player.velocity_x = 0
        player.velocity_y = 0
        player.collider:setLinearVelocity(0, 0)
    end

    -- Sync player position with collider position
    local colliderX, colliderY = player.collider:getPosition()
    player.x = colliderX - player.collider_offset_x - 8
    player.y = colliderY - player.collider_offset_y - 10
end


function movement.updateState(player)
    -- Don't change state during attack or dash
    if player.isAttacking or player.isDashing then
        return
    end
    
    -- Only update idle state if not moving
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
            newState = "idle_front" -- default
        end

        if player.state ~= newState then
            player.prev_state = player.state
            player.state = newState
            if player.animations[newState] then
                player.animations[newState]:gotoFrame(1)
            end
        end
    end
end

function movement.startDash(player)
    player.isDashing = true
    player.dash_timer = player.dash_duration
    player.dash_cooldown_timer = player.dash_cooldown
    player.is_running = false -- Stop running when dashing
    
    -- Get current input direction for dash
    local dx, dy = 0, 0
    if love.keyboard.isDown("left") then
        dx = dx - 1
    end
    if love.keyboard.isDown("right") then
        dx = dx + 1
    end
    if love.keyboard.isDown("up") then
        dy = dy - 1
    end
    if love.keyboard.isDown("down") then
        dy = dy + 1
    end
    
    -- If no keys pressed, use last direction
    if dx == 0 and dy == 0 then
        if player.last_direction == "left" then
            dx = -1
        elseif player.last_direction == "right" then
            dx = 1
        elseif player.last_direction == "up" then
            dy = -1
        else -- down
            dy = 1
        end
    end
    
    -- Normalize diagonal movement
    local length = math.sqrt(dx * dx + dy * dy)
    if length > 0 then
        dx = dx / length
        dy = dy / length
    end
    
    -- Set animation state based on primary direction
    if math.abs(dx) > math.abs(dy) then
        if dx > 0 then
            player.state = "dash_right"
        else
            player.state = "dash_left"
        end
    else
        if dy > 0 then
            player.state = "dash_down"
        else
            player.state = "dash_up"
        end
    end
    
    -- Reset dash animation
    if player.animations[player.state] then
        player.animations[player.state]:gotoFrame(1)
    end
    
    -- Apply dash velocity directly (no acceleration)
    player.velocity_x = dx * player.dash_speed
    player.velocity_y = dy * player.dash_speed
    player.collider:setLinearVelocity(player.velocity_x, player.velocity_y)
end

function movement.updateDash(player, dt)
    -- Update dash timer
    if player.isDashing then
        player.dash_timer = player.dash_timer - dt
        
        if player.dash_timer <= 0 then
            player.isDashing = false
            player.dash_timer = 0
            -- IMMEDIATE STOP after dash (no sliding)
            player.velocity_x = 0
            player.velocity_y = 0
            player.collider:setLinearVelocity(0, 0)
        end
    end
    
    -- Update dash cooldown
    if player.dash_cooldown_timer > 0 then
        player.dash_cooldown_timer = player.dash_cooldown_timer - dt
    end
end

return movement