--[[
    Contains tile data and necessary code for rendering a tile map to the
    screen.
]]

require 'Util'

Map = Class{}

TILE_BRICK = 1
TILE_EMPTY = -1

-- cloud tiles
CLOUD_LEFT = 6
CLOUD_RIGHT = 7

-- bush tiles
BUSH_LEFT = 2
BUSH_RIGHT = 3

-- mushroom tiles
MUSHROOM_TOP = 10
MUSHROOM_BOTTOM = 11

-- jump block
JUMP_BLOCK = 5
JUMP_BLOCK_HIT = 9

-- flag pole
FLAG_POLE_TOP = 8
FLAG_POLE_MID = 12
FLAG_POLE_BOT = 16

-- flag
FLAG1 = 13
FLAG2 = 14

-- a speed to multiply delta time to scroll map; smooth value
local SCROLL_SPEED = 62

-- constructor for our map object
function Map:init()

    self.spritesheet = love.graphics.newImage('graphics/spritesheet.png')
    self.sprites = generateQuads(self.spritesheet, 16, 16)
    self.music = love.audio.newSource('sounds/music.wav', 'static')

    self.tileWidth = 16
    self.tileHeight = 16
    self.mapWidth = 150
    self.mapHeight = 28
    self.tiles = {}
    self.animations = {}

    -- applies positive Y influence on anything affected
    self.gravity = 15

    -- associate player with map
    self.player = Player(self)

    -- camera offsets
    self.camX = 0
    self.camY = -3

    -- cache width and height of map in pixels
    self.mapWidthPixels = self.mapWidth * self.tileWidth
    self.mapHeightPixels = self.mapHeight * self.tileHeight

    -- first, fill map with empty tiles
    for y = 1, self.mapHeight do
        for x = 1, self.mapWidth do
            
            -- support for multiple sheets per tile; storing tiles as tables 
            self:setTile(x, y, TILE_EMPTY)
        end
    end

    -- begin generating the terrain using vertical scan lines
    local x = 1
    while x <= self.mapWidth - 27 do
        
        -- 10% chance to generate a cloud
        -- make sure we're 2 tiles from edge at least
        if x < self.mapWidth - 2 then
            if math.random(10) == 1 then
                
                -- choose a random vertical spot above where blocks/pipes generate
                local cloudStart = math.random(self.mapHeight / 2 - 6)

                self:setTile(x, cloudStart, CLOUD_LEFT)
                self:setTile(x + 1, cloudStart, CLOUD_RIGHT)
            end
        end

        -- 10% chance to generate a rising pyramid
        if math.random(10) == 1 and x < self.mapWidth - 27 * 2 and x > 18 then
            -- random height
            local pyramid_height = math.random(3, 5)
            -- creates pyramid
            for pyramid_x = 1, pyramid_height do
                for pyramid_y = 1, pyramid_x do
                    self:setTile(x + pyramid_x, self.mapHeight / 2 - pyramid_y, TILE_BRICK)
                end
                for y = self.mapHeight / 2, self.mapHeight do
                    self:setTile(x + pyramid_x, y, TILE_BRICK)
                end
            end
            x = x + pyramid_height
            -- 50% chance to create empty gap
            local tile_type = math.random(2) == 1 and TILE_BRICK or TILE_EMPTY
            for i = 1, 3 do
                for y = self.mapHeight / 2, self.mapHeight do
                    self:setTile(x + i, y, tile_type)
                end
            end
            x = x + 3
            -- 33% chance to generate flipped pyramid
            if math.random(3) == 1 then
                local pyramid_height = pyramid_height + math.random(1, 6)
                -- creates pyramid
                for pyramid_x = 1, pyramid_height do
                    for pyramid_y = 1, pyramid_height - pyramid_x do
                        self:setTile(x + pyramid_x, self.mapHeight / 2 - pyramid_y, TILE_BRICK)
                    end
                    for y = self.mapHeight / 2, self.mapHeight do
                        self:setTile(x + pyramid_x, y, TILE_BRICK)
                    end
                end
                x = x + pyramid_height
            end
        -- 5% chance to generate a mushroom
        elseif math.random(20) == 1 then
            -- left side of pipe
            self:setTile(x, self.mapHeight / 2 - 2, MUSHROOM_TOP)
            self:setTile(x, self.mapHeight / 2 - 1, MUSHROOM_BOTTOM)

            -- creates column of tiles going to bottom of map
            for y = self.mapHeight / 2, self.mapHeight do
                self:setTile(x, y, TILE_BRICK)
            end

            -- next vertical scan line
            x = x + 1

        -- 10% chance to generate bush, being sure to generate away from edge
        elseif math.random(10) == 1 and x < self.mapWidth - 3 then
            local bushLevel = self.mapHeight / 2 - 1

            -- place bush component and then column of bricks
            self:setTile(x, bushLevel, BUSH_LEFT)
            for y = self.mapHeight / 2, self.mapHeight do
                self:setTile(x, y, TILE_BRICK)
            end
            x = x + 1

            self:setTile(x, bushLevel, BUSH_RIGHT)
            for y = self.mapHeight / 2, self.mapHeight do
                self:setTile(x, y, TILE_BRICK)
            end
            x = x + 1

        -- 10% chance to not generate anything, creating a gap
        elseif math.random(10) ~= 1 then
            
            -- creates column of tiles going to bottom of map
            for y = self.mapHeight / 2, self.mapHeight do
                self:setTile(x, y, TILE_BRICK)
            end

            -- chance to create a block for Mario to hit
            if math.random(15) == 1 then
                self:setTile(x, self.mapHeight / 2 - 4, JUMP_BLOCK)
            end

            -- next vertical scan line
            x = x + 1
        else
            -- increment X so we skip two scanlines, creating a 2-tile gap
            x = x + 2
        end
    end
    -- generate end pyramid with flag
    while x <= self.mapWidth do
        -- constants
        local flag_position = 3
        local flag_pole_height = 10
        local pyramid_base = 19
        local pyramid_height = 8

        -- creates column of tiles going to bottom of map
        for y = self.mapHeight / 2, self.mapHeight do
            self:setTile(x, y, TILE_BRICK)
        end
        
        -- creates pyramid
        if x == self.mapWidth - pyramid_base then
            for pyramid_x = 1, pyramid_height do
                for pyramid_y = 1, pyramid_x do
                    self:setTile(x + pyramid_x, self.mapHeight / 2 - pyramid_y, TILE_BRICK)
                end
            end
        end

        if x == self.mapWidth - flag_position then
            -- creates flagpole
            self:setTile(x, self.mapHeight / 2 - 1, FLAG_POLE_BOT)
            for y = self.mapHeight / 2 - flag_pole_height, self.mapHeight / 2 - 2 do
                self:setTile(x, y, FLAG_POLE_MID)
            end
            self:setTile(x, self.mapHeight / 2 - flag_pole_height, FLAG_POLE_TOP)
            
            -- creates flag
            self:addAnimation(x, self.mapHeight / 2 - flag_pole_height, Animation{
                    texture = self.spritesheet,
                    frames = {
                        self.sprites[FLAG1],
                        self.sprites[FLAG2]
                    },
                    interval = 0.2},
                10, 6  -- x, y pixel offsets
            )
        end
        
        x = x + 1
    end

    -- start the background music
    self.music:setLooping(true)
    self.music:play()
