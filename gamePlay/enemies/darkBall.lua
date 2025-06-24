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

        -- Draw life bar under the sprite
        local sprite_height = 64 * scale
        local bar_width = 64
        local bar_height = 8
        local bar_x = self.x
        local bar_y = self.y + sprite_height + 4
        local life_ratio = self.life / self.maxLife

        -- Background shadow
        love.graphics.setColor(0, 0, 0, 0.3)
        love.graphics.rectangle("fill", bar_x + 2, bar_y + 2, bar_width, bar_height, 4, 4)

        -- Background (light red)
        love.graphics.setColor(0.3, 0, 0, 0.6)
        love.graphics.rectangle("fill", bar_x, bar_y, bar_width, bar_height, 4, 4)

        -- Life (green bar)
        love.graphics.setColor(0, 0.8, 0)
        love.graphics.rectangle("fill", bar_x, bar_y, bar_width * life_ratio, bar_height, 4, 4)

        -- Border
        love.graphics.setColor(1, 1, 1)
        love.graphics.rectangle("line", bar_x, bar_y, bar_width, bar_height, 4, 4)

        love.graphics.setColor(1, 1, 1) -- Reset color
    end

    return self
end

return darkBall
