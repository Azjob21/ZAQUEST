local NUM_DARK_BALLS = 5
local dark_balls = {}
local cached_pillar_tiles = {}  -- Cache pillar tiles to avoid recreating every frame

function love.load()
    wf = require 'lib/windfield'
    world = wf.newWorld(0, 0)
    world:addCollisionClass('Player') 
    sti = require "lib/sti"
    local camera = require("lib.camera")  
    cam = camera() -- Initialize the camera
    love.graphics.setDefaultFilter("nearest", "nearest")
    background = love.graphics.newImage("assets/testground/background.png")
    player = require("gamePlay.player")
    dark_ball = require("gamePlay.enemies.darkBall")
    love.window.setTitle("ZaQuest")
    
    player.load(cam)
    gameMap = sti("assets/testground/testGround.lua") -- Load Tiled map

    -- IMPORTANT: Set the world reference for dark balls BEFORE creating them
    dark_ball.setWorld(world)
    dark_ball.initializeCollisionClasses(world)
    dark_ball.setupCollisionCallbacks(world)

    -- Spawn dark balls
    for i = 1, NUM_DARK_BALLS do
        local x = 100 + (i - 1) * 150
        local y = 100 + math.random(0, 200)
        local ball = dark_ball.new(x, y, "circle", player) -- Pass player reference directly
        if ball then
            table.insert(dark_balls, ball)
            print("Created dark ball", i, "at position", x, y)
        else
            print("Failed to create dark ball instance", i)
        end
    end

    -- Add wall colliders from object layer
    if gameMap.layers["walls"] then
        for _, wall in ipairs(gameMap.layers["walls"].objects) do
            local collider = world:newRectangleCollider(wall.x, wall.y, wall.width, wall.height)
            collider:setType("static")
        end
    end
    
    -- Cache pillar tiles once during load to avoid memory leaks
    cached_pillar_tiles = getPillarTiles()
end

function love.update(dt)
    cam:lookAt(player.x + 32, player.y + 32)
    player.update(dt)

    -- Update dark balls
    for i, ball in ipairs(dark_balls) do
        if ball and ball.update then
            ball.update(dt)
        else
            print("Invalid ball at index", i)
        end
    end

    if gameMap then
        gameMap:update(dt)
    end

    -- Clamp camera inside map
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local mapWidth = gameMap.width * gameMap.tilewidth
    local mapHeight = gameMap.height * gameMap.tileheight

    cam.x = math.max(w / 2, math.min(cam.x, mapWidth - w / 2))
    cam.y = math.max(h / 2, math.min(cam.y, mapHeight - h / 2))

    world:update(dt)
end

