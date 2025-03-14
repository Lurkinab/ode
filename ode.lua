-- Near miss state
local nearMissStreak = 0
local nearMissCooldown = 0
local nearMissCooldownDuration = 3 -- Cooldown duration in seconds

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
        if car.pos:closerToThan(player.pos, 4) then -- Changed from 5 to 4 (get even closer)
            local drivingAlong = math.dot(car.look, player.look) > 0.2
            if not drivingAlong then
                state.drivingAlong = false

                -- Increase proximity requirement for near misses
                if not state.nearMiss and car.pos:closerToThan(player.pos, 1.5) then -- Changed from 2 to 1.5
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

                    if car.pos:closerToThan(player.pos, 1) then -- Changed from 1.5 to 1
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
                totalScore = math.max(0, totalScore - 500) -- Reduced from -1000 to -500
                comboMeter = 1
                addMessage('Collision: -500 points', -1) -- Display collision feedback
                addMessage('Collisions: ' .. collisionCounter .. '/' .. maxCollisions, -1)

                -- Reset score if collision counter reaches maxCollisions
                if collisionCounter >= maxCollisions then
                    ac.sendChatMessage("Too many collisions! Score reset.")
                    totalScore = 0
                    collisionCounter = 0 -- Reset collision counter
                    addMessage('Too many collisions! Score reset.', -1)
                end

                -- Start cooldown
                collisionCooldown = collisionCooldownDuration
            end

            if not state.overtaken and not state.collided and state.drivingAlong then
                local posDir = (car.pos - player.pos):normalize()
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
