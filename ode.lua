-- Assetto Corsa ode.lua script with enhanced UI and drawn background

-- Event configuration:
local requiredSpeed = 55

-- Collision cooldown state
local collisionCooldown = 0 -- Cooldown timer
local collisionCooldownDuration = 2 -- Cooldown duration in seconds

-- Collision counter and score reset logic
local collisionCounter = 0 -- Tracks the number of collisions
local maxCollisions = 10 -- Maximum allowed collisions before score reset

-- Combo multiplier cap
local maxComboMultiplier = 5 -- Maximum combo multiplier

-- Near Miss Logic
local nearMissStreak = 0 -- Track consecutive near misses
local nearMissCooldown = 0 -- Cooldown timer for streak reset
local nearMissDistance = 3.0 -- Proximity threshold for near miss
local nearMissMultiplier = 1.0 -- Separate near miss multiplier
local nearMissResetTime = 3 -- 3 seconds to reset near miss multiplier
local lastNearMiss = 0 -- Timestamp for debouncing near miss events

-- Event state:
local timePassed = 0
local totalScore = 0
local comboMeter = 1
local comboColor = 0
local highestScore = 0
local dangerouslySlowTimer = 0
local carsState = {}
local wheelsWarningTimeout = 0

-- Message system for UI
local messages = {}
local maxMessages = 5 -- Maximum number of messages to display
local messageLifetime = 3.0 -- Duration messages stay on screen (seconds)

