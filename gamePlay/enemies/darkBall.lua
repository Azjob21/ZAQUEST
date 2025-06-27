local darkBall = {}
local anim8 = require("lib.anim8")
local wf = require 'lib.windfield'

-- Note: We'll use the world from main.lua instead of creating a new one
local world

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

-- Set the world reference (call this from main.lua)
function darkBall.setWorld(world_ref)
    world = world_ref
end

-- Constructor
function darkBall.new(x, y, collider_type, player_ref)
    local self = {
        x = x or 150,
        y = y or 150,
        speed = 200,
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
        chase_speed = 120,    -- Increased speed when chasing player
        idle_speed = 0,      -- Speed when not chasing
        detection_range = 300 -- Range to detect player
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
        self.collider = world:newCircleCollider(self.x, self.y, self.radius-20)
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
    
    local current_name = self.anim_sequence[self.current_anim_index]
    self.current_anim = animations[current_name]
    self.sprite_sheet = (current_name == "jump") and sprite_sheet_jump or sprite_sheet_wink
    
    function self.update(dt)
        if self.destroyed then return end
        
        -- Update physics position
        if self.collider then
            self.x, self.y = self.collider:getPosition()
        end
        
        -- Get current animation name
        local current_name = self.anim_sequence[self.current_anim_index]
        
        -- Move towards player logic
        if self.player and self.collider then
            -- Get player position - handle both collider and direct position
            local player_x, player_y
            if self.player.collider then
                player_x, player_y = self.player.collider:getPosition()
            else
                player_x = self.player.x + (self.player.width or 32) / 2
                player_y = self.player.y + (self.player.height or 64) / 2
            end
            
            -- Calculate distance to player
            local dx = player_x - self.x
            local dy = player_y - self.y
            local distance = math.sqrt(dx * dx + dy * dy)
            
            -- Different behavior based on animation and distance
            if current_name == "jump" then
                -- Always chase during jump animation
                if distance > 5 then -- Avoid jittering when very close
                    local dir_x = (dx / distance) * self.chase_speed
                    local dir_y = (dy / distance) * self.chase_speed
                    self.collider:setLinearVelocity(dir_x, dir_y)
                else
                    self.collider:setLinearVelocity(0, 0)
                end
            else
                -- During wink animations, slow down but still move slightly towards player
                if distance < self.detection_range and distance > 5 then
                    local dir_x = (dx / distance) * (self.idle_speed * 0.5)
                    local dir_y = (dy / distance) * (self.idle_speed * 0.5)
                    self.collider:setLinearVelocity(dir_x, dir_y)
                else
                    -- Apply damping to slow down
                    local vx, vy = self.collider:getLinearVelocity()
                    self.collider:setLinearVelocity(vx * 0.9, vy * 0.9)
                end
            end
        else
            -- No player reference, just slow down
            if self.collider then
                local vx, vy = self.collider:getLinearVelocity()
                self.collider:setLinearVelocity(vx * 0.95, vy * 0.95)
            end
        end
        
        -- Update animation
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
            local offset_x = self.width * scale / 2 + 60
            local offset_y = self.height * scale / 2 + 80
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
    
    function self.setDetectionRange(range)
        self.detection_range = range
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
    -- Don't add 'Player' here since it's already added in player.lua
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