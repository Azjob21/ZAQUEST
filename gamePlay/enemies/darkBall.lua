local darkBall = {}
local anim8 = require("lib.anim8")
local wf = require 'lib.windfield'
local world = wf.newWorld(0, 0)

-- Shared resources
local sprite_sheet_jump, sprite_sheet_wink
local grid1, grid2
local animations = {}

local function loadSharedResources()
    local success, err = pcall(function()
        sprite_sheet_jump = love.graphics.newImage("assets/enemies/Sprite-Sheet-dark-ball.png")
        sprite_sheet_wink = love.graphics.newImage("assets/enemies/Sprite-Sheet-dark-ball-wink.png")
    end)
    
    if not success then
        print("Failed to load sprite sheets:", err)
        return false
    end
    
    local frame_width, frame_height = 64, 64
    grid1 = anim8.newGrid(frame_width, frame_height, sprite_sheet_jump:getWidth(), sprite_sheet_jump:getHeight())
    grid2 = anim8.newGrid(frame_width, frame_height, sprite_sheet_wink:getWidth(), sprite_sheet_wink:getHeight())
    
    success, err = pcall(function()
        animations.jump = anim8.newAnimation(grid1('1-30', 1), 0.1)
        animations.wink = anim8.newAnimation(grid2('1-9', 1), 0.21)
    end)
    
    if not success then
        print("Failed to create animations:", err)
        return false
    end
    
    return true
end

-- Constructor
function darkBall.new(x, y, collider_type, player_ref)
    local self = {
        x = x or 150,
        y = y or 150,
        speed = 100,
        life = 100,
        maxLife = 100,
        
        anim_sequence = { "jump", "wink", "wink" },
        current_anim_index = 1,
        anim_timer = 0,
        
        -- Collider properties
        collider = nil,
        collider_type = collider_type or "circle", -- "circle" or "rectangle"
        radius = 32, -- for circle collider
        width = 64,  -- for rectangle collider
        height = 64, -- for rectangle collider
        destroyed = false,
        
        -- Player tracking
        player = player_ref, -- Reference to player object
        chase_speed = 80,    -- Speed when chasing player
        idle_speed = 20      -- Speed when not chasing
    }
    
    if not sprite_sheet_jump and not loadSharedResources() then
        return nil
    end
    
    -- Create collider based on type
    if self.collider_type == "circle" then
        self.collider = world:newCircleCollider(self.x, self.y, self.radius)
    else
        self.collider = world:newRectangleCollider(self.x - self.width/2, self.y - self.height/2, self.width, self.height)
    end
    
    -- Set collider properties
    self.collider:setType('dynamic') -- Can be 'static', 'dynamic', or 'kinematic'
    self.collider:setUserData(self) -- Store reference to self for collision callbacks
    
    -- Set collision class (only if classes have been initialized)
    local success, err = pcall(function()
        self.collider:setCollisionClass('darkBall')
    end)
    if not success then
        print("Warning: Collision class not set. Call darkBall.initializeCollisionClasses() first")
    end
    
    local current_name = self.anim_sequence[self.current_anim_index]
    self.current_anim = animations[current_name]
    self.sprite_sheet = (current_name == "jump") and sprite_sheet_jump or sprite_sheet_wink
    
    function self.update(dt)
        if self.destroyed then return end
        
        -- Update physics position
        if self.collider then
            self.x, self.y = self.collider:getPosition()
        end
        
        -- Move towards player during jump animation
        local current_name = self.anim_sequence[self.current_anim_index]
        if current_name == "jump" and self.player and self.collider then
            local player_x, player_y = self.player.x, self.player.y
            local dx = player_x - self.x
            local dy = player_y - self.y
            local distance = math.sqrt(dx * dx + dy * dy)
            
            if distance > 0 then
                -- Normalize direction vector and apply speed
                local dir_x = (dx / distance) * self.chase_speed
                local dir_y = (dy / distance) * self.chase_speed
                
                -- Set velocity towards player
                self.collider:setLinearVelocity(dir_x, dir_y)
            end
        else
            -- Stop moving or apply gentle random movement during wink
            if self.collider then
                local vx, vy = self.collider:getLinearVelocity()
                -- Apply damping to slow down
                self.collider:setLinearVelocity(vx * 0.95, vy * 0.95)
            end
        end
        
        if self.current_anim then
            self.current_anim:update(dt)
            
            self.anim_timer = self.anim_timer + dt
            if self.anim_timer >= self.current_anim.totalDuration then
                self.anim_timer = 0
                self.current_anim_index = self.current_anim_index % #self.anim_sequence + 1
                
                local anim_name = self.anim_sequence[self.current_anim_index]
                local next_anim = animations[anim_name]
                
                if next_anim then
                    self.current_anim = next_anim
                    self.sprite_sheet = (anim_name == "jump") and sprite_sheet_jump or sprite_sheet_wink
                    self.current_anim:gotoFrame(1)
                else
                    print("Animation not found for:", anim_name)
                end
            end
        end
    end
    
    function self.draw()
        if self.destroyed then return end
        
        local scale = 2
        if self.current_anim and self.sprite_sheet then
            -- Draw sprite centered on collider position
            local offset_x = self.width * scale / 2
            local offset_y = self.height * scale / 2
            self.current_anim:draw(self.sprite_sheet, self.x - offset_x/2, self.y - offset_y/2, 0, scale, scale)
        else
            love.graphics.setColor(1, 0, 0)
            love.graphics.rectangle("fill", self.x - 16, self.y - 32, 32, 64)
            love.graphics.setColor(1, 1, 1)
        end
        
        -- Optional: Draw collider outline for debugging
        if love.keyboard.isDown('f1') then -- Press F1 to see colliders
            love.graphics.setColor(0, 1, 0, 0.3)
            if self.collider_type == "circle" then
                love.graphics.circle("fill", self.x, self.y, self.radius)
            else
                love.graphics.rectangle("fill", self.x - self.width/2, self.y - self.height/2, self.width, self.height)
            end
            love.graphics.setColor(1, 1, 1)

        end
        world:draw() -- Draw all colliders
    end
    
    -- Movement functions
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
    
    -- Collision callback function
    function self.onCollision(other_collider, contact)
        local other = other_collider:getUserData()
        if other then
            print("DarkBall collided with:", other)
            -- Add your collision logic here
        end
    end
    
    -- Player tracking functions
    function self.setPlayer(player_ref)
        self.player = player_ref
    end
    
    function self.setChaseSpeed(speed)
        self.chase_speed = speed
    end
    
    function self.getCurrentAnimation()
        return self.anim_sequence[self.current_anim_index]
    end
    
    function self.isChasing()
        return self.getCurrentAnimation() == "jump"
    end
    
    -- Cleanup function
    function self.destroy()
        if self.collider then
            self.collider:destroy()
            self.collider = nil
        end
        self.destroyed = true
    end
    
    return self
