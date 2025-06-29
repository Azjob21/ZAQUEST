local player = {}
sword = require("gamePlay.weapons.sword")
anim8 = require("lib.anim8")
local movement = require('gamePlay.player.movement')
local input = require('gamePlay.player.input')
local battleSys= require('gamePlay.player.battleSys')

-- Remove player's own world creation - use the shared world from main.lua
local world = nil  -- Will be set by main.lua

function player.load(cam, shared_world)
    -- Use the shared world from main.lua
    world = shared_world
    
    player.cam = cam
    player.x = 250
    player.y = 250
    player.height = 64
    player.width = 32
    player.speed = 250
    player.sprite_sheet_idle_states = love.graphics.newImage("assets/player-movement/Sprite-Sheet-idle-states1.png")
    player.sprite_sheet_walk_states = love.graphics.newImage("assets/player-movement/Sprite-Sheet-walk-states1.png")
    player.sprite_sheet_dash= love.graphics.newImage("assets/player-movement/Sprite-Sheet-dash.png")
    -- player.sprite_sheet_run = love.graphics.newImage("assets/player-movement/Sprite-Sheet-run.png") -- Uncomment when you have the sprite
    
    player.state = "idle_front"
    player.last_direction = "down"
    player.is_moving = false
    player.prev_state = "idle_front"
    player.life = 100
    player.max_life = 100
    player.spirit = 100
    player.weapon = "sword"
    player.weapon_visible = true
    player.max_spirit = 100
    
    -- Attack system variables
    player.isAttacking = false
    player.attack_duration = 0.5
    player.attack_timer = 0
    player.can_move_while_attacking = false
    player.attack_damage = 15
    player.attack_range = 40
    
    -- Dash system variables
    player.isDashing = false
    player.dash_duration = 0.4
    player.dash_timer = 0
    player.dash_speed = 600
    player.dash_cooldown = 0.3
    player.dash_cooldown_timer = 0
    
    -- PHYSICS SYSTEM - New variables for sliding effect
    player.velocity_x = 0
    player.velocity_y = 0
    player.friction = 0.95           -- How quickly player stops (lower = more sliding)
    player.acceleration = 800        -- How quickly player accelerates
    player.max_velocity = 300        -- Maximum velocity to prevent infinite speed
    player.dash_friction = 0.92      -- Special friction after dashing (more sliding)
    player.dash_end_timer = 0        -- Timer for post-dash sliding effect
    
    -- RUNNING SYSTEM - New variables for running animation
    player.is_running = false        -- Whether player is currently running
    player.run_threshold_time = 0.3  -- Hold space for this long to start running
    player.space_hold_timer = 0      -- Timer for space key holding
    player.run_speed_multiplier = 1.5 -- Speed multiplier when running
    player.space_pressed_last_frame = false -- To detect space key press/release
    
    -- BATTLE SYSTEM - New variables for combat
    player.invulnerable = false      -- Invulnerability frames after taking damage
    player.invulnerability_duration = 1.0  -- How long invulnerability lasts
    player.invulnerability_timer = 0
    player.flash_timer = 0           -- For visual feedback when taking damage
    player.destroyed = false         -- For consistency with enemy system
    
    -- Attack colliders storage
    player.attack_colliders = {}
    
    sword.load()
    
    -- Create separate grids for each sprite sheet
    player.grid_idle = anim8.newGrid(32, 64, player.sprite_sheet_idle_states:getWidth(), player.sprite_sheet_idle_states:getHeight())
    player.grid_walk = anim8.newGrid(32, 64, player.sprite_sheet_walk_states:getWidth(), player.sprite_sheet_walk_states:getHeight())
    player.grid_dash = anim8.newGrid(32, 64, player.sprite_sheet_dash:getWidth(), player.sprite_sheet_dash:getHeight())
    -- player.grid_run = anim8.newGrid(32, 64, player.sprite_sheet_run:getWidth(), player.sprite_sheet_run:getHeight()) -- Uncomment when you have the sprite
    
    -- Create collider using the shared world
    local feet_collider_width = 30
    local feet_collider_height = 20
    local feet_x = player.x + player.width / 2
    local feet_y = player.y + player.height - 10
    
    player.collider = world:newRectangleCollider(
        feet_x, feet_y, 
        feet_collider_width, feet_collider_height
    )
    player.collider:setFixedRotation(true)
    player.collider:setCollisionClass('Player')
    
    -- Set up player collision data for the battle system
    player.collider:setUserData({
        type = "player",
        life = player.life,
        max_life = player.max_life,
        takeDamage = function(damage)
            return player.takeDamage(damage)
        end,
        destroyed = false
    })
    
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
        walk_up = anim8.newAnimation(player.grid_walk('1-4', 4), 0.15),
        -- Dash animations
        dash_down = anim8.newAnimation(player.grid_dash('1-7', 1), 0.04),
        dash_right = anim8.newAnimation(player.grid_dash('1-7', 2), 0.04),
        dash_left = anim8.newAnimation(player.grid_dash('1-7', 3), 0.04),
        dash_up = anim8.newAnimation(player.grid_dash('1-7', 4), 0.04),
        -- Running animations (using walk sprites for now, uncomment when you have run sprites)
        run_down = anim8.newAnimation(player.grid_walk('1-4', 1), 0.1),  -- Faster animation
        run_right = anim8.newAnimation(player.grid_walk('1-4', 2), 0.1),
        run_left = anim8.newAnimation(player.grid_walk('1-4', 3), 0.1),
        run_up = anim8.newAnimation(player.grid_walk('1-4', 4), 0.1),
        -- When you have run sprites, replace above with:
        -- run_down = anim8.newAnimation(player.grid_run('1-4', 1), 0.1),
        -- run_right = anim8.newAnimation(player.grid_run('1-4', 2), 0.1),
        -- run_left = anim8.newAnimation(player.grid_run('1-4', 3), 0.1),
        -- run_up = anim8.newAnimation(player.grid_run('1-4', 4), 0.1),
    }
    
    for _, anim in pairs(player.animations) do
        anim:gotoFrame(1)
    end
