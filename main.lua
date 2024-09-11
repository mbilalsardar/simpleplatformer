-- main.lua

local player = {
    startX = 100,
    startY = 100,
    x = 100,
    y = 100,
    width = 30,
    height = 50,
    speed = 200,
    jumpForce = -400,
    yVelocity = 0,
    isJumping = false,
    jumpCount = 0,
    maxJumps = 2,  -- Allow for double jump
    canJump = true -- New flag to track if the player can initiate a jump
}

local platforms = {}
local screenWidth = 800
local screenHeight = 600
local gravity = 800
local cameraX = 0
local cameraSpeed = 5

local minPlatformDistance = 100
local maxPlatformDistance = 300
local minPlatformWidth = 100
local maxPlatformWidth = 300
local minPlatformY = 200
local maxPlatformY = screenHeight - 100

-- Timer and high score variables
local currentTime = 0
local highScore = 0
local isPaused = false

local function generatePlatform(startX)
    return {
        x = startX,
        y = love.math.random(minPlatformY, maxPlatformY),
        width = love.math.random(minPlatformWidth, maxPlatformWidth),
        height = 20
    }
end

local function initializePlatforms()
    platforms = {} -- Clear existing platforms
    local x = 0
    while x < screenWidth * 2 do
        local platform = generatePlatform(x)
        table.insert(platforms, platform)
        x = platform.x + platform.width + love.math.random(minPlatformDistance, maxPlatformDistance)
    end
end

local function ensurePlatforms()
    local rightmostX = 0
    for _, platform in ipairs(platforms) do
        rightmostX = math.max(rightmostX, platform.x + platform.width)
    end

    while rightmostX < cameraX + screenWidth * 2 do
        local newPlatform = generatePlatform(rightmostX + love.math.random(minPlatformDistance, maxPlatformDistance))
        table.insert(platforms, newPlatform)
        rightmostX = newPlatform.x + newPlatform.width
    end
end

-- Updated collision function
local function checkCollision(player, platform)
    local playerBottom = player.y + player.height
    local platformTop = platform.y

    return player.x < platform.x + platform.width and
        player.x + player.width > platform.x and
        playerBottom <= platformTop and
        playerBottom + player.yVelocity * love.timer.getDelta() >= platformTop    -- Checking player's landing trajectory
end

local function loadHighScore()
    local path = love.filesystem.getSourceBaseDirectory()
    print(path)
    local file = io.open(path .. "/highscore.txt", "r") -- changed to "r" for reading
    if file then
        local contents = file:read("*all")
        if contents ~= "" then
            highScore = tonumber(contents) or 0
            if highScore == nil then
                print("Error: unable to load high score from file")
                highScore = 0
            end
        else
            highScore = 0
        end
        file:close()
    end
end

local function saveHighScore()
    local path = love.filesystem.getSourceBaseDirectory()
    local file = io.open(path .. "/highscore.txt", "w")
    if file then
        file:write(tostring(highScore))
        file:close()
    end
end

local function resetGame()
    player.x = player.startX
    player.y = player.startY
    player.yVelocity = 0
    player.isJumping = false
    player.jumpCount = 0
    player.canJump = true
    cameraX = 0
    currentTime = 0
    initializePlatforms()
end

function love.load()
    love.window.setMode(screenWidth, screenHeight)
    loadHighScore()
    resetGame()
end

function love.update(dt)
    if not isPaused then
      

        -- Player movement
        if love.keyboard.isDown('left') then
            -- Update timer
            -- currentTime = currentTime + dt
            player.x = player.x - player.speed * dt
        elseif love.keyboard.isDown('right') then
            -- Update timer
            currentTime = currentTime + dt
            player.x = player.x + player.speed * dt
        end

        -- Apply gravity
        player.yVelocity = player.yVelocity + gravity * dt
        local newY = player.y + player.yVelocity * dt

        -- Check for collision with platforms
        local onGround = false
        for _, platform in ipairs(platforms) do
            if checkCollision(player, platform) and player.yVelocity > 0 then
                player.y = platform.y - player.height
                player.yVelocity = 0
                player.isJumping = false
                player.jumpCount = 0
                player.canJump = true
                onGround = true
                break
            end
        end
        if not onGround then
            player.y = newY
        end


        -- Update camera with smooth movement
        cameraX = cameraX + (player.x - screenWidth / 4 - cameraX) * dt * cameraSpeed

        -- Check if player has fallen out of view
        if player.y > screenHeight then
            if currentTime > highScore then
                highScore = currentTime
                saveHighScore()
            end
            resetGame()
        end

        -- Remove off-screen platforms and ensure new ones are generated
        for i = #platforms, 1, -1 do
            if platforms[i].x + platforms[i].width < cameraX - screenWidth then
                table.remove(platforms, i)
            end
        end
        ensurePlatforms()

        -- Increase difficulty by gradually speeding up the player
        player.speed = player.speed + dt * 10
    end
end

function love.draw()
    love.graphics.push()
    love.graphics.translate(-cameraX, 0)

    -- Draw player
    love.graphics.setColor(1, 0, 0)
    love.graphics.rectangle('fill', player.x, player.y, player.width, player.height)

    -- Draw platforms
    love.graphics.setColor(0, 1, 0)
    for _, platform in ipairs(platforms) do
        love.graphics.rectangle('fill', platform.x, platform.y, platform.width, platform.height)
    end

    love.graphics.pop()

    -- Draw UI
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Time: " .. string.format("%.2f", currentTime), 10, 10)
    love.graphics.print("High Score: " .. string.format("%.2f", highScore), 10, 30)
    -- love.graphics.print("Jumps: " .. player.jumpCount .. "/" .. player.maxJumps, 10, 50)
    love.graphics.print("Use arrow keys to move and space to jump, press again to double jump", 10, 50)
    love.graphics.print("Press P to pause", 10, screenHeight - 30)

    -- Display pause message if paused
    if isPaused then
        love.graphics.printf("PAUSED", 0, screenHeight / 2, screenWidth, "center")
    end
end

function love.keypressed(key)
    if key == 'space' then
        if player.canJump and player.jumpCount < player.maxJumps then
            player.yVelocity = player.jumpForce
            player.isJumping = true
            player.jumpCount = player.jumpCount + 1
            player.canJump = false
        end
    elseif key == "p" then
        isPaused = not isPaused -- Toggle pause state
    end
end

function love.keyreleased(key)
    if key == 'space' then
        player.canJump = true
    end
end
