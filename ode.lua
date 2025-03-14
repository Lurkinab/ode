-- Event configuration:
local requiredSpeed = 55

-- Collision cooldown state
local collisionCooldown = 0 -- Cooldown timer
local collisionCooldownDuration = 2 -- Cooldown duration in seconds

-- Crash counter (formerly collision counter)
local crashCount = 0 -- Tracks the number of crashes (MackSauce)

-- Combo multiplier cap
local maxComboMultiplier = 10 -- Maximum combo multiplier (changed from 5 to 10)

-- Near Miss Logic
local nearMissStreak = 0 -- Track consecutive near misses
local nearMissCooldown = 0 -- Cooldown timer for streak reset
local nearMissDistance = 1.5 -- Constant distance for near miss (1.5 meters)

-- Track player's last position to detect teleport
local lastPlayerPos = nil -- Initialize as nil to handle first frame properly

-- Debug flag to help troubleshoot collision issues
local debugMode = true -- Set to true to see collision debug messages

-- This function is called before event activates. Once it returns true, it'll run:
function script.prepare(dt)
  return ac.getCarState(1).speedKmh > 60
end

-- Event state:
local timePassed = 0
local totalScore = 0
local comboMeter = 1
local comboColor = 0
local highestScore = 0
local dangerouslySlowTimer = 0
local carsState = {}
local wheelsWarningTimeout = 0

-- Function to add messages to the UI
local messages = {}
local glitter = {}
local glitterCount = 0

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

-- Function to update messages and glitter effects
local function updateMessages(dt)
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

-- Function to properly initialize car state
function initCarState()
  return {
    overtaken = false,
    collided = false,
    nearMiss = false,
    maxPosDot = 0
  }
end

-- Reset all car states
function resetCarStates()
  for i = 1, #carsState do
    carsState[i] = initCarState()
  end
end

-- Function to check for collisions
function checkCollision(player)
  local sim = ac.getSimState()
  local collisionDetected = false
  
  -- Check if player has collided with anything
  if player.collision then
    if debugMode then
      addMessage("Debug: General collision detected!", 0)
    end
    
    -- Now find which car we collided with
    for i = 2, sim.carsCount do
      local car = ac.getCarState(i)
      local state = carsState[i]
      
      -- First ensure the state exists
      if not state then
        carsState[i] = initCarState()
        state = carsState[i]
      end
      
      -- Check if close enough to be a possible collision
      if car.pos:closerToThan(player.pos, 5) then
        -- If not on cooldown and not already counted
        if collisionCooldown <= 0 and not state.collided then
          if debugMode then
            addMessage("Debug: Car " .. i .. " collision detected!", 0)
          end
          
          -- Update highest score if current score is higher
          if totalScore > highestScore then
            highestScore = math.floor(totalScore)
            ac.sendChatMessage("New highest score: " .. highestScore .. " points!")
          end
          
          -- Handle collision
          crashCount = crashCount + 1
          totalScore = math.max(0, totalScore - 500)
          comboMeter = 1
          state.collided = true
          
          addMessage('Collision: -500 points', -1)
          addMessage('MackSauce: ' .. crashCount, -1)
          
          -- Start cooldown
          collisionCooldown = collisionCooldownDuration
          collisionDetected = true
          break -- Only count one collision at a time
        end
      end
    end
  end
  
  return collisionDetected
end

