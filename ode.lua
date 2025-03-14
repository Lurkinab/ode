-- Event configuration
local requiredSpeed = 55
local collisionPenalty = 500 -- Points deducted per collision
local maxCollisions = 5 -- Maximum collisions before reset

-- Collision tracking
local collisionCooldown = 0
local collisionCooldownDuration = 2 -- seconds
local collisionCounter = 0 -- Tracks collisions

-- Scoring system
local totalScore = 0
local comboMeter = 1 -- Combo multiplier
local highestScore = 0
local maxComboMultiplier = 10 -- Cap for combo multiplier

-- Timer states
local timePassed = 0
local dangerouslySlowTimer = 0
local wheelsWarningTimeout = 0
local comboColor = 0

-- Near miss state
local nearMissStreak = 0
local nearMissCooldown = 0
local nearMissCooldownDuration = 3 -- Cooldown duration in seconds

-- UI position (movable)
local uiPosition = vec2(300, 100) -- Initial position (center of screen adjusted)

-- Car states tracking
local carsState = {}

-- UI elements
local messages = {}
local glitter = {}
local glitterCount = 0

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
end

-- Update function
function script.update(dt)
    local player = ac.getCarState(1)
    if player.engineLifeLeft < 1 then
        if totalScore > highestScore then
            highestScore = math.floor(totalScore)
            ac.sendChatMessage("New highest score: " .. highestScore .. " points!") -- Broadcast to all players
        end
        totalScore = 0
        comboMeter = 1
        return
    end

    timePassed = timePassed + dt

    -- Update collision cooldown
    if collisionCooldown > 0 then
        collisionCooldown = collisionCooldown - dt
    end

    -- Update near miss cooldown
    if nearMissCooldown > 0 then
        nearMissCooldown = nearMissCooldown - dt
    elseif nearMissStreak > 0 then
        nearMissStreak = 0 -- Reset streak if cooldown expires
    end

    -- Make combo meter fade slower
    local comboFadingRate = 0.2 * math.lerp(1, 0.1, math.lerpInvSat(player.speedKmh, 80, 200)) + player.wheelsOutside
    comboMeter = math.max(1, comboMeter - dt * comboFadingRate)

    -- Cap the combo multiplier at maxComboMultiplier
    comboMeter = math.min(comboMeter, maxComboMultiplier)

    local sim = ac.getSimState()
    while sim.carsCount > #carsState do
        carsState[#carsState + 1] = {}
    end

    if wheelsWarningTimeout > 0 then
        wheelsWarningTimeout = wheelsWarningTimeout - dt
    elseif player.wheelsOutside > 0 then
        addMessage('Car is outside', -1)
        wheelsWarningTimeout = 60
    end

    if player.speedKmh < requiredSpeed then 
        if dangerouslySlowTimer > 15 then    
            if totalScore > highestScore then
                highestScore = math.floor(totalScore)
                ac.sendChatMessage("New highest score: " .. highestScore .. " points!") -- Broadcast to all players
            end
            totalScore = 0
            comboMeter = 1
        else
            if dangerouslySlowTimer == 0 then addMessage('Too slow!', -1) end
        end
        dangerouslySlowTimer = dangerouslySlowTimer + dt
        comboMeter = 1
        return
    else 
        dangerouslySlowTimer = 0
    end

    for i = 1, ac.getSimState().carsCount do 
        local car = ac.getCarState(i)
        local state = carsState[i]

        -- Increase proximity requirement for near misses and overtakes
        if car.position:distance(player.position) < 4 then -- Changed to distance function for consistency
            local drivingAlong = math.dot(car.look, player.look) > 0.2
            if not drivingAlong then
                state.drivingAlong = false

                -- Increase proximity requirement for near misses
                if not state.nearMiss and car.position:distance(player.position) < 1.5 then
                    state.nearMiss = true

                    -- Increment near miss streak and reset cooldown
                    nearMissStreak = nearMissStreak + 1
                    nearMissCooldown = nearMissCooldownDuration

                    -- Display near miss message
                    if nearMissStreak > 1 then
                        addMessage('Near Miss x' .. nearMissStreak .. '!', 1) -- Green text for near miss
                    else
                        addMessage('Near Miss!', 1) -- Green text for near miss
                    end

                    if car.position:distance(player.position) < 1 then
                        comboMeter = comboMeter + 3
                    else
                        comboMeter = comboMeter + 1
                    end
                end
            end

            if car.collidedWith == 0 and collisionCooldown <= 0 then
                -- Update highest score if current score is higher (before deducting points)
                if totalScore > highestScore then
                    highestScore = math.floor(totalScore)
                    ac.sendChatMessage("New highest score: " .. highestScore .. " points!") -- Broadcast to all players
                end

                -- Handle collision
                collisionCounter = collisionCounter + 1
                totalScore = math.max(0, totalScore - 500)
                comboMeter = 1
                addMessage('Collision: -500 points', -1)
                addMessage('Collisions: ' .. collisionCounter .. '/' .. maxCollisions, -1)

                -- Reset score if collision counter reaches maxCollisions
                if collisionCounter >= maxCollisions then
                    ac.sendChatMessage("Too many collisions! Score reset.")
                    totalScore = 0
                    collisionCounter = 0
                    addMessage('Too many collisions! Score reset.', -1)
                end

                -- Start cooldown
                collisionCooldown = collisionCooldownDuration
            end

            if not state.overtaken and not state.collided and state.drivingAlong then
                local posDir = (car.position - player.position):normalize()
                local posDot = math.dot(posDir, car.look)
                state.maxPosDot = math.max(state.maxPosDot, posDot)
                if posDot < -0.5 and state.maxPosDot > 0.5 then
                    totalScore = totalScore + math.ceil(10 * comboMeter)
                    comboMeter = comboMeter + 1
                    comboColor = comboColor + 90
                    state.overtaken = true
                end
            end

        else
            state.maxPosDot = -1
            state.overtaken = false
            state.collided = false
            state.drivingAlong = true
            state.nearMiss = false
        end
    end
end

-- Draw the UI
function script.drawUI()
    local uiState = ac.getUiState()
    updateMessages(uiState.dt)

    local speedRelative = math.saturate(math.floor(ac.getCarState(1).speedKmh) / requiredSpeed)
    local speedWarning = math.applyLag(0, speedRelative < 1 and 1 or 0, 0.5, uiState.dt)

    local colorGrey = rgbm(0.7, 0.7, 0.7, 1)
    local colorBlack = rgbm(0, 0, 0, 1)
    local colorCombo = rgbm.new(hsv(comboColor, math.saturate(comboMeter / 10), 1):rgb(), math.saturate(comboMeter / 4))
    local colorNearMiss = rgbm(0, 1, 0, 1) -- Green for near miss
    local colorRed = rgbm(1, 0, 0, 1)

    -- Movable transparent window
    ui.beginTransparentWindow('overtakeScore', uiPosition, vec2(600, 300), true) -- true enables dragging
    ui.beginOutline()

    -- Large grey box (left) for points
    ui.pushStyleVar(ui.StyleVar.Alpha, 1 - speedWarning)
    ui.pushFont(ui.Font.Huge)
    ui.setCursor(vec2(50, 100))
    ui.text(math.floor(totalScore) .. ' PTS')
    ui.popFont()
    ui.popStyleVar()

    -- Top right section for multipliers
    ui.pushStyleVar(ui.StyleVar.Alpha, 1 - speedWarning)
    ui.pushFont(ui.Font.Title)
    ui.setCursor(vec2(400, 50))
    ui.text('1.0x') -- Placeholder for Speed (not implemented)
    ui.sameLine(0, 20)
    ui.text('1.0x') -- Placeholder for Proximity (maps to nearMissStreak)
    ui.sameLine(0, 20)
    ui.text('1.0x') -- Maps to comboMeter
    ui.sameLine(0, 20)
    ui.textColored(math.ceil(comboMeter * 10) / 10 .. 'x', colorCombo) -- Diagonal black box effect
    ui.popFont()
    ui.popStyleVar()

    -- Small black box (right) for collision count
    ui.pushStyleVar(ui.StyleVar.Alpha, 1 - speedWarning)
    ui.pushFont(ui.Font.Title)
    ui.setCursor(vec2(450, 150))
    ui.beginOutline(colorBlack) -- Black outline to mimic PNG
    ui.textColored(collisionCounter .. '/' .. maxCollisions, colorRed)
    ui.endOutline()
    ui.popFont()
    ui.popStyleVar()

    -- Custom rendering for green near miss messages (under collision count)
    for i = 1, #messages do
        local m = messages[i]
        if m.mood == 1 then -- Green text for near miss
            ui.pushFont(ui.Font.Title)
            ui.setCursor(vec2(400, 200 + m.currentPos * 30)) -- Under collision count
            ui.textColored(m.text, colorNearMiss:lerp(rgbm(0, 0, 0, 1), m.age / 2))
            ui.popFont()
        end
    end

    ui.endOutline(rgbm(0, 0, 0, 0.3))
    ui.endTransparentWindow()

    -- Update UI position if dragged
    if ui.windowHovered() and ui.isMouseLeftKeyDown() then
        local mousePos = ui.mousePos()
        local windowSize = vec2(600, 300)
        uiPosition = vec2(mousePos.x - windowSize.x / 2, mousePos.y - 20) -- Center under mouse
    end
end