-- Modified addMessage to accept a color
function addMessage(text, color)
  table.insert(messages, 1, { text = text, age = 0, color = color })
  if #messages > maxMessages then
    table.remove(messages, #messages)
  end
end

-- Function to update messages
local function updateMessages(dt)
  comboColor = comboColor + dt * 10 * comboMeter
  if comboColor > 360 then comboColor = comboColor - 360 end
  for i = #messages, 1, -1 do
    messages[i].age = messages[i].age + dt
    if messages[i].age > messageLifetime then
      table.remove(messages, i)
    end
  end
end

-- This function is called before event activates. Once it returns true, it’ll run:
function script.prepare(dt)
  return ac.getCar(0).speedKmh > 60
end

function script.update(dt)
  local player = ac.getCar(0) -- Use ac.getCar(0) for player
  if not player or player.engineLifeLeft < 1 then
    if totalScore > highestScore then
      highestScore = math.floor(totalScore)
    end
    totalScore = 0
    comboMeter = 1
    nearMissMultiplier = 1.0
    nearMissStreak = 0
    collisionCounter = 0
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
    if nearMissCooldown <= 0 then
      nearMissStreak = 0
      nearMissMultiplier = 1.0
      addMessage('Near Miss Multiplier Reset!', rgbm(1, 1, 1, 1)) -- White for reset message
    end
  end

  -- Update combo meter fade rate
  local comboFadingRate = 0.2 * math.lerp(1, 0.1, math.lerpInvSat(player.speedKmh, 80, 200)) + player.wheelsOutside
  comboMeter = math.max(1, comboMeter - dt * comboFadingRate)

  -- Cap the combo multiplier
  comboMeter = math.min(comboMeter, maxComboMultiplier)

  local sim = ac.getSim()
  while sim.carsCount > #carsState do
    carsState[#carsState + 1] = {}
  end

  if wheelsWarningTimeout > 0 then
    wheelsWarningTimeout = wheelsWarningTimeout - dt
  elseif player.wheelsOutside > 0 then
    addMessage('Car is outside', rgbm(1, 1, 1, 1)) -- White for outside message
    wheelsWarningTimeout = 60
  end

  if player.speedKmh < requiredSpeed then 
    if dangerouslySlowTimer > 15 then    
      if totalScore > highestScore then
        highestScore = math.floor(totalScore)
      end
      totalScore = 0
      comboMeter = 1
      nearMissMultiplier = 1.0
      nearMissStreak = 0
      collisionCounter = 0
    else
      if dangerouslySlowTimer == 0 then addMessage('Too slow!', rgbm(1, 1, 1, 1)) end -- White for too slow message
      dangerouslySlowTimer = dangerouslySlowTimer + dt
      comboMeter = 1
      return
    end
  else 
    dangerouslySlowTimer = 0
  end

  -- Collision detection
  local simState = ac.getSimState()
  for i = 1, simState.carsCount do 
    local car = ac.getCarState(i)
    if car.collidedWith == 0 and collisionCooldown <= 0 then
      if totalScore > highestScore then
        highestScore = math.floor(totalScore)
      end
      collisionCounter = collisionCounter + 1
      totalScore = math.max(0, totalScore - 1500)
      comboMeter = 1
      nearMissMultiplier = 1.0
      nearMissStreak = 0
      addMessage('Collision: -1500', rgbm(1, 0, 0, 1)) -- Red for collision
      addMessage('Collisions: ' .. collisionCounter .. '/' .. maxCollisions, rgbm(1, 0, 0, 1)) -- Red for collision counter
      if collisionCounter >= maxCollisions then
        totalScore = 0
        collisionCounter = 0
        nearMissMultiplier = 1.0
        nearMissStreak = 0
        addMessage('Too many collisions! Score reset.', rgbm(1, 0, 0, 1)) -- Red for reset message
      end
      collisionCooldown = collisionCooldownDuration
    end
  end

  -- Near miss and overtake logic
  for i = 1, sim.carsCount do 
    local car = ac.getCar(i)
    if car and car.index ~= player.index then -- Skip player car
      local state = carsState[i] or {}
      carsState[i] = state

      -- Near miss logic with proximity check
      local distance = car.pos:distance(player.pos)
      if distance <= nearMissDistance and distance > 0.1 then -- Ensure not too close (avoid collision overlap)
        local currentTime = os.time()
        if currentTime - lastNearMiss >= 1 then -- Debounce to avoid rapid triggers
          nearMissStreak = nearMissStreak + 1
          nearMissMultiplier = math.min(nearMissMultiplier + 0.5, 5.0)
          nearMissCooldown = nearMissResetTime
          lastNearMiss = currentTime
          local nearMissPoints = math.ceil(50 * comboMeter * nearMissMultiplier)
          totalScore = totalScore + nearMissPoints
          comboMeter = comboMeter + (distance < 1.0 and 3 or 1) -- Bonus for very close
          addMessage('Near Miss! +' .. nearMissPoints .. ' x' .. nearMissStreak, rgbm(1, 1, 0, 1)) -- Yellow for near miss
        end
      end

      -- Overtake logic
      if car.pos:closerToThan(player.pos, 4) then
        local drivingAlong = math.dot(car.look, player.look) > 0.2
        if not drivingAlong then
          state.drivingAlong = false
        end
        if not state.overtaken and not state.collided and state.drivingAlong then
          local posDir = (car.pos - player.pos):normalize()
          local posDot = math.dot(posDir, car.look)
          state.maxPosDot = math.max(state.maxPosDot or -1, posDot)
          if posDot < -0.5 and state.maxPosDot > 0.5 then
            totalScore = totalScore + math.ceil(50 * comboMeter * nearMissMultiplier)
            comboMeter = comboMeter + 1
            comboColor = comboColor + 90
            state.overtaken = true
            addMessage('Overtake! +50', rgbm(0, 1, 0, 1)) -- Green for overtake
          end
        end
      else
        state.maxPosDot = -1
        state.overtaken = false
        state.collided = false
        state.drivingAlong = true
      end
    end
  end
end

local speedWarning = 0
function script.drawUI()
  local uiState = ac.getUiState()
  updateMessages(uiState.dt)

  local speedRelative = math.saturate(math.floor(ac.getCar(0).speedKmh) / requiredSpeed)
  speedWarning = math.applyLag(speedWarning, speedRelative < 1 and 1 or 0, 0.5, uiState.dt)

  local colorDark = rgbm(0.4, 0.4, 0.4, 1)
  local colorGrey = rgbm(0.7, 0.7, 0.7, 1)
  local colorAccent = rgbm.new(hsv(speedRelative * 120, 1, 1):rgb(), 1)
  local colorCombo = rgbm.new(hsv(comboColor, math.saturate(comboMeter / 10), 1):rgb(), math.saturate(comboMeter / 4))

  -- Define UI window size and position
  local windowPos = vec2(uiState.windowSize.x * 0.5 - 600, 100)
  local windowSize = vec2(400, 400)

  -- Draw the background using primitives
  -- Bottom parallelogram (light gray, #a0a0a0)
  local bottomColor = rgbm(0.627, 0.627, 0.627, 1) -- #a0a0a0
  local bottomHeight = windowSize.y * 0.3
  local bottomSkew = windowSize.x * 0.2
  ui.drawTriangleFilled(
    windowPos + vec2(0, windowSize.y - bottomHeight), -- Bottom-left
    windowPos + vec2(windowSize.x, windowSize.y - bottomHeight), -- Bottom-right
    windowPos + vec2(bottomSkew, windowSize.y), -- Bottom-left skewed
    bottomColor
  )
  ui.drawTriangleFilled(
    windowPos + vec2(windowSize.x, windowSize.y - bottomHeight), -- Bottom-right
    windowPos + vec2(windowSize.x - bottomSkew, windowSize.y), -- Bottom-right skewed
    windowPos + vec2(bottomSkew, windowSize.y), -- Bottom-left skewed
    bottomColor
  )

  -- Middle parallelogram (medium gray, #979797)
  local middleColor = rgbm(0.592, 0.592, 0.592, 1) -- #979797
  local middleHeight = windowSize.y * 0.2
  local middleOffsetY = windowSize.y * 0.35
  ui.drawTriangleFilled(
    windowPos + vec2(windowSize.x * 0.2, windowSize.y - middleOffsetY - middleHeight), -- Top-left
    windowPos + vec2(windowSize.x, windowSize.y - middleOffsetY - middleHeight), -- Top-right
    windowPos + vec2(windowSize.x * 0.2 + bottomSkew, windowSize.y - middleOffsetY), -- Bottom-left skewed
    middleColor
  )
  ui.drawTriangleFilled(
    windowPos + vec2(windowSize.x, windowSize.y - middleOffsetY - middleHeight), -- Top-right
    windowPos + vec2(windowSize.x - bottomSkew, windowSize.y - middleOffsetY), -- Bottom-right skewed
    windowPos + vec2(windowSize.x * 0.2 + bottomSkew, windowSize.y - middleOffsetY), -- Bottom-left skewed
    middleColor
  )

  -- Top parallelogram (dark gray, #070707)
  local topColor = rgbm(0.027, 0.027, 0.027, 1) -- #070707
  local topHeight = windowSize.y * 0.15
  local topOffsetY = windowSize.y * 0.55
  ui.drawTriangleFilled(
    windowPos + vec2(windowSize.x * 0.4, windowSize.y - topOffsetY - topHeight), -- Top-left
    windowPos + vec2(windowSize.x, windowSize.y - topOffsetY - topHeight), -- Top-right
    windowPos + vec2(windowSize.x * 0.4 + bottomSkew, windowSize.y - topOffsetY), -- Bottom-left skewed
    topColor
  )
  ui.drawTriangleFilled(
    windowPos + vec2(windowSize.x, windowSize.y - topOffsetY - topHeight), -- Top-right
    windowPos + vec2(windowSize.x - bottomSkew, windowSize.y - topOffsetY), -- Bottom-right skewed
    windowPos + vec2(windowSize.x * 0.4 + bottomSkew, windowSize.y - topOffsetY), -- Bottom-left skewed
    topColor
  )

  -- Add a semi-transparent overlay to improve text readability
  ui.drawRectFilled(windowPos, windowPos + windowSize, rgbm(0, 0, 0, 0.5))

  -- Begin the transparent window
  ui.beginTransparentWindow('overtakeScore', windowPos, windowSize)
  ui.beginOutline()

  -- Highest Score
  ui.pushStyleVar(ui.StyleVar.Alpha, 1 - speedWarning)
  ui.pushFont(ui.Font.Title)
  ui.text('Highest Score: ' .. highestScore)
  ui.popFont()
  ui.popStyleVar()

  -- Total Score
  ui.pushFont(ui.Font.Huge)
  ui.text(totalScore .. ' pts')
  ui.popFont()

  -- Combo and Near Miss Multipliers (side by side)
  ui.offsetCursorY(10)
  ui.pushFont(ui.Font.Title)
  ui.beginGroup()
  ui.textColored('Combo: ' .. string.format('%.1fx', comboMeter), colorCombo)
  ui.sameLine(0, 40)
  ui.text('Near Miss: ' .. string.format('%.1fx', nearMissMultiplier))
  ui.endGroup()
  ui.popFont()

  -- Collisions
  ui.offsetCursorY(10)
  ui.pushFont(ui.Font.Title)
  ui.textColored('Collisions: ' .. collisionCounter .. '/' .. maxCollisions, rgbm(1, 0, 0, 1))
  ui.popFont()

  -- Draw temporary messages
  ui.offsetCursorY(20)
  for i, msg in ipairs(messages) do
    local alpha = 1.0 - (msg.age / messageLifetime)
    ui.pushStyleVar(ui.StyleVar.Alpha, alpha)
    ui.textColored(msg.text, msg.color)
    ui.popStyleVar()
    ui.offsetCursorY(20)
  end

  ui.endOutline(rgbm(0, 0, 0, 0.3))
  ui.endTransparentWindow()
end
