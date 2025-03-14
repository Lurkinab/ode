-- Event configuration
local requiredSpeed = 55
local collisionPenalty = 500 -- Points deducted per collision
local resetScoreOnCollision = false -- Set to true to reset score to 0 on collision

-- Collision tracking
local collisionCooldown = 0
local collisionCooldownDuration = 2 -- seconds
local crashCount = 0 -- Tracks collisions, resets when speed = 0

-- Scoring system
local totalScore = 0
local comboMeter = 1 -- Overtake multiplier
local nearMissMultiplier = 1 -- Near miss multiplier
local maxComboMultiplier = 10 -- Applies to both
local highestScore = 0

-- Timer states
local timePassed = 0
local dangerouslySlowTimer = 0
local wheelsWarningTimeout = 0
local nearMissCooldown = 0 -- For resetting near miss streak
local nearMissCooldownDuration = 3 -- 3 seconds

-- Near miss tracking
local nearMissStreak = 0

-- UI position (movable)
local uiPosition = vec2(300, 100) -- Initial position (center of screen adjusted)

-- Car states tracking
local carsState = {}

-- UI elements
local messages = {}
local glitter = {}
local glitterCount = 0
local comboColor = 0

-- Prepare function
function script.prepare(dt)
    return ac.getCarState(1).speedKmh > 60
end

-- Initialize car state
function createCarState()
    return {
        overtaken = false,
        collided = false,
        maxPosDot = 0,
        lastDistance = 1000,
        drivingAlong = true
    }
end

-- Reset all car states
function resetAllCarStates()
    for i = 1, #carsState do
        carsState[i] = createCarState()
    end
end

