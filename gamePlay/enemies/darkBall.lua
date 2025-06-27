local darkBall = {}
local anim8 = require("lib.anim8")

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
function darkBall.new(x, y)
    local self = {
        x = x or 150,
        y = y or 150,
        speed = 100,
        life = 100,
        maxLife = 100,

        anim_sequence = { "jump", "wink", "wink" },
        current_anim_index = 1,
        anim_timer = 0
    }

    if not sprite_sheet_jump and not loadSharedResources() then
        return nil
    end

    local current_name = self.anim_sequence[self.current_anim_index]
    self.current_anim = animations[current_name]
    self.sprite_sheet = (current_name == "jump") and sprite_sheet_jump or sprite_sheet_wink

    function self.update(dt)
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
        local scale = 2
        if self.current_anim and self.sprite_sheet then
            self.current_anim:draw(self.sprite_sheet, self.x, self.y, 0, scale, scale)
        else
            love.graphics.setColor(1, 0, 0)
            love.graphics.rectangle("fill", self.x, self.y, 32, 64)
            love.graphics.setColor(1, 1, 1)
        end
    end

    return self
end

return darkBall