end

-- Module functions for world management
function darkBall.updateWorld(dt)
    world:update(dt)
end

function darkBall.getWorld()
    return world
end

-- Initialize collision classes (call this once before creating any dark balls)
function darkBall.initializeCollisionClasses()
    -- Register collision classes
    world:addCollisionClass('darkBall')
    world:addCollisionClass('player')
    world:addCollisionClass('wall')
    world:addCollisionClass('enemy')
    
    -- Set up collision rules (optional)
    -- world:setCollisionClass('darkBall', 'player', 'cross') -- darkBalls can pass through players but trigger collision
    -- world:setCollisionClass('darkBall', 'wall', 'bounce') -- darkBalls bounce off walls
end

-- Set up collision callbacks (call this once in your main game)
function darkBall.setupCollisionCallbacks()
    world:setCallbacks(
        function(a, b, coll) -- beginContact
            local userData_a = a:getUserData()
            local userData_b = b:getUserData()
            
            if userData_a and userData_a.onCollision then
                userData_a.onCollision(b, coll)
            end
            if userData_b and userData_b.onCollision then
                userData_b.onCollision(a, coll)
            end
        end,
        function(a, b, coll) -- endContact
            -- Handle collision end if needed
        end,
        function(a, b, coll) -- preSolve
            -- Handle pre-collision resolution if needed
        end,
        function(a, b, coll) -- postSolve
            -- Handle post-collision resolution if needed
        end
    )
end

return darkBall