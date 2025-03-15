-- Assetto Corsa ode.lua script with reorganized UI based on PNG design

-- Event configuration:
local requiredSpeed = 55

-- Collision cooldown state
local collisionCooldown = 0
local collisionCooldownDuration = 2

-- Collision counter and score reset logic
local collisionCounter = 0
local maxCollisions = 10

-- Combo multiplier cap
local maxComboMultiplier = 5

-- Proximity Logic (formerly Near Miss)
local proximityStreak = 0
local proximityCooldown = 0
local proximityDistance = 3.0
local proximityMultiplier = 1.0
local proximityResetTime = 5 -- Changed from 3 to 5 seconds
local lastProximity = 0
local proximityColor = 0 -- For color cycling

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
local maxMessages = 5
local messageLifetime = 3.0

function addMessage(text, color)
  table.insert(messages, 1, { text = text, age = 0, color = color or rgbm(1, 1, 1, 1) })
  if #messages > maxMessages then
    table.remove(messages, #messages)
  end
end

local function updateMessages(dt)
  comboColor = comboColor + dt * 10 * comboMeter
  proximityColor = proximityColor + dt * 8 * proximityMultiplier -- Slightly slower color cycle than combo
  if comboColor > 360 then comboColor = comboColor - 360 end
  if proximityColor > 360 then proximityColor = proximityColor - 360 end
  for i = #messages, 1, -1 do
    messages[i].age = messages[i].age + dt
    if messages[i].age > messageLifetime then
      table.remove(messages, i)
    end
  end
end

function script.prepare(dt)
  return ac.getCar(0).speedKmh > 60
end

function script.update(dt)
  local player = ac.getCar(0)
  if not player or player.engineLifeLeft < 1 then
    if totalScore > highestScore then
      highestScore = math.floor(totalScore)
    end
    totalScore = 0
    comboMeter = 1
    proximityMultiplier = 1.0
    proximityStreak = 0
    collisionCounter = 0
    return
  end

  timePassed = timePassed + dt

  if collisionCooldown > 0 then
    collisionCooldown = collisionCooldown - dt
  end

  if proximityCooldown > 0 then
    proximityCooldown = proximityCooldown - dt
    if proximityCooldown <= 0 then
      proximityStreak = 0
      proximityMultiplier = 1.0
      addMessage('Proximity Multiplier Reset!')
    end
  end

  local comboFadingRate = 0.2 * math.lerp(1, 0.1, math.lerpInvSat(player.speedKmh, 80, 200)) + player.wheelsOutside
  comboMeter = math.max(1, comboMeter - dt * comboFadingRate)
  comboMeter = math.min(comboMeter, maxComboMultiplier)

  local sim = ac.getSim()
  while sim.carsCount > #carsState do
    carsState[#carsState + 1] = {}
  end

  if wheelsWarningTimeout > 0 then
    wheelsWarningTimeout = wheelsWarningTimeout - dt
  elseif player.wheelsOutside > 0 then
    addMessage('Car is outside')
    wheelsWarningTimeout = 60
  end

  if player.speedKmh < requiredSpeed then 
    if dangerouslySlowTimer > 15 then    
      if totalScore > highestScore then
        highestScore = math.floor(totalScore)
      end
      totalScore = 0
      comboMeter = 1
      proximityMultiplier = 1.0
      proximityStreak = 0
      collisionCounter = 0
    else
      if dangerouslySlowTimer == 0 then addMessage('Too slow!') end
      dangerouslySlowTimer = dangerouslySlowTimer + dt
      comboMeter = 1
      return
    end
  else 
    dangerouslySlowTimer = 0
  end

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
      proximityMultiplier = 1.0
      proximityStreak = 0
      addMessage('Collision: -1500', rgbm(1, 0, 0, 1))
      addMessage('Collisions: ' .. collisionCounter .. '/' .. maxCollisions, rgbm(1, 0, 0, 1))
      if collisionCounter >= maxCollisions then
        totalScore = 0
        collisionCounter = 0
        proximityMultiplier = 1.0
        proximityStreak = 0
        addMessage('Too many collisions! Score reset.', rgbm(1, 0, 0, 1))
      end
      collisionCooldown = collisionCooldownDuration
    end
  end

  for i = 1, sim.carsCount do 
    local car = ac.getCar(i)
    if car and car.index ~= player.index then
      local state = carsState[i] or {}
      carsState[i] = state

      local distance = car.pos:distance(player.pos)
      if distance <= proximityDistance and distance > 0.1 then
        local currentTime = os.time()
        if currentTime - lastProximity >= 1 then
          proximityStreak = proximityStreak + 1
          proximityMultiplier = math.min(proximityMultiplier + 0.5, 5.0)
          proximityCooldown = proximityResetTime
          lastProximity = currentTime
          local proximityPoints = math.ceil(50 * comboMeter * proximityMultiplier)
          totalScore = totalScore + proximityPoints
          comboMeter = comboMeter + (distance < 1.0 and 3 or 1)
          addMessage('Proximity! +' .. proximityPoints .. ' x' .. proximityStreak, rgbm(0.576, 0.439, 0.858, 1))
        end
      end

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
            totalScore = totalScore + math.ceil(50 * comboMeter * proximityMultiplier)
            comboMeter = comboMeter + 1
            comboColor = comboColor + 90
            state.overtaken = true
            addMessage('Overtake! +50', rgbm(0, 1, 0, 1))
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
  local colorProximity = rgbm.new(hsv(proximityColor, math.saturate(proximityMultiplier / 10), 1):rgb(), math.saturate(proximityMultiplier / 4))

  ui.beginTransparentWindow('overtakeScore', vec2(uiState.windowSize.x * 0.5 - 600, 100), vec2(400, 400))
  ui.beginOutline()

  -- Multipliers centered above PTS box
  ui.pushFont(ui.Font.Title)
  local windowWidth = 400
  local proximityWidth = ui.measureText('Proximity: ' .. string.format('%.1fx', proximityMultiplier))
  local comboWidth = ui.measureText('Combo: ' .. math.ceil(comboMeter * 10) / 10 .. 'x')
  local totalWidth = proximityWidth + comboWidth + 40 -- 40 is the sameLine spacing
  local startX = (windowWidth - totalWidth) / 2
  ui.setCursorX(startX)
  ui.textColored('Proximity: ' .. string.format('%.1fx', proximityMultiplier), colorProximity)
  ui.sameLine(0, 40)
  ui.textColored('Combo: ' .. math.ceil(comboMeter * 10) / 10 .. 'x', colorCombo)
  ui.popFont()

  -- PTS box (larger grey box)
  ui.offsetCursorY(40) -- Move down to align with PNG design
  ui.beginTransparentWindow('scoreBox', vec2(uiState.windowSize.x * 0.5 - 650, 150), vec2(200, 60))
  ui.drawRectFilled(vec2(0, 0), vec2(200, 60), rgbm(0.8, 0.8, 0.8, 1)) -- Grey background
  ui.pushFont(ui.Font.Huge)
  local textWidth = ui.measureText(totalScore .. ' PTS')
  ui.setCursorX((200 - textWidth) / 2) -- Center the text
  ui.textColored(totalScore .. ' PTS', rgbm(0, 0, 0, 1)) -- Black text
  ui.popFont()
  ui.endTransparentWindow()

  -- Personal Best to the right of PTS
  ui.beginTransparentWindow('pbBox', vec2(uiState.windowSize.x * 0.5 - 450, 150), vec2(100, 60))
  ui.drawRectFilled(vec2(0, 0), vec2(100, 60), rgbm(0.8, 0.8, 0.8, 1)) -- Grey background
  ui.pushFont(ui.Font.Title)
  local pbTextWidth = ui.measureText('Personal Best: ' .. highestScore)
  ui.setCursorX((100 - pbTextWidth) / 2) -- Center the text
  ui.pushStyleVar(ui.StyleVar.Alpha, 1 - speedWarning)
  ui.text('Personal Best: ' .. highestScore)
  ui.popStyleVar()
  ui.popFont()
  ui.endTransparentWindow()

  -- Collisions and messages together below
  ui.offsetCursorY(70) -- Move down to group with messages
  ui.pushFont(ui.Font.Title)
  ui.textColored('Collisions: ' .. collisionCounter .. '/' .. maxCollisions, rgbm(1, 0, 0, 1))
  ui.offsetCursorY(10)
  ui.pushStyleVar(ui.StyleVar.ItemSpacing, vec2(0, 10))
  for i, msg in ipairs(messages) do
    local alpha = 1.0 - (msg.age / messageLifetime)
    ui.pushStyleVar(ui.StyleVar.Alpha, alpha)
    ui.textColored(msg.text, msg.color)
    ui.popStyleVar()
    ui.offsetCursorY(30)
  end
  ui.popStyleVar()
  ui.popFont()

  ui.endOutline(rgbm(0, 0, 0, 0.3))
  ui.endTransparentWindow()
end
