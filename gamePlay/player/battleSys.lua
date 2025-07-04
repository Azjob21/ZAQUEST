battleSys = {}
function battleSys.takeDamage(player, damage)
    if player.invulnerable or player.destroyed then
        return false
    end
    
    player.life = player.life - damage
    player.invulnerable = true
    player.invulnerability_timer = player.invulnerability_duration
    player.flash_timer = 0.1  -- Flash for visual feedback
    
    print("Player took", damage, "damage! Life:", player.life)
    
    if player.life <= 0 then
        player.life = 0
        player.destroyed = true
        print("Player defeated!")
        -- You could add game over logic here
    end
    
    -- Update collider user data
    local userData = player.collider:getUserData()
    if userData then
        userData.life = player.life
        userData.destroyed = player.destroyed
    end
    
    return true
end

function battleSys.onAttackHit(player, enemy)
      if enemy == player then return end
    if enemy and not enemy.destroyed then
        print("Player's attack hit an enemy!")
        
        if enemy.takeDamage then
            enemy.takeDamage(player.attack_damage)
        elseif enemy.life then
            enemy.life = enemy.life - player.attack_damage
            print("Enemy took", player.attack_damage, "damage! Life:", enemy.life)
            
            if enemy.life <= 0 then
                enemy.destroyed = true
                print("Enemy destroyed by player!")
            end
        end
    end
end

function battleSys.createAttackCollider(player)
    -- Remove any existing attack colliders
    player.clearAttackColliders()
    
    -- Calculate attack position based on player direction
    local attack_x = player.x + player.width / 2 
    local attack_y = player.y + player.height / 2 
    local attack_width = 60  -- Increased for combined sprite
    local attack_height = 35-- Increased for combined sprite
    
    -- Adjust position based on direction
    if player.last_direction == "right" then
        attack_x = attack_x + player.attack_range 
    elseif player.last_direction == "left" then
        attack_x = attack_x - player.attack_range 
    elseif player.last_direction == "up" then
        attack_y = attack_y - player.attack_range
    else -- down
        attack_y = attack_y + player.attack_range +50
    end
    
    -- Create attack collider
    local attack_collider = world:newRectangleCollider(
        attack_x - attack_width/2, 
        attack_y - attack_height/2, 
        attack_width, 
        attack_height
    )
    attack_collider:setType("static")  -- Attack colliders don't move
    attack_collider:setCollisionClass('PlayerAttack')
    -- This is crucial for the self-damage prevention logic in main.lua
    
    -- Set user data for the attack collider with timer
    attack_collider:setUserData({
        type = "player_attack",
        damage = player.attack_damage,
        player = player,  -- Reference back to player for callback
        created_time = love.timer.getTime(),
        lifetime = 0.2  -- How long the collider should exist
    })
    
    table.insert(player.attack_colliders, attack_collider)
end

function battleSys.updateAttackColliders(player,dt)
    local current_time = love.timer.getTime()
    
    -- Check each attack collider for expiration
    for i = #player.attack_colliders, 1, -1 do
        local collider = player.attack_colliders[i]
        local userData = collider:getUserData()
        
        if userData and userData.created_time and userData.lifetime then
            if current_time - userData.created_time >= userData.lifetime then
                -- Remove expired collider
                collider:destroy()
                table.remove(player.attack_colliders, i)
            end
        end
    end
end

function battleSys.removeAttackCollider(player,collider)
    for i, attack_collider in ipairs(player.attack_colliders) do
        if attack_collider == collider then
            attack_collider:destroy()
            table.remove(player.attack_colliders, i)
            break
        end
    end
end

function battleSys.clearAttackColliders(player)
    for _, collider in ipairs(player.attack_colliders) do
        if collider and not collider:isDestroyed() then
            collider:destroy()
        end
    end
    player.attack_colliders = {}
end

function battleSys.startAttack(player)
    player.isAttacking = true
    player.attack_timer = player.attack_duration
    player.is_running = false -- Stop running when attacking
    
    -- Set the appropriate attack animation based on direction
    local attack_state = "attack_" .. player.last_direction
    player.state = attack_state
    
    -- Reset the attack animation to start from the beginning
    if player.animations[attack_state] then
        player.animations[attack_state]:gotoFrame(1)
    end
    
    -- Create attack collider for battle system
    player.createAttackCollider()
end

function battleSys.updateAttack(player,dt)
    if player.isAttacking then
        player.attack_timer = player.attack_timer - dt
        if player.attack_timer <= 0 then
            player.isAttacking = false
            player.attack_timer = 0
            -- Clear any remaining attack colliders
            player.clearAttackColliders()
        end
    end
end

function battleSys.updateBattleSystem(player,dt)
    -- Update invulnerability
    if player.invulnerable then
        player.invulnerability_timer = player.invulnerability_timer - dt
        if player.invulnerability_timer <= 0 then
            player.invulnerable = false
            player.invulnerability_timer = 0
        end
    end
    
    -- Update flash timer for visual feedback
    if player.flash_timer > 0 then
        player.flash_timer = player.flash_timer - dt
    end
end

return battleSys