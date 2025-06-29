local darkBall = {}
local anim8 = require("lib.anim8")
local wf = require 'lib.windfield'

-- Note: We'll use the world from main.lua instead of creating a new one
local world

-- Shared resources
local sprite_sheet_jump, sprite_sheet_wink, sprite_sheet_death
local grid1, grid2, grid3
local animations = {}

-- Battle system constants
local BATTLE_CONFIG = {
    MAX_HEALTH = 100,
    ATTACK_DAMAGE = 25,
    ATTACK_COOLDOWN = 1.5,
    DEATH_ANIMATION_TIME = 1.0,
    KNOCKBACK_FORCE = 300,
    INVINCIBILITY_TIME = 0.5,
    FLASH_DURATION = 0.1,
    AGGRO_RANGE = 250,
    ATTACK_RANGE = 60,
    CHASE_SPEED = 120,
    IDLE_SPEED = 30,
    ATTACK_SPEED = 80
}

local function loadSharedResources()
    local success, err = pcall(function()
        sprite_sheet_jump = love.graphics.newImage("assets/enemies/Sprite-Sheet-dark-ball.png")
        sprite_sheet_wink = love.graphics.newImage("assets/enemies/Sprite-Sheet-dark-ball-wink.png")
        -- If you have a death animation sprite, uncomment this:
        -- sprite_sheet_death = love.graphics.newImage("assets/enemies/Sprite-Sheet-dark-ball-death.png")
    end)
    
    if not success then
        print("Failed to load sprite sheets:", err)
        return false
    end
    
    local frame_width, frame_height = 64, 64
    grid1 = anim8.newGrid(frame_width, frame_height, sprite_sheet_jump:getWidth(), sprite_sheet_jump:getHeight())
    grid2 = anim8.newGrid(frame_width, frame_height, sprite_sheet_wink:getWidth(), sprite_sheet_wink:getHeight())
    
    -- If death sprite exists
    if sprite_sheet_death then
        grid3 = anim8.newGrid(frame_width, frame_height, sprite_sheet_death:getWidth(), sprite_sheet_death:getHeight())
    end
    
    success, err = pcall(function()
        animations.jump = anim8.newAnimation(grid1('1-30', 1), 0.08) -- Faster for combat
        animations.wink = anim8.newAnimation(grid2('1-9', 1), 0.15)
        animations.idle = anim8.newAnimation(grid2('1-3', 1), 0.5) -- Slower idle
        animations.attack = anim8.newAnimation(grid1('15-25', 1), 0.06) -- Attack frames
        animations.hurt = anim8.newAnimation(grid2('7-9', 1), 0.1) -- Hurt frames
        
        -- Death animation (if sprite exists, otherwise use hurt frames)
        if sprite_sheet_death and grid3 then
            animations.death = anim8.newAnimation(grid3('1-10', 1), 0.1)
        else
            animations.death = anim8.newAnimation(grid2('8-9', 1), 0.2)
        end
    end)
    
    if not success then
        print("Failed to create animations:", err)
        return false
    end
    
    return true
end

-- Set the world reference (call this from main.lua)
function darkBall.setWorld(world_ref)
    world = world_ref
end