end

-- BATTLE SYSTEM FUNCTIONS
function player.takeDamage(damage)
    battleSys.takeDamage(player, damage)
end
function player.onAttackHit(enemy)
   battleSys.onAttackHit(player, enemy)
end

function player.createAttackCollider()
   battleSys.createAttackCollider(player)
end
function player.updateAttackColliders(dt)
    battleSys.updateAttackColliders(player, dt)
end

function player.removeAttackCollider(collider)
    battleSys.removeAttackCollider(player, collider)
end

function player.clearAttackColliders()
    battleSys.clearAttackColliders(player)
end

function player.handleInput(dt)
    input.handleInput(player, dt)
end

function player.startAttack()
   battleSys.startAttack(player,sword)
end


function player.updateAttack(dt)
    battleSys.updateAttack(player, dt)
end

function player.updateBattleSystem(dt)
    battleSys.updateBattleSystem(player, dt)
end

function player.startDash()
    movement.startDash(player)
end
function player.updateDash(dt)
    movement.updateDash(player, dt)
end
function player.handleMovement(dt)
    movement.handleMovement(player, dt)
end

function player.updateState()
    movement.updateState(player)
end

function player.update(dt)
    -- Don't update if player is destroyed
    if player.destroyed then
        return
    end
    
    player.handleInput(dt)
    player.updateAttack(dt)
    player.updateAttackColliders(dt)  -- Add this line
    player.updateDash(dt)
    player.updateBattleSystem(dt)  -- New battle system update
    player.handleMovement(dt)
    player.updateState()
    
    -- Update camera to follow player smoothly
    if player.cam then
        player.cam:lookAt(player.x + player.width/2, player.y + player.height/2)
    end
    
    if player.animations[player.state] then
        player.animations[player.state]:update(dt)
        sword.update(dt)
    end
end

function player.draw()
    -- Don't draw if player is destroyed
    if player.destroyed then
        return
    end
    
    local scale = 1.5
    local offsetX, offsetY = 0, 0

    -- Flash effect when taking damage
    if player.flash_timer > 0 then
        love.graphics.setColor(1, 0.5, 0.5, 0.8)  -- Red tint
    elseif player.invulnerable then
        -- Flicker effect during invulnerability
        local flicker = math.sin(love.timer.getTime() * 20) > 0
        if flicker then
            love.graphics.setColor(1, 1, 1, 0.5)  -- Semi-transparent
        else
            love.graphics.setColor(1, 1, 1, 1)    -- Normal
        end
    else
        love.graphics.setColor(1, 1, 1, 1)        -- Normal color
    end

    -- Select correct animation and sprite sheet based on state
    local anim = player.animations[player.state]
    local sprite_sheet

    if player.state:match("^dash_") then
        sprite_sheet = player.sprite_sheet_dash
    elseif player.state:match("^run_") then
        -- Use walk sprite sheet for now, change to run sprite sheet when available
        sprite_sheet = player.sprite_sheet_walk_states
        -- sprite_sheet = player.sprite_sheet_run -- Use this when you have run sprites
    elseif player.state:match("^walk_") then
        sprite_sheet = player.sprite_sheet_walk_states
    elseif player.state:match("^idle_") then
        sprite_sheet = player.sprite_sheet_idle_states
    else
        -- fallback
        sprite_sheet = player.sprite_sheet_idle_states
        anim = player.animations.idle_front
    end

    -- Draw sword BEHIND player when attacking upward/backward
    if player.weapon == "sword" and player.weapon_visible and player.isAttacking and player.last_direction == "up" then
        sword.draw()
    end

    -- Draw the player
    if anim then
        anim:draw(
            sprite_sheet,
            player.x + offsetX,
            player.y + offsetY,
            nil,
            scale
        )
    end

    -- Draw sword ON TOP of player for all other directions (but not during dash)
    if player.weapon == "sword" and player.weapon_visible and not player.isDashing and not (player.isAttacking and player.last_direction == "up") then
        sword.draw()
    end
    
    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
    
    -- Debug: Show running state
    if player.is_running then
        love.graphics.setColor(0, 1, 0)
        love.graphics.print("RUNNING", player.x, player.y - 20)
        love.graphics.setColor(1, 1, 1)
    end
    
    -- Debug: Show health and invulnerability
    if player.invulnerable then
        love.graphics.setColor(1, 1, 0)
        love.graphics.print("INVULNERABLE", player.x, player.y - 40)
        love.graphics.setColor(1, 1, 1)
    end
    
    -- Health bar
    love.graphics.setColor(1, 0, 0)
    love.graphics.rectangle("fill", player.x, player.y - 10, player.width * (player.life / player.max_life), 4)
    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.rectangle("line", player.x, player.y - 10, player.width, 4)
    love.graphics.setColor(1, 1, 1)

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