end

-- return whether a given tile is collidable
function Map:collides(tile)
    -- define our collidable tiles
    local collidables = {
        TILE_BRICK, JUMP_BLOCK, JUMP_BLOCK_HIT,
        MUSHROOM_TOP, MUSHROOM_BOTTOM
    }

    -- iterate and return true if our tile type matches
    for _, v in ipairs(collidables) do
        if tile.id == v then
            return true
        end
    end

    return false
end

-- return whether a given tile is touchable
function Map:touch(tile)
    -- touchables
    local touchables = {
        FLAG_POLE_BOT, FLAG_POLE_MID, FLAG_POLE_TOP
    }
    -- iterate and return true if tile type matches
    for _, v in ipairs(touchables) do
        if tile.id == v then
            return true
        end
    end
    return false
end

-- function to update camera offset with delta time
function Map:update(dt)
    self.player:update(dt)
    -- update animations
    for _, animation in ipairs(self.animations) do
        animation['animation']:update(dt)
    end
    -- keep camera's X coordinate following the player, preventing camera from
    -- scrolling past 0 to the left and the map's width
    self.camX = math.max(0, math.min(self.player.x - VIRTUAL_WIDTH / 2,
        math.min(self.mapWidthPixels - VIRTUAL_WIDTH, self.player.x)))
end

-- gets the tile type at a given pixel coordinate
function Map:tileAt(x, y)
    return {
        x = math.floor(x / self.tileWidth) + 1,
        y = math.floor(y / self.tileHeight) + 1,
        id = self:getTile(math.floor(x / self.tileWidth) + 1, math.floor(y / self.tileHeight) + 1)
    }
end

-- returns an integer value for the tile at a given x-y coordinate
function Map:getTile(x, y)
    return self.tiles[(y - 1) * self.mapWidth + x]
end

-- sets a tile at a given x-y coordinate to an integer value
function Map:setTile(x, y, id)
    self.tiles[(y - 1) * self.mapWidth + x] = id
end

-- adds an animation to a given x-y coordinate to an integer value
function Map:addAnimation(x, y, animation, xo, yo)
    -- offsets
    xo = xo or 0
    yo = yo or 0
    table.insert(self.animations, {x = x, y = y, animation = animation, xo = xo, yo = yo})
end

-- renders our map to the screen, to be called by main's render
function Map:render()
    for y = 1, self.mapHeight do
        for x = 1, self.mapWidth do
            local tile = self:getTile(x, y)
            if tile ~= TILE_EMPTY then
                love.graphics.draw(self.spritesheet, self.sprites[tile],
                    (x - 1) * self.tileWidth, (y - 1) * self.tileHeight)
            end
        end
    end

    for _, animation in ipairs(self.animations) do
        love.graphics.draw(
            self.spritesheet,
            animation['animation']:getCurrentFrame(),
            (animation['x'] - 1) * self.tileWidth + animation['xo'],
            (animation['y'] - 1) * self.tileHeight + animation['yo']
        )
    end

    self.player:render()
end
