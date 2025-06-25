local NUM_DARK_BALLS = 5
local dark_balls = {}

function love.load()
    local camera = require("lib.camera")
    cam = camera() -- Initialize the camera
    love.graphics.setDefaultFilter("nearest", "nearest")
    background = love.graphics.newImage("assets/testground/background.png")
    player = require("gamePlay.player")
    dark_ball = require("gamePlay.enemies.darkBall") -- This now returns a module with 'new' function
    love.window.setTitle("ZaQuest")
    player.load(cam)

    -- Create multiple dark balls at different locations
    for i = 1, NUM_DARK_BALLS do
        -- Spread them out with some randomness
        local x = 100 + (i-1) * 150
        local y = 100 + math.random(0, 200)
        local ball = dark_ball.new(x, y)
        if ball then
            table.insert(dark_balls, ball)
        else
            print("Failed to create dark ball instance", i)
        end
    end
end

function love.update(dt)
    
    cam:lookAt(player.x + 32, player.y + 32)
    player.update(dt)
    for _, ball in ipairs(dark_balls) do
        ball.update(dt)
    end
end

function love.draw()
    cam:attach() -- Attach the camera
    love.graphics.draw(background, 0, 0)
    player.draw()
    for _, ball in ipairs(dark_balls) do
        ball.draw()
    end
    cam:detach() -- Detach the camera
end