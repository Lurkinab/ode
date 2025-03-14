-- Event configuration
local requiredSpeed = 55
local collisionPenalty = 500 -- Points deducted per collision
local resetScoreOnCollision = false -- Set to true to reset score to 0 on collision

-- Collision tracking
local collisionCooldown = 0
local collisionCooldownDuration = 2 -- seconds
local crashCount = 0 -- MackSauce counter (tracks collisions, resets on teleport)

-- Scoring system
local totalScore = 0
local comboMeter = 1 -- Overtake multiplier
local nearMissMultiplier = 1 -- Separate near miss multiplier
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

-- Teleport detection
local lastPlayerPos = nil
local teleportThreshold = 100 -- meters

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
        nearMissTriggered = false, -- Tracks if near miss was counted this frame
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
    nearMissMultiplier = 1 -- Reset near miss multiplier on collision

    addMessage('Collision: -' .. collisionPenalty .. ' points', -1)
    addMessage('MackSauce: ' .. crashCount, -1)
    addMessage('Collision detected (' .. source .. ')', -1)
end

-- Update function
function script.update(dt)
    local player = ac.getCarState(1)

    -- Skip first frame
    if lastPlayerPos == nil then
        lastPlayerPos = player.position
        return
    end

    -- Handle engine failure
    if player.engineLifeLeft < 1 then
        if totalScore > highestScore then
            highestScore = math.floor(totalScore)
            ac.sendChatMessage("New highest score: " .. highestScore .. " points!")
        end
        totalScore = 0
        comboMeter = 1
        nearMissMultiplier = 1
        crashCount = 0
        resetAllCarStates()
        return
    end

    timePassed = timePassed + dt

    -- Update cooldowns
    if collisionCooldown > 0 then collisionCooldown = collisionCooldown - dt end
    if nearMissCooldown > 0 then
        nearMissCooldown = nearMissCooldown - dt
        if nearMissCooldown <= 0 then
            nearMissStreak = 0
            nearMissMultiplier = 1
        end
    end

    -- Combo meter fade (only affects overtake combo)
    local comboFadingRate = 0.2 * math.lerp(1, 0.1, math.lerpInvSat(player.speedKmh, 80, 200)) + player.wheelsOutside
    comboMeter = math.max(1, comboMeter - dt * comboFadingRate)
    comboMeter = math.min(comboMeter, maxComboMultiplier)
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

    -- Speed check
    if player.speedKmh < requiredSpeed then
        if dangerouslySlowTimer > 15 then
            if totalScore > highestScore then
                highestScore = math.floor(totalScore)
                ac.sendChatMessage("New highest score: " .. highestScore .. " points!")
            end
            totalScore = 0
            comboMeter = 1
            nearMissMultiplier = 1
            crashCount = 0
        else
            if dangerouslySlowTimer == 0 then addMessage('Too slow!', -1) end
        end
        dangerouslySlowTimer = dangerouslySlowTimer + dt
        comboMeter = 1
        nearMissMultiplier = 1
        return
    else
        dangerouslySlowTimer = 0
    end

    -- Teleport detection
    local posChange = lastPlayerPos:distance(player.position)
    if posChange > teleportThreshold then
        totalScore = 0
        crashCount = 0
        comboMeter = 1
        nearMissMultiplier = 1
        nearMissStreak = 0
        resetAllCarStates()
        addMessage('Teleport detected! Score and MackSauce reset.', -1)
        ac.debug("Teleport triggered", posChange)
    end

    -- Process collisions and cars
    if collisionCooldown <= 0 then
        -- Wall collision check
        if player.collidedWith ~= -1 then
            handleCollision("wall")
            ac.debug("Player collidedWith (wall)", player.collidedWith)
        end
    end

    local nearMissThisFrame = 0
    for i = 2, sim.carsCount do
        local car = ac.getCarState(i)
        local state = carsState[i]
        local distance = car.position:distance(player.position)

        -- Debug collision data
        ac.debug("Car " .. i .. " collidedWith", car.collidedWith)
        ac.debug("Distance to car " .. i, distance)

        -- Car collision check
        if collisionCooldown <= 0 and car.collidedWith == 0 then
            state.collided = true
            handleCollision("car " .. i)
        end

        -- Near miss detection (within 1 meter)
        if not state.collided and distance < 1 and not state.nearMissTriggered then
            nearMissThisFrame = nearMissThisFrame + 1
            state.nearMissTriggered = true -- Prevent double-counting this frame
            nearMissStreak = nearMissStreak + 1
            nearMissCooldown = nearMissCooldownDuration
            nearMissMultiplier = nearMissMultiplier + 1 -- Increase multiplier
        elseif distance >= 1 then
            state.nearMissTriggered = false -- Reset for next frame
        end

        -- Overtake detection
        if not state.overtaken and not state.collided then
            local posDir = (car.position - player.position):normalize()
            local posDot = math.dot(posDir, car.look)
            state.maxPosDot = math.max(state.maxPosDot, posDot)
            if posDot < -0.5 and state.maxPosDot > 0.5 then
                state.overtaken = true
                local points = 10 * comboMeter * nearMissMultiplier -- Combine multipliers
                totalScore = totalScore + math.ceil(points)
                comboMeter = comboMeter + 1
                comboColor = comboColor + 90
                addMessage('Overtake! +' .. math.floor(points) .. ' points', 1)
            end
        end

        state.lastDistance = distance
    end

    -- Display near miss message if any occurred this frame
    if nearMissThisFrame > 0 then
        if nearMissStreak > 1 then
            addMessage('Near Miss x' .. nearMissStreak, 2) -- Green text (mood 2)
        else
            addMessage('Near Miss', 2)
        end
    end

    lastPlayerPos = player.position
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

    ui.beginTransparentWindow('overtakeScore', vec2(uiState.windowSize.x * 0.5 - 600, 100), vec2(400, 400))
    ui.beginOutline()

    ui.pushStyleVar(ui.StyleVar.Alpha, 1 - speedWarning)
    ui.pushFont(ui.Font.Title)
    ui.text('Highest Score: ' .. highestScore)
    ui.popFont()
    ui.popStyleVar()

    ui.pushFont(ui.Font.Huge)
    ui.text(math.floor(totalScore) .. ' pts')
    ui.sameLine(0, 40)
    ui.beginRotation()
    ui.textColored(math.ceil(comboMeter * 10) / 10 .. 'x', colorCombo)
    ui.sameLine(0, 40) -- Position near miss multiplier next to combo
    ui.textColored(math.ceil(nearMissMultiplier * 10) / 10 .. 'x', colorNearMiss)
    if comboMeter > 20 then
        ui.endRotation(math.sin(comboMeter / 180 * 3141.5) * 3 * math.lerpInvSat(comboMeter, 20, 30) + 90)
    else
        ui.endRotation(0)
    end
    ui.popFont()

    ui.offsetCursorY(20)
    ui.pushFont(ui.Font.Title)
    ui.textColored('MackSauce: ' .. crashCount, rgbm(1, 0, 0, 1))
    ui.popFont()

    -- Custom rendering for green near miss messages
    for i = 1, #messages do
        local m = messages[i]
        if m.mood == 2 then -- Green text for near miss
            ui.pushFont(ui.Font.Title)
            ui.setCursor(vec2(80, 100 + m.currentPos * 30))
            ui.textColored(m.text, rgbm(0, 1, 0, 1 - m.age / 2))
            ui.popFont()
        end
    end

    ui.endOutline(rgbm(0, 0, 0, 0.3))
    ui.endTransparentWindow()
end
