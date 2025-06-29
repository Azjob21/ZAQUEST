input = {}
function input.handleInput(player,dt)
    -- Toggle weapon visibility when "w" is pressed
    if love.keyboard.isDown("w") and not player._weapon_toggle_pressed then
        player.weapon_visible = not player.weapon_visible
        player._weapon_toggle_pressed = true
    elseif not love.keyboard.isDown("w") then
        player._weapon_toggle_pressed = false
    end
    
    -- Handle attack input
    if love.keyboard.isDown("x") and not player.isAttacking and not player.isDashing then
        player.startAttack()
    end
    
    -- RUNNING SYSTEM - Handle space key for running/dashing
    local space_pressed = love.keyboard.isDown("space")
    
    -- Check if space was just pressed (for dash detection)
    local space_just_pressed = space_pressed and not player.space_pressed_last_frame
    
    if space_pressed then
        player.space_hold_timer = player.space_hold_timer + dt
        
        -- Check if we should start running (space held + moving + not dashing/attacking)
        if player.space_hold_timer >= player.run_threshold_time and 
           player.is_moving and not player.isDashing and not player.isAttacking then
            player.is_running = true
        end
    else
        player.space_hold_timer = 0
        player.is_running = false
    end
    
    -- Handle dash input (space just pressed, not held)
    if space_just_pressed and not player.isDashing and not player.isAttacking and 
       player.dash_cooldown_timer <= 0 and player.space_hold_timer < 0.1 then
        player.startDash()
    end
    
    player.space_pressed_last_frame = space_pressed
end
return input