-- Constructor
function darkBall.new(x, y, collider_type, player_ref)
    local self = {
        x = x or 150,
        y = y or 150,
        
        -- Combat stats
        health = BATTLE_CONFIG.MAX_HEALTH,
        maxHealth = BATTLE_CONFIG.MAX_HEALTH,
        attackDamage = BATTLE_CONFIG.ATTACK_DAMAGE,
        
        -- Battle state
        state = "idle", -- idle, chasing, attacking, hurt, dying, dead
        attackCooldown = 0,
        invincibilityTimer = 0,
        deathTimer = 0,
        flashTimer = 0,
        isFlashing = false,
        
        -- Animation system
        currentAnimation = "idle",
        anim_timer = 0,
        
        -- Physics
        collider = nil,
        collider_type = collider_type or "circle",
        radius = 28,
        width = 56,
        height = 56,
        destroyed = false,
        
        -- AI behavior
        player = player_ref,
        detectionRange = BATTLE_CONFIG.AGGRO_RANGE,
        attackRange = BATTLE_CONFIG.ATTACK_RANGE,
        lastPlayerPosition = {x = 0, y = 0},
        
        -- Movement
        currentSpeed = BATTLE_CONFIG.IDLE_SPEED,
        targetVelocity = {x = 0, y = 0}
    }
    
    if not sprite_sheet_jump and not loadSharedResources() then
        return nil
    end
    
    -- Make sure we have a world reference
    if not world then
        print("ERROR: World not set. Call darkBall.setWorld(world) first")
        return nil
    end
    
    -- Create collider based on type
    if self.collider_type == "circle" then
        self.collider = world:newCircleCollider(self.x, self.y, self.radius)
    else
        self.collider = world:newRectangleCollider(self.x - self.width/2, self.y - self.height/2, self.width, self.height)
    end
    
    -- Set collider properties
    self.collider:setType('dynamic')
    self.collider:setUserData(self)
    
    -- Set collision class
    local success, err = pcall(function()
        self.collider:setCollisionClass('darkBall')
    end)
    if not success then
        print("Warning: Collision class not set:", err)
    end
    
    -- Initialize animation
    self.current_anim = animations[self.currentAnimation]
    self.sprite_sheet = sprite_sheet_wink -- Start with idle sprite
    
    -- Battle system methods
    function self.takeDamage(damage, knockback_direction)
        if self.state == "dead" or self.state == "dying" then
            return false
        end
        
        if self.invincibilityTimer > 0 then
            return false -- Still invincible
        end
        
        -- Apply damage
        self.health = math.max(0, self.health - damage-20)
        print("Dark ball took", damage, "damage! Health:", self.health)
        
        -- Start invincibility
        self.invincibilityTimer = BATTLE_CONFIG.INVINCIBILITY_TIME
        self.isFlashing = true
        self.flashTimer = 0
        
        -- Apply knockback if direction provided
        if knockback_direction and self.collider then
            local knockback_force = BATTLE_CONFIG.KNOCKBACK_FORCE
            local dx = knockback_direction.x * knockback_force
            local dy = knockback_direction.y * knockback_force
            self.collider:applyLinearImpulse(dx, dy)
        end
        
        -- Check if dead
        if self.health <= 0 then
            self.state = "dying"
            self.deathTimer = BATTLE_CONFIG.DEATH_ANIMATION_TIME
            self.currentAnimation = "death"
            print("Dark ball is dying!")
        else
            -- Enter hurt state
            self.state = "hurt"
            self.currentAnimation = "hurt"
            self.anim_timer = 0
        end
        
        return true
    end
    
    function self.heal(amount)
        if self.state == "dead" or self.state == "dying" then
            return
        end
        
        self.health = math.min(self.maxHealth, self.health + amount)
    end
    
    function self.canAttack()
        return self.attackCooldown <= 0 and self.state ~= "dead" and self.state ~= "dying"
    end
    
    function self.attack(target)
        if not self.canAttack() or not target then
            return false
        end
        
        -- Calculate distance to target
        local dx = target.x - self.x
        local dy = target.y - self.y
        local distance = math.sqrt(dx * dx + dy * dy)
        
        if distance <= self.attackRange then
            self.state = "attacking"
            self.currentAnimation = "attack"
            self.attackCooldown = BATTLE_CONFIG.ATTACK_COOLDOWN
            self.anim_timer = 0
            
            -- Apply damage to target
            if target.takeDamage then
                local knockback_dir = {
                    x = dx / distance,
                    y = dy / distance
                }
                target.takeDamage(self.attackDamage, knockback_dir)
                print("Dark ball attacked target for", self.attackDamage, "damage!")
            end
            
            return true
        end
        
        return false
    end
    
    function self.getDistanceToPlayer()
        if not self.player then return math.huge end
        
        local player_x, player_y = self.getPlayerPosition()
        local dx = player_x - self.x
        local dy = player_y - self.y
        return math.sqrt(dx * dx + dy * dy), dx, dy
    end
    
    function self.getPlayerPosition()
        if not self.player then return 0, 0 end
        
        if self.player.collider then
            return self.player.collider:getPosition()
        else
            return self.player.x + (self.player.width or 32) / 2,
                   self.player.y + (self.player.height or 64) / 2
        end
    end
    
    function self.updateAI(dt)
        if self.state == "dead" or self.state == "dying" then
            return
        end
        
        local distance, dx, dy = self.getDistanceToPlayer()
        
        -- Update target velocity based on state and player position
        if distance <= self.detectionRange and self.player then
            if distance <= self.attackRange then
                -- Close enough to attack
                if self.canAttack() then
                    local player_x, player_y = self.getPlayerPosition()
                    self.attack({x = player_x, y = player_y, takeDamage = self.player.takeDamage})
                end
                
                -- Stop moving when attacking
                self.targetVelocity.x = 0
                self.targetVelocity.y = 0
                self.currentSpeed = 0
            else
                -- Chase the player
                if self.state ~= "attacking" and self.state ~= "hurt" then
                    self.state = "chasing"
                    self.currentAnimation = "jump"
                end
                
                -- Move toward player
                local dir_x = dx / distance
                local dir_y = dy / distance
                self.currentSpeed = BATTLE_CONFIG.CHASE_SPEED
                self.targetVelocity.x = dir_x * self.currentSpeed
                self.targetVelocity.y = dir_y * self.currentSpeed
            end
        else
            -- Player too far or no player - idle behavior
            if self.state ~= "hurt" and self.state ~= "attacking" then
                self.state = "idle"
                self.currentAnimation = "idle"
            end
            
            -- Gradually slow down
            self.targetVelocity.x = self.targetVelocity.x * 0.95
            self.targetVelocity.y = self.targetVelocity.y * 0.95
            self.currentSpeed = self.currentSpeed * 0.98
        end
    end
    
    function self.updateMovement(dt)
        if not self.collider or self.state == "dead" then
            return
        end
        
        -- Apply movement with smoothing
        if self.state ~= "attacking" then
            local smoothing = 8 * dt
            local current_vx, current_vy = self.collider:getLinearVelocity()
            
            local new_vx = current_vx + (self.targetVelocity.x - current_vx) * smoothing
            local new_vy = current_vy + (self.targetVelocity.y - current_vy) * smoothing
            
            self.collider:setLinearVelocity(new_vx, new_vy)
        end
    end
    
    function self.updateTimers(dt)
        -- Update attack cooldown
        if self.attackCooldown > 0 then
            self.attackCooldown = self.attackCooldown - dt
        end
        
        -- Update invincibility
        if self.invincibilityTimer > 0 then
            self.invincibilityTimer = self.invincibilityTimer - dt
            
            -- Handle flashing effect
            if self.isFlashing then
                self.flashTimer = self.flashTimer + dt
                if self.flashTimer >= BATTLE_CONFIG.FLASH_DURATION then
                    self.flashTimer = 0
                end
            end
            
            if self.invincibilityTimer <= 0 then
                self.isFlashing = false
            end
        end
        
        -- Update death timer
        if self.state == "dying" then
            self.deathTimer = self.deathTimer - dt
            if self.deathTimer <= 0 then
                self.state = "dead"
                self.destroyed = true
            end
        end
    end
    
    function self.updateAnimations(dt)
        if not self.current_anim then return end
        
        -- Update current animation
        self.current_anim:update(dt)
        self.anim_timer = self.anim_timer + dt
        
        -- Handle animation transitions
        if self.currentAnimation ~= self.getCurrentAnimationName() then
            self.setAnimation(self.currentAnimation)
        end
        
        -- Check for animation completion
        if self.anim_timer >= self.current_anim.totalDuration then
            self.onAnimationComplete()
        end
    end
    
    function self.setAnimation(anim_name)
        if animations[anim_name] and self.currentAnimation ~= anim_name then
            self.currentAnimation = anim_name
            self.current_anim = animations[anim_name]
            self.current_anim:gotoFrame(1)
            self.anim_timer = 0
            
            -- Set appropriate sprite sheet
            if anim_name == "jump" or anim_name == "attack" then
                self.sprite_sheet = sprite_sheet_jump
            elseif anim_name == "death" and sprite_sheet_death then
                self.sprite_sheet = sprite_sheet_death
            else
                self.sprite_sheet = sprite_sheet_wink
            end
        end
    end
    
    function self.getCurrentAnimationName()
        return self.currentAnimation
    end
    
    function self.onAnimationComplete()
        self.anim_timer = 0
        
        -- Handle state transitions after animation completion
        if self.state == "hurt" then
            self.state = "idle"
            self.currentAnimation = "idle"
        elseif self.state == "attacking" then
            self.state = "idle"
            self.currentAnimation = "idle"
        end
        
        -- Loop certain animations
        if self.currentAnimation == "idle" or self.currentAnimation == "jump" then
            self.current_anim:gotoFrame(1)
        end
    end
    
    function self.update(dt)
        if self.destroyed then return end
        
        -- Update physics position
        if self.collider then
            self.x, self.y = self.collider:getPosition()
        end
        
        -- Update all systems
        self.updateTimers(dt)
        self.updateAI(dt)
        self.updateMovement(dt)
        self.updateAnimations(dt)
        
        -- Debug controls (remove in production)
        if love.keyboard.isDown('f') then
            self.takeDamage(10) -- Test damage
        end
        if love.keyboard.isDown('h') then
            self.heal(5) -- Test healing
        end
    end
    
    function self.draw()
        if self.destroyed or self.state == "dead" then return end
        
        local scale = 2
        
        -- Handle flashing effect
        local should_draw = true
        if self.isFlashing then
            should_draw = (self.flashTimer < BATTLE_CONFIG.FLASH_DURATION * 0.5)
        end
        
        if should_draw and self.current_anim and self.sprite_sheet then
            -- Draw sprite centered on collider position
            local offset_x = self.width * scale / 2
            local offset_y = self.height * scale / 2
            
            -- Tint based on state
            if self.state == "hurt" then
                love.graphics.setColor(1, 0.5, 0.5) -- Red tint for hurt
            elseif self.state == "dying" then
                love.graphics.setColor(0.7, 0.7, 0.7) -- Gray tint for dying
            else
                love.graphics.setColor(1, 1, 1) -- Normal color
            end
            
            self.current_anim:draw(self.sprite_sheet, self.x - offset_x, self.y - offset_y, 0, scale, scale)
            love.graphics.setColor(1, 1, 1) -- Reset color
        end
        
        -- Draw health bar
        if self.health < self.maxHealth and self.state ~= "dying" then
            local bar_width = 40
            local bar_height = 4
            local bar_x = self.x - bar_width / 2
            local bar_y = self.y - self.height - 10
            
            -- Background
            love.graphics.setColor(0.3, 0.3, 0.3)
            love.graphics.rectangle("fill", bar_x, bar_y, bar_width, bar_height)
            
            -- Health bar
            local health_ratio = self.health / self.maxHealth
            local health_color = {
                1 - health_ratio, -- Red increases as health decreases
                health_ratio,     -- Green decreases as health decreases
                0
            }
            love.graphics.setColor(health_color)
            love.graphics.rectangle("fill", bar_x, bar_y, bar_width * health_ratio, bar_height)
            
            love.graphics.setColor(1, 1, 1) -- Reset color
        end
        
        -- Debug visualization
        if love.keyboard.isDown('f1') then
            -- Draw collider
            love.graphics.setColor(0, 1, 0, 0.3)
            if self.collider_type == "circle" then
                love.graphics.circle("fill", self.x, self.y, self.radius)
            else
                love.graphics.rectangle("fill", self.x - self.width/2, self.y - self.height/2, self.width, self.height)
            end
            
            -- Draw detection range
            love.graphics.setColor(1, 1, 0, 0.1)
            love.graphics.circle("fill", self.x, self.y, self.detectionRange)
            
            -- Draw attack range
            love.graphics.setColor(1, 0, 0, 0.2)
            love.graphics.circle("fill", self.x, self.y, self.attackRange)
            
            love.graphics.setColor(1, 1, 1)
            
            -- Draw state text
            love.graphics.print("State: " .. self.state, self.x - 30, self.y - 60)
            love.graphics.print("HP: " .. self.health .. "/" .. self.maxHealth, self.x - 30, self.y - 45)
        end
    end
    
    -- Utility functions
    function self.moveBy(dx, dy)
        if self.collider and not self.destroyed then
            local x, y = self.collider:getPosition()
            self.collider:setPosition(x + dx, y + dy)
        end
    end
    
    function self.setPosition(new_x, new_y)
        if self.collider and not self.destroyed then
            self.collider:setPosition(new_x, new_y)
            self.x, self.y = new_x, new_y
        end
    end
    
    function self.setVelocity(vx, vy)
        if self.collider and not self.destroyed then
            self.collider:setLinearVelocity(vx, vy)
        end
    end
    
    function self.getVelocity()
        if self.collider and not self.destroyed then
            return self.collider:getLinearVelocity()
        end
        return 0, 0
    end
    
    function self.onCollision(other_collider, contact)
        local other = other_collider:getUserData()
        if other and other.type == "player_attack" then
            -- This is handled by the main collision system
            return
        end
    end
    
    function self.setPlayer(player_ref)
        self.player = player_ref
    end
    
    function self.isDead()
        return self.state == "dead" or self.destroyed
    end
    
    function self.isAlive()
        return not self.isDead()
    end
    
    function self.getHealthRatio()
        return self.health / self.maxHealth
    end
    
    function self.destroy()
        if self.collider then
            self.collider:destroy()
            self.collider = nil
        end
        self.destroyed = true
        self.state = "dead"
    end
    
    return self
end

-- Initialize collision classes (call this once before creating any dark balls)
function darkBall.initializeCollisionClasses(world_ref)
    if world_ref then
        world = world_ref
    end
    if not world then
        print("ERROR: No world reference for collision classes")
        return
    end
    
    -- Register collision classes
    world:addCollisionClass('darkBall')
    world:addCollisionClass('wall')
    world:addCollisionClass('enemy')
end

-- Set up collision callbacks (call this once in your main game)
function darkBall.setupCollisionCallbacks(world_ref)
    if world_ref then
        world = world_ref
    end
    if not world then
        print("ERROR: No world reference for collision callbacks")
        return
    end
    
    -- Note: The main collision system is handled in main.lua
    -- This is just for any additional dark ball specific collisions
end

return darkBall