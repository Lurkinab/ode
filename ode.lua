-- Event configuration:
local requiredSpeed = 80

-- Collision cooldown state
local collisionCooldown = 0 -- Cooldown timer
local collisionCooldownDuration = 2 -- Cooldown duration in seconds

-- Combo multiplier cap
local maxComboMultiplier = 10 -- Maximum combo multiplier

-- Collision counter and score reset logic
local collisionCounter = 0 -- Tracks the number of collisions
local maxCollisions = 5 -- Maximum allowed collisions before score reset

-- Leaderboard state
local leaderboard = {} -- Stores scores for all players

-- This function is called before event activates. Once it returns true, it’ll run:
function script.prepare(dt)
  ac.debug('speed', ac.getCarState(1).speedKmh)
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
local playerPreCollisionSpeed = 0 -- Track player's speed before collision

-- Function to handle collisions
local function handleCollision(player, otherCar)
  if collisionCooldown > 0 then return end -- Skip if cooldown is active

  -- Deduct 1000 points per collision
  totalScore = math.max(0, totalScore - 1000)
  comboMeter = 1
  collisionCounter = collisionCounter + 1

  -- Update highest score if current score is higher
  if totalScore > highestScore then
    highestScore = math.floor(totalScore)
    ac.sendChatMessage("New highest score: " .. highestScore .. " points!")
  end

  -- Reset score if collision counter reaches maxCollisions
  if collisionCounter >= maxCollisions then
    ac.sendChatMessage("Too many collisions! Score reset.")
    totalScore = 0
    collisionCounter = 0 -- Reset collision counter
    addMessage('Too many collisions! Score reset.', -1)
  else
    addMessage('Collision: Lost 1000 points. Collisions: ' .. collisionCounter .. '/' .. maxCollisions, -1)
  end

  -- Start cooldown
  collisionCooldown = collisionCooldownDuration
end

-- Function to update leaderboard
local function updateLeaderboard()
  local sim = ac.getSimState()
  for i = 1, sim.carsCount do
    local car = ac.getCarState(i)
    if not leaderboard[i] then
      leaderboard[i] = { name = car.driverName, score = 0 }
    end
    -- Update the player's own score
    if i == 1 then
      leaderboard[i].score = totalScore
    end
  end
end

function script.update(dt)
  if timePassed == 0 then
    addMessage('Let’s go!', 0)
  end

  local player = ac.getCarState(1)
  if player.engineLifeLeft < 1 then
    if totalScore > highestScore then
      highestScore = math.floor(totalScore)
      ac.sendChatMessage("Scored " .. totalScore .. " points.")
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

  -- Cap the combo multiplier at maxComboMultiplier
  comboMeter = math.min(comboMeter, maxComboMultiplier)

  local comboFadingRate = 0.5 * math.lerp(1, 0.1, math.lerpInvSat(player.speedKmh, 80, 200)) + player.wheelsOutside
  comboMeter = math.max(1, comboMeter - dt * comboFadingRate)

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
    if dangerouslySlowTimer > 10 then    
      if totalScore > highestScore then
        highestScore = math.floor(totalScore)
        ac.sendChatMessage("Scored " .. totalScore .. " points.")
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

  -- Update player's pre-collision speed
  playerPreCollisionSpeed = player.speedKmh

  for i = 1, ac.getSimState().carsCount do 
    local car = ac.getCarState(i)
    local state = carsState[i]

    if car.pos:closerToThan(player.pos, 10) then
      local drivingAlong = math.dot(car.look, player.look) > 0.2
      if not drivingAlong then
        state.drivingAlong = false

        if not state.nearMiss and car.pos:closerToThan(player.pos, 3) then
          state.nearMiss = true

          if car.pos:closerToThan(player.pos, 2.5) then
            comboMeter = comboMeter + 3
            addMessage('Very close near miss!', 1)
          else
            comboMeter = comboMeter + 1
            addMessage('Near miss: bonus combo', 0)
          end
        end
      end

      if car.collidedWith == 0 and collisionCooldown <= 0 then
        handleCollision(player, car) -- Handle collision
        state.collided = true
      end

      if not state.overtaken and not state.collided and state.drivingAlong then
        local posDir = (car.pos - player.pos):normalize()
        local posDot = math.dot(posDir, car.look)
        state.maxPosDot = math.max(state.maxPosDot, posDot)
        if posDot < -0.5 and state.maxPosDot > 0.5 then
          totalScore = totalScore + math.ceil(10 * comboMeter)
          comboMeter = comboMeter + 1
          comboColor = comboColor + 90
          addMessage('Overtake', comboMeter > 20 and 1 or 0)
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

  -- Update leaderboard
  updateLeaderboard()
end

-- UI and message handling
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

  -- Draw the score and collision counter
  ui.beginTransparentWindow('overtakeScore', vec2(uiState.windowSize.x * 0.5 - 600, 100), vec2(400, 400))
  ui.beginOutline()

  ui.pushStyleVar(ui.StyleVar.Alpha, 1 - speedWarning)
  ui.pushFont(ui.Font.Title)
  ui.text('Highest Score: ' .. highestScore)
  ui.popFont()
  ui.popStyleVar()

  ui.pushFont(ui.Font.Huge)
  ui.text(totalScore .. ' pts')
  ui.sameLine(0, 40)
  ui.beginRotation()
  ui.textColored(math.ceil(comboMeter * 10) / 10 .. 'x', colorCombo)
  if comboMeter > 20 then
    ui.endRotation(math.sin(comboMeter / 180 * 3141.5) * 3 * math.lerpInvSat(comboMeter, 20, 30) + 90)
  end
  ui.popFont()

  -- Draw collision counter
  ui.offsetCursorY(20)
  ui.pushFont(ui.Font.Main)
  ui.textColored('Collisions: ' .. collisionCounter .. '/' .. maxCollisions, rgbm(1, 0, 0, 1))
  ui.popFont()

  -- Draw leaderboard
  ui.offsetCursorY(40)
  ui.pushFont(ui.Font.Title)
  ui.text('Leaderboard')
  ui.popFont()
  ui.offsetCursorY(10)
  for i = 1, #leaderboard do
    ui.text(leaderboard[i].name .. ': ' .. leaderboard[i].score .. ' pts')
  end

  ui.endOutline(rgbm(0, 0, 0, 0.3))
  ui.endTransparentWindow()
end