function script.update(dt)
  local player = ac.getCarState(1)

  -- Initialize lastPlayerPos if it's the first frame
  if lastPlayerPos == nil then
    lastPlayerPos = player.position
    resetCarStates() -- Make sure car states are initialized
    return -- Skip the first frame to establish position
  end

  -- Detect teleport by checking for large position changes
  local currentPlayerPos = player.position
  if not lastPlayerPos:closerToThan(currentPlayerPos, 100) then
    -- Player teleported (position changed by more than 100 meters)
    totalScore = 0
    crashCount = 0
    comboMeter = 1
    addMessage('Teleport detected! Score and MackSauce reset.', -1)
    resetCarStates() -- Reset all car states when teleporting
  end
  lastPlayerPos = currentPlayerPos

  if player.engineLifeLeft < 1 then
    if totalScore > highestScore then
      highestScore = math.floor(totalScore)
      ac.sendChatMessage("New highest score: " .. highestScore .. " points!") 
    end
    totalScore = 0
    comboMeter = 1
    resetCarStates()
    return
  end

  timePassed = timePassed + dt

  -- Update collision cooldown
  if collisionCooldown > 0 then
    collisionCooldown = collisionCooldown - dt
  end

  -- Update combo meter fade rate (slower fade)
  local comboFadingRate = 0.05 -- Slower fade rate
  comboMeter = math.max(1, comboMeter - dt * comboFadingRate)

  -- Cap the combo multiplier at maxComboMultiplier
  comboMeter = math.min(comboMeter, maxComboMultiplier)

  -- Update near miss cooldown
  if nearMissCooldown > 0 then
    nearMissCooldown = nearMissCooldown - dt
    if nearMissCooldown <= 0 then
      -- Reset streak if cooldown expires
      nearMissStreak = 0
    end
  end

  local sim = ac.getSimState()
  while sim.carsCount > #carsState do
    carsState[#carsState + 1] = initCarState()
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
        ac.sendChatMessage("New highest score: " .. highestScore .. " points!") 
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

  -- Check for collisions first - this is the primary issue we're fixing
  local collisionHappened = checkCollision(player)
  
  -- Only process other cars for near misses and overtakes if no collision happened
  if not collisionHappened then
    -- Process other cars (AI cars)
    for i = 2, sim.carsCount do
      local car = ac.getCarState(i)
      local state = carsState[i]
      
      if not state then -- Ensure state exists
        carsState[i] = initCarState()
        state = carsState[i]
      end
  
      -- Only process near misses and overtakes if no collision with this car
      if not state.collided then
        -- Near miss logic
        if car.pos:closerToThan(player.pos, nearMissDistance) then
          if not state.nearMiss then
            state.nearMiss = true
  
            -- Reward for near miss
            local points = 100 * comboMeter
            totalScore = totalScore + points
            comboMeter = comboMeter + 0.5
  
            -- Update streak
            nearMissStreak = nearMissStreak + 1
  
            -- Display green text message for near miss
            addMessage('Near Miss! +' .. math.floor(points) .. ' points (Streak: ' .. nearMissStreak .. ')', 1)
  
            -- Reset near miss cooldown
            nearMissCooldown = 3
          end
        else
          -- Reset near miss state when cars are far apart
          state.nearMiss = false
        end
  
        -- Overtake logic - only if not collided
        if not state.overtaken then
          local posDir = (car.pos - player.pos):normalize()
          local posDot = math.dot(posDir, car.look)
          state.maxPosDot = math.max(state.maxPosDot, posDot)
          if posDot < -0.5 and state.maxPosDot > 0.5 then
            -- Reward for overtake
            local points = 100 * comboMeter
            totalScore = totalScore + points
            comboMeter = comboMeter + 1
            state.overtaken = true
            addMessage('Overtake! +' .. math.floor(points) .. ' points', 1)
          end
        end
      end
    end
  end
end

local speedWarning = 0
function script.drawUI()
  local uiState = ac.getUiState()
  updateMessages(uiState.dt)

  local speedRelative = math.saturate(math.floor(ac.getCarState(1).speedKmh) / requiredSpeed)
  speedWarning = math.applyLag(speedWarning, speedRelative < 1 and 1 or 0, 0.5, uiState.dt)

  local colorDark = rgbm(0.4, 0.4, 0.4, 1)
  local colorGrey = rgbm(0.7, 0.7, 0.7, 1)
  local colorAccent = rgbm.new(hsv(speedRelative * 120, 1, 1):rgb(), 1)
  local colorCombo = rgbm.new(hsv(comboColor, math.saturate(comboMeter / 10), 1):rgb(), math.saturate(comboMeter / 4))

  -- Draw the score and crash counter
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
  if comboMeter > 20 then
    ui.endRotation(math.sin(comboMeter / 180 * 3141.5) * 3 * math.lerpInvSat(comboMeter, 20, 30) + 90)
  else
    ui.endRotation(0)
  end
  ui.popFont()

  -- Draw crash counter (bigger text)
  ui.offsetCursorY(20)
  ui.pushFont(ui.Font.Title)
  ui.textColored('MackSauce: ' .. crashCount, rgbm(1, 0, 0, 1))
  ui.popFont()

  ui.endOutline(rgbm(0, 0, 0, 0.3))
  ui.endTransparentWindow()
end
