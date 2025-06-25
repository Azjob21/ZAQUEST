local darkBall = {}
anim8 = require("lib.anim8")

-- Shared resources for all instances
local sprite_sheet, grid, animation

-- Load shared resources once
local function loadSharedResources()
    local success, err = pcall(function()
        sprite_sheet = love.graphics.newImage("assets/enemies/Sprite-Sheet-dark-ball.png")
    end)
    
    if not success then
        print("Failed to load sprite sheet:", err)
        return false
    end

    local frame_width = 32
    local frame_height = 64
    grid = anim8.newGrid(frame_width, frame_height, 
                         sprite_sheet:getWidth(), 
                         sprite_sheet:getHeight())
    
    success, err = pcall(function()
        animation = anim8.newAnimation(grid('1-17', 1), 0.21)
    end)
    
    if not success then
        print("Failed to create animation:", err)
        return false
    end
    
    return true
end

-- Constructor for new dark balls
function darkBall.new(x, y)
    local self = {
        x = x or 150,
        y = y or 150,
        speed = 100,
        life = 100,
        maxLife = 100
    }

    -- Initialize shared resources if not already loaded
    if not sprite_sheet and not loadSharedResources() then
        return nil
    end

    function self.update(dt)
        if animation then
            animation:update(dt)
        end
    end

    function self.draw()
        local scale = 2

        -- Draw animation or fallback
        if animation and sprite_sheet then
            animation:draw(sprite_sheet, self.x, self.y, 0, scale, scale)
        else
            love.graphics.setColor(1, 0, 0)
            love.graphics.rectangle("fill", self.x, self.y, 32, 64)
            love.graphics.setColor(1, 1, 1)
        end

        love.graphics.setColor(1, 1, 1) -- Reset color
    end

    return self
end

return darkBall
