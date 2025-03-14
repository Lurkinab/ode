-- Assetto Corsa ode.lua script with original collision logic restored using ac.getCarState

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

-- Background image (insert your base64 PNG data here)
local backgroundImageBase64 = "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AQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAAADVKRoAAEB1igYAAFCdogEAAFSnaAAAANUpGgAAQHWKBgAAUJ2iAQAAVKdoAAAA1SkaAABAdYoGAABQnaIBAABUp2gAA
local backgroundImage = nil -- Will store the decoded image

-- Initialize the background image on first run
local function initializeBackgroundImage()
  if backgroundImageBase64 ~= "" and not backgroundImage then
    backgroundImage = ui.decodeBase64(backgroundImageBase64)
  end
end

function addMessage(text)
  table.insert(messages, 1, { text = text, age = 0 })
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
      addMessage('Near Miss Multiplier Reset!')
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
      nearMissMultiplier = 1.0
      nearMissStreak = 0
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

  -- Collision detection (restored original logic with ac.getCarState)
  local simState = ac.getSimState()
  for i = 1, simState.carsCount do 
    local car = ac.getCarState(i)
    if car.collidedWith == 0 and collisionCooldown <= 0 then
      if totalScore > highestScore then
        highestScore = math.floor(totalScore)
      end
      collisionCounter = collisionCounter + 1
      totalScore = math.max(0, totalScore - 1500) -- Keeping your preferred deduction
      comboMeter = 1
      nearMissMultiplier = 1.0
      nearMissStreak = 0
      addMessage('Collision: -1500')
      addMessage('Collisions: ' .. collisionCounter .. '/' .. maxCollisions)
      if collisionCounter >= maxCollisions then
        totalScore = 0
        collisionCounter = 0
        nearMissMultiplier = 1.0
        nearMissStreak = 0
        addMessage('Too many collisions! Score reset.')
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
          addMessage('Near Miss! +' .. nearMissPoints .. ' x' .. nearMissStreak)
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
            addMessage('Overtake! +50')
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
  -- Initialize the background image on the first UI draw
  initializeBackgroundImage()

  local uiState = ac.getUiState()
  updateMessages(uiState.dt)

  local speedRelative = math.saturate(math.floor(ac.getCar(0).speedKmh) / requiredSpeed)
  speedWarning = math.applyLag(speedWarning, speedRelative < 1 and 1 or 0, 0.5, uiState.dt)

  local colorDark = rgbm(0.4, 0.4, 0.4, 1)
  local colorGrey = rgbm(0.7, 0.7, 0.7, 1)
  local colorAccent = rgbm.new(hsv(speedRelative * 120, 1, 1):rgb(), 1)
  local colorCombo = rgbm.new(hsv(comboColor, math.saturate(comboMeter / 10), 1):rgb(), math.saturate(comboMeter / 4))

  -- Draw the scoreboard with background image
  ui.beginTransparentWindow('overtakeScore', vec2(uiState.windowSize.x * 0.5 - 200, 100), vec2(400, 400))
  
  -- Draw the background image if it’s available
  if backgroundImage then
    ui.drawImage(backgroundImage, vec2(0, 0), vec2(400, 400), true) -- Adjust size as needed
  end

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

  -- Draw collision counter and near miss multiplier
  ui.offsetCursorY(20)
  ui.pushFont(ui.Font.Title)
  ui.textColored('Collisions: ' .. collisionCounter .. '/' .. maxCollisions, rgbm(1, 0, 0, 1))
  ui.text('Near Miss Multiplier: ' .. string.format('%.1fx', nearMissMultiplier))
  ui.popFont()

  -- Draw temporary messages below collision counter
  ui.offsetCursorY(20)
  for i, msg in ipairs(messages) do
    local alpha = 1.0 - (msg.age / messageLifetime)
    ui.pushStyleVar(ui.StyleVar.Alpha, alpha)
    ui.text(msg.text)
    ui.popStyleVar()
    ui.offsetCursorY(20)
  end

  ui.endOutline(rgbm(0, 0, 0, 0.3))
  ui.endTransparentWindow()
end
