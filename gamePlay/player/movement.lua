movement = {}
function movement.handleMovement(player,dt)
    -- Don't allow normal movement during attack
    if player.isAttacking and not player.can_move_while_attacking then
        -- Apply friction even during attack
        player.velocity_x = player.velocity_x * player.friction
        player.velocity_y = player.velocity_y * player.friction
        player.collider:setLinearVelocity(player.velocity_x, player.velocity_y)
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
        -- Sync player position with collider during dash for smooth camera follow
        local colliderX, colliderY = player.collider:getPosition()
        player.x = colliderX - player.collider_offset_x - 8
        player.y = colliderY - player.collider_offset_y - 10
        return
    end
    
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

    -- PHYSICS-BASED MOVEMENT
    if keys_pressed > 0 and (dx ~= 0 or dy ~= 0) then
        player.is_moving = true
        
        -- Normalize diagonal movement
        local length = math.sqrt(dx * dx + dy * dy)
        if length > 0 then
            dx = dx / length
            dy = dy / length
        end
        
        -- Calculate target speed based on running state
        local target_speed = player.speed
        if player.is_running then
            target_speed = target_speed * player.run_speed_multiplier
        end
        
        -- Apply acceleration towards target velocity
        player.velocity_x = player.velocity_x + (dx * player.acceleration * dt)
        player.velocity_y = player.velocity_y + (dy * player.acceleration * dt)
        
        -- Cap velocity to target speed
        local current_speed = math.sqrt(player.velocity_x^2 + player.velocity_y^2)
        if current_speed > target_speed then
            local scale = target_speed / current_speed
            player.velocity_x = player.velocity_x * scale
            player.velocity_y = player.velocity_y * scale
        end
        
        -- Set state based on running and direction
        local state_prefix = player.is_running and "run_" or "walk_"
        
        if math.abs(dx) > math.abs(dy) then
            if dx > 0 then
                player.state = state_prefix .. "right"
            else
                player.state = state_prefix .. "left"
            end
        else
            if dy > 0 then
                player.state = state_prefix .. "down"
            else
                player.state = state_prefix .. "up"
            end
        end
    else
        -- Apply friction when not moving (creates sliding effect)
        local friction_to_use = player.friction
        
        -- Use different friction if we just finished dashing
        if player.dash_end_timer > 0 then
            friction_to_use = player.dash_friction
        end
        
        player.velocity_x = player.velocity_x * friction_to_use
        player.velocity_y = player.velocity_y * friction_to_use
        
        -- Stop very small movements to prevent jitter
        if math.abs(player.velocity_x) < 5 then player.velocity_x = 0 end
        if math.abs(player.velocity_y) < 5 then player.velocity_y = 0 end
    end
    
    -- Apply velocity to collider
    player.collider:setLinearVelocity(player.velocity_x, player.velocity_y)

    -- Sync player position with collider position using the offset
    local colliderX, colliderY = player.collider:getPosition()
    player.x = colliderX - player.collider_offset_x - 8
    player.y = colliderY - player.collider_offset_y - 10
end
function movement.updateState(player)
   -- Don't change state during attack or dash
    if player.isAttacking or player.isDashing then
        return
    end
    
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
function movement.startDash(player)
    player.isDashing = true
    player.dash_timer = player.dash_duration
    player.dash_cooldown_timer = player.dash_cooldown
    player.is_running = false -- Stop running when dashing
    
    -- Get current input direction for orthogonal dashing
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
    
    -- Normalize diagonal movement for consistent dash distance
    local length = math.sqrt(dx * dx + dy * dy)
    if length > 0 then
        dx = dx / length
        dy = dy / length
    end
    
    -- Set animation state based on primary direction (for visual clarity)
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
    
    -- Apply normalized dash velocity (using physics system)
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
            -- Start post-dash sliding effect
            player.dash_end_timer = 0.4 -- Duration of sliding after dash
        end
    end
    
    -- Update dash cooldown
    if player.dash_cooldown_timer > 0 then
        player.dash_cooldown_timer = player.dash_cooldown_timer - dt
    end
    
    -- Update dash end timer (for post-dash sliding)
    if player.dash_end_timer > 0 then
        player.dash_end_timer = player.dash_end_timer - dt
    end
end    
return movement