function getPillarTiles()
    local drawables = {}
    
    -- Validate gameMap and layer existence
    if not gameMap or not gameMap.layers then 
        print("WARNING: gameMap or layers missing")
        return drawables 
    end

    local layer = gameMap.layers["pillars"]
    if not layer or layer.type ~= "tilelayer" then
        print("WARNING: Invalid pillar layer -", layer and "wrong type" or "missing")
        return drawables
    end

    -- Check if layer.data exists and is properly structured
    if not layer.data or type(layer.data) ~= "table" then
        print("WARNING: Invalid layer data")
        return drawables
    end

    -- First pass: collect all pillar tiles and group them by column
    local pillar_columns = {}
    
    for y = 1, layer.height do
        -- Check if row exists
        if not layer.data[y] then
            print("WARNING: Missing row", y)
            goto continue
        end
        
        for x = 1, layer.width do
            local tile = layer.data[y][x]
            
            -- Skip empty/nil tiles (0 or nil means no tile)
            if not tile or tile == 0 then
                goto continue_tile
            end
            
            -- Handle different tile data structures
            local tileset_obj = nil
            local quad = nil
            
            if type(tile) == "table" then
                -- Tile is an object with tileset reference
                if type(tile.tileset) == "number" then
                    -- tileset is an ID, get the actual tileset from gameMap
                    if gameMap.tilesets and gameMap.tilesets[tile.tileset] then
                        tileset_obj = gameMap.tilesets[tile.tileset]
                    end
                elseif type(tile.tileset) == "table" then
                    -- tileset is already the tileset object
                    tileset_obj = tile.tileset
                end
                quad = tile.quad
            elseif type(tile) == "number" then
                -- Tile is just a GID number, need to find the tileset
                local gid = tile
                if gameMap.tilesets then
                    for _, tileset in ipairs(gameMap.tilesets) do
                        if gid >= tileset.firstgid and gid < (tileset.firstgid + tileset.tilecount) then
                            tileset_obj = tileset
                            -- Calculate quad from GID
                            local tid = gid - tileset.firstgid
                            local tiles_per_row = math.floor(tileset.imagewidth / tileset.tilewidth)
                            local tile_x = (tid % tiles_per_row) * tileset.tilewidth
                            local tile_y = math.floor(tid / tiles_per_row) * tileset.tileheight
                            quad = love.graphics.newQuad(tile_x, tile_y, tileset.tilewidth, tileset.tileheight, tileset.imagewidth, tileset.imageheight)
                            break
                        end
                    end
                end
            end
            
            -- Skip if we couldn't resolve the tileset or quad
            if not tileset_obj or not tileset_obj.image or not quad then
                print("WARNING: Could not resolve tileset/quad for tile at", x, y, "tile data:", type(tile))
                goto continue_tile
            end
            
            local tile_x = (x - 1) * (gameMap.tilewidth or 16)
            local tile_y = (y - 1) * (gameMap.tileheight or 16)
            local tile_height = gameMap.tileheight or 16
            
            -- Group tiles by column (x position) to find pillar structures
            local column_key = tile_x
            if not pillar_columns[column_key] then
                pillar_columns[column_key] = {}
            end
            
            table.insert(pillar_columns[column_key], {
                x = tile_x,
                y = tile_y,
                quad = quad,
                image = tileset_obj.image,
                bottom = tile_y + tile_height,
                grid_y = y  -- Keep track of grid position for sorting
            })
            
            ::continue_tile::
        end
        ::continue::
    end
    
    -- Second pass: process each column to find pillar structures and assign proper depth
    for column_x, tiles in pairs(pillar_columns) do
        -- Sort tiles in this column by their y position
        table.sort(tiles, function(a, b) return a.grid_y < b.grid_y end)
        
        -- Find connected pillar structures in this column
        local pillar_groups = {}
        local current_group = {}
        
        for i, tile in ipairs(tiles) do
            if #current_group == 0 then
                -- Start new group
                table.insert(current_group, tile)
            else
                local last_tile = current_group[#current_group]
                -- Check if this tile is directly below the last one (connected)
                if tile.grid_y == last_tile.grid_y + 1 then
                    -- Connected - add to current group
                    table.insert(current_group, tile)
                else
                    -- Gap found - finish current group and start new one
                    table.insert(pillar_groups, current_group)
                    current_group = {tile}
                end
            end
        end
        
        -- Don't forget the last group
        if #current_group > 0 then
            table.insert(pillar_groups, current_group)
        end
        
        -- Process each pillar group
        for _, group in ipairs(pillar_groups) do
            if #group > 0 then
                -- Find the bottom-most tile in this pillar group
                local pillar_bottom = 0
                for _, tile in ipairs(group) do
                    pillar_bottom = math.max(pillar_bottom, tile.bottom)
                end
                
                -- Assign the pillar bottom to all tiles in this group
                for _, tile in ipairs(group) do
                    tile.pillar_bottom = pillar_bottom
                    table.insert(drawables, tile)
                end
            end
        end
    end
    
    print("Found", #drawables, "valid pillar tiles")
    return drawables
end

function love.draw()
    local success, err = pcall(function()
        if not cam then 
            error("Camera not initialized")
        end
        
        cam:attach()

        -- Draw background layers first (static background)
        if background and type(background) == "userdata" then
            love.graphics.draw(background, 0, 0)
        end
        
        -- Draw all map layers except pillars (they need depth sorting)
        if gameMap then
            for _, layer in pairs(gameMap.layers) do
                if layer.name ~= "pillars" and layer.name ~= "walls" and layer.type == "tilelayer" and layer.visible then
                    gameMap:drawLayer(layer)
                end
            end
        end

        -- Get pillars for depth sorting (use cached tiles)
        local pillar_tiles = cached_pillar_tiles or {}

        -- Get player's position for depth sorting
        local player_x, player_y = 0, 0
        if player.collider then
            player_x, player_y = player.collider:getPosition()
        else
            player_x = player.x or 0
            player_y = (player.y or 0) + (player.height or 32)
        end

        -- Group pillar tiles by their pillar structure (same pillar_bottom = same pillar)
        local pillar_structures = {}
        for _, tile in ipairs(pillar_tiles) do
            if tile and tile.image and tile.quad and tile.x and tile.y then
                local pillar_key = tile.pillar_bottom or (tile.bottom or tile.y)
                if not pillar_structures[pillar_key] then
                    pillar_structures[pillar_key] = {
                        tiles = {},
                        min_x = math.huge,
                        max_x = -math.huge,
                        pillar_bottom = pillar_key
                    }
                end
                
                table.insert(pillar_structures[pillar_key].tiles, tile)
                pillar_structures[pillar_key].min_x = math.min(pillar_structures[pillar_key].min_x, tile.x)
                pillar_structures[pillar_key].max_x = math.max(pillar_structures[pillar_key].max_x, tile.x + (gameMap.tilewidth or 16))
            end
        end
        
        -- Separate pillars into those behind and in front of player
        local pillars_behind = {}
        local pillars_front = {}
        
        for _, pillar_struct in pairs(pillar_structures) do
            -- Check if player overlaps with the entire pillar structure horizontally
            local player_width = player.width or 32
            local player_left = player_x - player_width / 2
            local player_right = player_x + player_width / 2
            local pillar_left = pillar_struct.min_x
            local pillar_right = pillar_struct.max_x
            
            -- Check if player and pillar overlap horizontally
            local player_inside_pillar_x = not (player_right < pillar_left or player_left > pillar_right)
            
            -- Decide where to place ALL tiles of this pillar structure
            local place_behind = true
            if player_inside_pillar_x then
                -- Player overlaps with pillar - use Y-axis depth sorting
                place_behind = pillar_struct.pillar_bottom <= player_y
            end
            
            -- Add all tiles of this pillar to the appropriate list
            for _, tile in ipairs(pillar_struct.tiles) do
                if place_behind then
                    table.insert(pillars_behind, tile)
                else
                    table.insert(pillars_front, tile)
                end
            end
        end
        
        -- Draw pillars behind player first
        for _, tile in ipairs(pillars_behind) do
            love.graphics.draw(tile.image, tile.quad, tile.x, tile.y)
        end
        
        -- Draw enemies behind player
        for _, ball in ipairs(dark_balls) do
            if ball and type(ball.draw) == "function" then
                local ball_depth = (ball.y or 0) + (ball.height or 0)
                if ball_depth <= player_y then
                    ball.draw()
                end
            end
        end
        
        -- Draw player
        if player.draw then
            player.draw()
        end
        
        -- Draw pillars in front of player
        for _, tile in ipairs(pillars_front) do
            love.graphics.draw(tile.image, tile.quad, tile.x, tile.y)
        end
        
        -- Draw enemies in front of player
        for _, ball in ipairs(dark_balls) do
            if ball and type(ball.draw) == "function" then
                local ball_depth = (ball.y or 0) + (ball.height or 0)
                if ball_depth > player_y then
                    ball.draw()
                end
            end
        end
        
        -- Optional: Remove this line if you don't want to see debug colliders
        -- world:draw() 

        cam:detach()
    end)

    if not success then
        print("FULL RENDER ERROR:", err)
        -- More detailed error display
        love.graphics.setColor(1, 0, 0)
        love.graphics.print("RENDER ERROR: "..tostring(err), 10, 10)
        love.graphics.setColor(1, 1, 1)
    end
end

-- Optional: Add debug keys
function love.keypressed(key)
    if key == "f2" then
        -- Print debug info about dark balls
        print("=== Dark Ball Debug Info ===")
        for i, ball in ipairs(dark_balls) do
            if ball then
                print("Ball", i, "Position:", ball.x, ball.y, "Animation:", ball.getCurrentAnimation())
                if ball.player then
                    print("  Player reference exists")
                else
                    print("  NO PLAYER REFERENCE!")
                end
            end
        end
    end
end