-- UI message system
function addMessage(text, mood)
    for i = math.min(#messages + 1, 4), 2, -1 do
        messages[i] = messages[i - 1]
        messages[i].targetPos = i
    end
    messages[1] = { text = text, age = 0, targetPos = 1, currentPos = 1, mood = mood }
    if mood == 1 then
        for i = 1, 60 do
            local dir = vec2(math.random() - 0.5, math.random() - 0.5)
            glitterCount = glitterCount + 1
            glitter[glitterCount] = {
                color = rgbm.new(hsv(math.random() * 360, 1, 1):rgb(), 1),
                pos = vec2(80, 140) + dir * vec2(40, 20),
                velocity = dir:normalize():scale(0.2 + math.random()),
                life = 0.5 + 0.5 * math.random()
            }
        end
    end
end

-- Update UI messages and effects
function updateMessages(dt)
    comboColor = comboColor + dt * 10 * comboMeter
    if comboColor > 360 then comboColor = comboColor - 360 end

    for i = 1, #messages do
        local m = messages[i]
        m.age = m.age + dt
        m.currentPos = math.applyLag(m.currentPos, m.targetPos, 0.8, dt)
    end

    for i = glitterCount, 1, -1 do
        local g = glitter[i]
        g.pos:add(g.velocity)
        g.velocity.y = g.velocity.y + 0.02
        g.life = g.life - dt
        g.color.mult = math.saturate(g.life * 4)
        if g.life < 0 then
            if i < glitterCount then
                glitter[i] = glitter[glitterCount]
            end
            glitterCount = glitterCount - 1
        end
    end

    if comboMeter > 10 and math.random() > 0.98 then
        for i = 1, math.floor(comboMeter) do
            local dir = vec2(math.random() - 0.5, math.random() - 0.5)
            glitterCount = glitterCount + 1
            glitter[glitterCount] = {
                color = rgbm.new(hsv(math.random() * 360, 1, 1):rgb(), 1),
                pos = vec2(195, 75) + dir * vec2(40, 20),
                velocity = dir:normalize():scale(0.2 + math.random()),
                life = 0.5 + 0.5 * math.random()
            }
        end
    end
end

-- Handle collision
function handleCollision(source)
    if totalScore > highestScore then
        highestScore = math.floor(totalScore)
        ac.sendChatMessage("New highest score: " .. highestScore .. " points!")
    end

    crashCount = crashCount + 1
    if resetScoreOnCollision then
        totalScore = 0
    else
        totalScore = math.max(0, totalScore - collisionPenalty)
    end
    comboMeter = 1
    nearMissMultiplier = 1
    nearMissStreak = 0

    addMessage('Collision: -' .. collisionPenalty .. ' points', -1)
    addMessage(crashCount, -1) -- Display raw count under collision message
    addMessage('Collision detected (' .. source .. ')', -1)

    collisionCooldown = collisionCooldownDuration
end

-- Update function
function script.update(dt)
    local player = ac.getCarState(1)

    -- Handle engine failure
    if player.engineLifeLeft < 1 then
        if totalScore > highestScore then
            highestScore = math.floor(totalScore)
            ac.sendChatMessage("New highest score: " .. highestScore .. " points!")
        end
        totalScore = 0
        comboMeter = 1
        nearMissMultiplier = 1
        nearMissStreak = 0
        crashCount = 0
        resetAllCarStates()
        return
    end

    timePassed = timePassed + dt

    -- Update cooldowns
    if collisionCooldown > 0 then
        collisionCooldown = collisionCooldown - dt
    end
    if nearMissCooldown > 0 then
        nearMissCooldown = nearMissCooldown - dt
        if nearMissCooldown <= 0 then
            nearMissStreak = 0
            nearMissMultiplier = 1
            ac.debug("Near miss cooldown reset", nearMissCooldown)
        end
    end

    -- Combo and near miss multiplier fade
    local fadingRate = 0.2 * math.lerp(1, 0.1, math.lerpInvSat(player.speedKmh, 80, 200)) + player.wheelsOutside
    comboMeter = math.max(1, comboMeter - dt * fadingRate)
    comboMeter = math.min(comboMeter, maxComboMultiplier)
    nearMissMultiplier = math.max(1, nearMissMultiplier - dt * fadingRate)
    nearMissMultiplier = math.min(nearMissMultiplier, maxComboMultiplier)

    -- Ensure car states match sim
    local sim = ac.getSimState()
    while sim.carsCount > #carsState do
        carsState[#carsState + 1] = createCarState()
    end

    -- Wheels outside check
    if wheelsWarningTimeout > 0 then
        wheelsWarningTimeout = wheelsWarningTimeout - dt
    elseif player.wheelsOutside > 0 then
        addMessage('Car is outside', -1)
        wheelsWarningTimeout = 60
    end

    -- Speed check (separate from reset)
    if player.speedKmh < requiredSpeed then
        if dangerouslySlowTimer > 15 then
            if totalScore > highestScore then
                highestScore = math.floor(totalScore)
                ac.sendChatMessage("New highest score: " .. highestScore .. " points!")
            end
            totalScore = 0
            comboMeter = 1
            nearMissMultiplier = 1
            nearMissStreak = 0
            crashCount = 0
        else
            if dangerouslySlowTimer == 0 then addMessage('Too slow!', -1) end
        end
        dangerouslySlowTimer = dangerouslySlowTimer + dt
        comboMeter = 1
        nearMissMultiplier = 1
    else
        dangerouslySlowTimer = 0
    end

    -- Speed-based reset
    if player.speedKmh <= 0 then
        totalScore = 0
        comboMeter = 1
        nearMissMultiplier = 1
        nearMissStreak = 0
        crashCount = 0
        resetAllCarStates()
        addMessage('Speed 0! Score and multipliers reset.', -1)
        ac.debug("Speed reset triggered", player.speedKmh)
    end

    -- Process collisions and cars
    if collisionCooldown <= 0 then
        -- Wall collision check
        if player.collidedWith ~= -1 then
            handleCollision("wall")
            ac.debug("Player collidedWith (wall)", player.collidedWith)
        end

        for i = 2, sim.carsCount do
            local car = ac.getCarState(i)
            local state = carsState[i]
            local distance = car.position:distance(player.position)

            -- Debug collision data
            ac.debug("Car " .. i .. " collidedWith", car.collidedWith)
            ac.debug("Player collidedWith", player.collidedWith)
            ac.debug("Distance to car " .. i, distance)

            -- Car collision check
            if player.collidedWith == (i - 1) then
                state.collided = true
                handleCollision("car " .. i)
            end

            -- Near miss detection (within 1.5 meters)
            if not state.collided and distance < 1.5 then
                nearMissStreak = nearMissStreak + 1
                nearMissMultiplier = math.min(nearMissMultiplier + 1, maxComboMultiplier)
                nearMissCooldown = nearMissCooldownDuration
                ac.debug("Near miss detected", {streak = nearMissStreak, multiplier = nearMissMultiplier})
                if nearMissStreak == 1 then
                    addMessage('Near Miss', 2)
                else
                    addMessage('Near Miss x' .. nearMissStreak, 2)
                end
            end

            -- Overtake detection
            if not state.overtaken and not state.collided then
                local posDir = (car.position - player.position):normalize()
                local posDot = math.dot(posDir, car.look)
                state.maxPosDot = math.max(state.maxPosDot, posDot)
                if posDot < -0.5 and state.maxPosDot > 0.5 then
                    state.overtaken = true
                    local points = 10 * comboMeter * nearMissMultiplier
                    totalScore = totalScore + math.ceil(points)
                    comboMeter = math.min(comboMeter + 1, maxComboMultiplier)
                    comboColor = comboColor + 90
                    addMessage('Overtake! +' .. math.floor(points) .. ' points', 1)
                end
            end

            state.lastDistance = distance
        end
    end
end

-- Draw the UI
function script.drawUI()
    local uiState = ac.getUiState()
    updateMessages(uiState.dt)

    local speedRelative = math.saturate(math.floor(ac.getCarState(1).speedKmh) / requiredSpeed)
    local speedWarning = math.applyLag(0, speedRelative < 1 and 1 or 0, 0.5, uiState.dt)

    local colorDark = rgbm(0.4, 0.4, 0.4, 1)
    local colorGrey = rgbm(0.7, 0.7, 0.7, 1)
    local colorAccent = rgbm.new(hsv(speedRelative * 120, 1, 1):rgb(), 1)
    local colorCombo = rgbm.new(hsv(comboColor, math.saturate(comboMeter / 10), 1):rgb(), math.saturate(comboMeter / 4))
    local colorNearMiss = rgbm(0, 1, 0, 1) -- Green for near miss

    -- Movable transparent window
    ui.beginTransparentWindow('overtakeScore', uiPosition, vec2(600, 300), true) -- true enables dragging
    ui.beginOutline()

    -- Big grey box (left) for points
    ui.pushStyleVar(ui.StyleVar.Alpha, 1 - speedWarning)
    ui.pushFont(ui.Font.Huge)
    ui.setCursor(vec2(50, 50))
    ui.text(math.floor(totalScore) .. ' pts')
    ui.popFont()
    ui.popStyleVar()

    -- Top right box for multipliers
    ui.pushStyleVar(ui.StyleVar.Alpha, 1 - speedWarning)
    ui.pushFont(ui.Font.Title)
    ui.setCursor(vec2(400, 50))
    ui.textColored(math.ceil(comboMeter * 10) / 10 .. 'x', colorCombo)
    ui.sameLine(0, 20)
    ui.textColored(math.ceil(nearMissMultiplier * 10) / 10 .. 'x', colorNearMiss)
    ui.popFont()
    ui.popStyleVar()

    -- Bottom right box for collision count
    ui.pushStyleVar(ui.StyleVar.Alpha, 1 - speedWarning)
    ui.pushFont(ui.Font.Title)
    ui.setCursor(vec2(400, 200))
    ui.textColored(crashCount, rgbm(1, 0, 0, 1)) -- Raw collision count
    ui.popFont()
    ui.popStyleVar()

    -- Custom rendering for green near miss messages (under collision count)
    for i = 1, #messages do
        local m = messages[i]
        if m.mood == 2 then -- Green text for near miss
            ui.pushFont(ui.Font.Title)
            ui.setCursor(vec2(400, 230 + m.currentPos * 30)) -- Under collision count
            ui.textColored(m.text, rgbm(0, 1, 0, 1 - m.age / 2))
            ui.popFont()
        end
    end

    ui.endOutline(rgbm(0, 0, 0, 0.3))
    ui.endTransparentWindow()

    -- Update UI position if dragged
    if ui.windowHovered() and ui.isMouseLeftKeyDown() then
        local mousePos = ui.mousePos()
        local windowSize = vec2(600, 300)
        uiPosition = vec2(mousePos.x - windowSize.x / 2, mousePos.y - 20)
    end
end
