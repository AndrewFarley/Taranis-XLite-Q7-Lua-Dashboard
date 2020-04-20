----------------------------------------------------------
-- Written by Farley Farley
-- Adapted by Alexandre Santini for the Tango2
-- farley <at> neonsurge __dot__ com
-- From: https://github.com/AndrewFarley/Taranis-XLite-Q7-Lua-Dashboard
-- Please feel free to submit issues, feedback, etc.
----------------------------------------------------------

-- Templating

-- If you set the GPS, it will not show Quad locator & Power ouput in order to keep a readable screen
local displayGPS = false

-- Drone locator & Power ouput
local displayQuadLocator = true
local displayPowerOutput = true

-- Will be displayed only if displayGPS, Quad locator and PowerOuput are set to false
local displayFillingText = true

------- GLOBALS -------
-- The model name when it can't detect a model name  from the handset
local modelName = "Unknown"
-- Tango2 Voltage
local lowVoltage = 3.38
local currentVoltage = 4.2
local highVoltage = 4.2
-- For our timer tracking
local timerLeft = 0
local maxTimerValue = 0
-- For armed drawing
local armed = 0
-- For mode drawing
local mode = 0
-- Animation increment
local animationIncrement = 0
-- is off trying to go on...
local isArmed = 0
-- Our global to get our link_quality
local link_quality = 0
-- For debugging / development
local lastMessage = "None"
local lastNumberMessage = "0"

------- HELPERS -------
-- Helper converts voltage to percentage of voltage for a sexy battery percent
local function convertVoltageToPercentage(voltage)
  local curVolPercent = math.ceil(((((highVoltage - voltage) / (highVoltage - lowVoltage)) - 1) * -1) * 100)
  if curVolPercent < 0 then
    curVolPercent = 0
  end
  if curVolPercent > 100 then
    curVolPercent = 100
  end
  return curVolPercent
end

-- Round routine for GPS
local function round(num, idp)
  local temp = 10^(idp or 0)
  if num >= 0 then
    return math.floor(num * temp + 0.5) / temp
  else
    return math.ceil(num * temp - 0.5) / temp end
end

-- A little animation / frame counter to help us with various animations
local function setAnimationIncrement()
  animationIncrement = math.fmod(math.ceil(math.fmod(getTime() / 100, 2) * 8), 4)
end

local function drawPropellor(start_x, start_y, invert)
  local animationIncrementLocal = animationIncrement
  if invert == true then
    animationIncrementLocal = (animationIncrementLocal - 3) * -1
    animationIncrementLocal = animationIncrementLocal + 3
    if animationIncrementLocal > 3 then
      animationIncrementLocal = animationIncrementLocal - 4
    end
  end

  -- Animated Quadcopter propellors
  if ((isArmed == 0 or isArmed == 2) and invert == false) or (isArmed == 1 and animationIncrementLocal == 0) then
    -- Top left Propellor
    lcd.drawLine(start_x + 1, start_y + 9, start_x + 9, start_y + 1, SOLID, FORCE)
    lcd.drawLine(start_x + 1, start_y + 10, start_x + 8, start_y + 1, SOLID, FORCE)
  elseif isArmed == 1 and animationIncrementLocal == 1 then
    -- Top left Propellor
    lcd.drawLine(start_x, start_y + 5, start_x + 9, start_y + 5, SOLID, FORCE)
    lcd.drawLine(start_x, start_y + 4, start_x + 9, start_y + 6, SOLID, FORCE)
  elseif ((isArmed == 0 or isArmed == 2) and invert == true) or (isArmed == 1 and animationIncrementLocal == 2) then
    -- Top left Propellor
    lcd.drawLine(start_x + 1, start_y + 1, start_x + 9, start_y + 9, SOLID, FORCE)
    lcd.drawLine(start_x + 1, start_y + 2, start_x + 10, start_y + 9, SOLID, FORCE)
  elseif isArmed == 1 and animationIncrementLocal == 3 then
    -- Top left Propellor
    lcd.drawLine(start_x + 5, start_y, start_x + 5, start_y + 10, SOLID, FORCE)
    lcd.drawLine(start_x + 6, start_y, start_x + 4, start_y + 10, SOLID, FORCE)
  end
end

-- A sexy helper to draw a 30x30 quadcopter (since X7 can not draw bitmap)
local function drawQuadcopter(start_x,start_y)

  -- Top left to bottom right
  lcd.drawLine(start_x + 4, start_y + 4, start_x + 26, start_y + 26, SOLID, FORCE)
  lcd.drawLine(start_x + 4, start_y + 5, start_x + 25, start_y + 26, SOLID, FORCE)
  lcd.drawLine(start_x + 5, start_y + 4, start_x + 26, start_y + 25, SOLID, FORCE)

  -- Bottom left to top right
  lcd.drawLine(start_x + 4, start_y + 26, start_x + 26, start_y + 4, SOLID, FORCE)
  lcd.drawLine(start_x + 4, start_y + 25, start_x + 25, start_y + 4, SOLID, FORCE)
  lcd.drawLine(start_x + 5, start_y + 26, start_x + 26, start_y + 5, SOLID, FORCE)

  -- Middle of Quad
  lcd.drawRectangle(start_x + 11, start_y + 11, 9, 9, SOLID)
  lcd.drawRectangle(start_x + 12, start_y + 12, 7, 7, SOLID)
  lcd.drawRectangle(start_x + 13, start_y + 13, 5, 5, SOLID)

  -- ARMED text
  if isArmed == 1 then
    lcd.drawText(start_x + 3, start_y + 12, "ARMED", SMLSIZE + BLINK)
  end

  -- Top-left propellor
  drawPropellor(start_x, start_y, false)
  -- Bottom-Right Propellor
  drawPropellor(start_x + 20, start_y + 20, false)
  -- Top-Right Propellor
  drawPropellor(start_x + 20, start_y, true)
  -- Bottom-left Propellor
  drawPropellor(start_x, start_y + 20, true)

end

-- Sexy voltage helper
local function drawTransmitterVoltage(start_x,start_y,voltage)

  local batteryWidth = 17

  -- Battery Outline
  lcd.drawRectangle(start_x, start_y, batteryWidth + 2, 6, SOLID)
  lcd.drawLine(start_x + batteryWidth + 2, start_y + 1, start_x + batteryWidth + 2, start_y + 4, SOLID, FORCE) -- Positive Nub

  -- Battery Percentage (after battery)
  local curVolPercent = convertVoltageToPercentage(voltage)
  if curVolPercent < 20 then
    lcd.drawText(start_x + batteryWidth + 5, start_y, curVolPercent.."%", SMLSIZE + BLINK)
  else
    if curVolPercent == 100 then
      lcd.drawText(start_x + batteryWidth + 5, start_y, "99%", SMLSIZE)
    else
      lcd.drawText(start_x + batteryWidth + 5, start_y, curVolPercent.."%", SMLSIZE)
    end

  end

  -- Filled in battery
  local pixels = math.ceil((curVolPercent / 100) * batteryWidth)
  if pixels == 1 then
    lcd.drawLine(start_x + pixels, start_y + 1, start_x + pixels, start_y + 4, SOLID, FORCE)
  end
  if pixels > 1 then
    lcd.drawRectangle(start_x + 1, start_y + 1, pixels, 4)
  end
  if pixels > 2 then
    lcd.drawRectangle(start_x + 2, start_y + 2, pixels - 1, 2)
    lcd.drawLine(start_x + pixels, start_y + 2, start_x + pixels, start_y + 3, SOLID, FORCE)
  end
end

local function drawFlightTimer(start_x, start_y)
  local timerWidth = 44
  local timerHeight = 20
  local myWidth = 0
  local percentageLeft = 0

  lcd.drawRectangle( start_x, start_y, timerWidth, 10 )
  lcd.drawText( start_x + 2, start_y + 2, "Fly Timer", SMLSIZE )
  lcd.drawRectangle( start_x, start_y + 10, timerWidth, timerHeight )

  if timerLeft < 0 then
    lcd.drawRectangle( start_x + 2, start_y + 20, 3, 2 )
    lcd.drawText( start_x + 2 + 3, start_y + 12, (timerLeft * -1).."s", DBLSIZE + BLINK )
  else
    lcd.drawTimer( start_x + 2, start_y + 12, timerLeft, DBLSIZE )
  end

  percentageLeft = (timerLeft / maxTimerValue)
  local offset = 0
  while offset < (timerWidth - 2) do
    if (percentageLeft * (timerWidth - 2)) > offset then
      -- print("Percent left: "..percentageLeft.." width: "..myWidth.." offset: "..offset.." timerHeight: "..timerHeight)
      lcd.drawLine( start_x + 1 + offset, start_y + 11, start_x + 1 + offset, start_y + 9 + timerHeight - 1, SOLID, 0)
    end
    offset = offset + 1
  end

end

local function drawTime()
  -- Draw date time
  local datenow = getDateTime()
  local min = datenow.min .. ""
  if datenow.min < 10 then
    min = "0" .. min
  end
  local hour = datenow.hour .. ""
  if datenow.hour < 10 then
    hour = "0" .. hour
  end
  if math.ceil(math.fmod(getTime() / 100, 2)) == 1 then
    hour = hour .. ":"
  end
  lcd.drawText(107,0,hour, SMLSIZE)
  lcd.drawText(119,0,min, SMLSIZE)
end

local function drawlink_quality(start_x, start_y)
  local timerWidth = 44
  local timerHeight = 15
  local myWidth = 0
  local percentageLeft = 0

  lcd.drawRectangle( start_x, start_y, timerWidth, 10 )
  lcd.drawText( start_x + 2, start_y + 2, "LQ", SMLSIZE)
  if link_quality < 50 then
    lcd.drawText( start_x + 23, start_y + 2, link_quality, SMLSIZE + BLINK)
  else
    lcd.drawText( start_x + 23, start_y + 2, link_quality, SMLSIZE)
  end
  lcd.drawRectangle( start_x, start_y + 10, timerWidth, timerHeight )


  if link_quality > 0 then
    lcd.drawLine(start_x + 1,  start_y + 20, start_x + 1,  start_y + 23, SOLID, FORCE)
    lcd.drawLine(start_x + 2,  start_y + 20, start_x + 2,  start_y + 23, SOLID, FORCE)
    lcd.drawLine(start_x + 3,  start_y + 20, start_x + 3,  start_y + 23, SOLID, FORCE)
    lcd.drawLine(start_x + 4,  start_y + 20, start_x + 4,  start_y + 23, SOLID, FORCE)
  end
  if link_quality > 10 then
    lcd.drawLine(start_x + 5,  start_y + 19, start_x + 5,  start_y + 23, SOLID, FORCE)
    lcd.drawLine(start_x + 6,  start_y + 19, start_x + 6,  start_y + 23, SOLID, FORCE)
  end
  if link_quality > 13 then
    lcd.drawLine(start_x + 7,  start_y + 19, start_x + 7,  start_y + 23, SOLID, FORCE)
    lcd.drawLine(start_x + 8,  start_y + 19, start_x + 8,  start_y + 23, SOLID, FORCE)
  end
  if link_quality > 16 then
    lcd.drawLine(start_x + 9,  start_y + 18, start_x + 9,  start_y + 23, SOLID, FORCE)
    lcd.drawLine(start_x + 10, start_y + 18, start_x + 10, start_y + 23, SOLID, FORCE)
  end
  if link_quality > 19 then
    lcd.drawLine(start_x + 11, start_y + 18, start_x + 11, start_y + 23, SOLID, FORCE)
    lcd.drawLine(start_x + 12, start_y + 18, start_x + 12, start_y + 23, SOLID, FORCE)
  end
  if link_quality > 22 then
    lcd.drawLine(start_x + 13, start_y + 17, start_x + 13, start_y + 23, SOLID, FORCE)
    lcd.drawLine(start_x + 14, start_y + 17, start_x + 14, start_y + 23, SOLID, FORCE)
  end
  if link_quality > 25 then
    lcd.drawLine(start_x + 15, start_y + 17, start_x + 15, start_y + 23, SOLID, FORCE)
    lcd.drawLine(start_x + 16, start_y + 17, start_x + 16, start_y + 23, SOLID, FORCE)
  end
  if link_quality > 28 then
    lcd.drawLine(start_x + 17, start_y + 16, start_x + 17, start_y + 23, SOLID, FORCE)
    lcd.drawLine(start_x + 18, start_y + 16, start_x + 18, start_y + 23, SOLID, FORCE)
  end
  if link_quality > 31 then
    lcd.drawLine(start_x + 19, start_y + 16, start_x + 19, start_y + 23, SOLID, FORCE)
  end
  if link_quality > 34 then
    lcd.drawLine(start_x + 20, start_y + 16, start_x + 20, start_y + 23, SOLID, FORCE)
  end
  if link_quality > 37 then
    lcd.drawLine(start_x + 21, start_y + 15, start_x + 21, start_y + 23, SOLID, FORCE)
  end
  if link_quality > 40 then
    lcd.drawLine(start_x + 22, start_y + 15, start_x + 22, start_y + 23, SOLID, FORCE)
  end
  if link_quality > 43 then
    lcd.drawLine(start_x + 23, start_y + 15, start_x + 23, start_y + 23, SOLID, FORCE)
  end
  if link_quality > 46 then
    lcd.drawLine(start_x + 24, start_y + 15, start_x + 24, start_y + 23, SOLID, FORCE)
  end
  if link_quality > 49 then
    lcd.drawLine(start_x + 25, start_y + 14, start_x + 25, start_y + 23, SOLID, FORCE)
  end
  if link_quality > 52 then
    lcd.drawLine(start_x + 26, start_y + 14, start_x + 26, start_y + 23, SOLID, FORCE)
  end
  if link_quality > 55 then
    lcd.drawLine(start_x + 27, start_y + 14, start_x + 27, start_y + 23, SOLID, FORCE)
  end
  if link_quality > 58 then
    lcd.drawLine(start_x + 28, start_y + 14, start_x + 28, start_y + 23, SOLID, FORCE)
  end
  if link_quality > 61 then
    lcd.drawLine(start_x + 29, start_y + 13, start_x + 29, start_y + 23, SOLID, FORCE)
  end
  if link_quality > 64 then
    lcd.drawLine(start_x + 30, start_y + 13, start_x + 30, start_y + 23, SOLID, FORCE)
  end
  if link_quality > 67 then
    lcd.drawLine(start_x + 31, start_y + 13, start_x + 31, start_y + 23, SOLID, FORCE)
  end
  if link_quality > 70 then
    lcd.drawLine(start_x + 32, start_y + 13, start_x + 32, start_y + 23, SOLID, FORCE)
  end
  if link_quality > 73 then
    lcd.drawLine(start_x + 33, start_y + 12, start_x + 33, start_y + 23, SOLID, FORCE)
  end
  if link_quality > 76 then
    lcd.drawLine(start_x + 34, start_y + 12, start_x + 34, start_y + 23, SOLID, FORCE)
  end
  if link_quality > 79 then
    lcd.drawLine(start_x + 35, start_y + 12, start_x + 35, start_y + 23, SOLID, FORCE)
  end
  if link_quality > 82 then
    lcd.drawLine(start_x + 36, start_y + 12, start_x + 36, start_y + 23, SOLID, FORCE)
  end
  if link_quality > 85 then
    lcd.drawLine(start_x + 37, start_y + 11, start_x + 37, start_y + 23, SOLID, FORCE)
  end
  if link_quality > 88 then
    lcd.drawLine(start_x + 38, start_y + 11, start_x + 38, start_y + 23, SOLID, FORCE)
  end
  if link_quality > 91 then
    lcd.drawLine(start_x + 39, start_y + 11, start_x + 39, start_y + 23, SOLID, FORCE)
  end
  if link_quality > 94 then
    lcd.drawLine(start_x + 40, start_y + 11, start_x + 40, start_y + 23, SOLID, FORCE)
  end
  if link_quality > 97 then
    lcd.drawLine(start_x + 41, start_y + 11, start_x + 41, start_y + 23, SOLID, FORCE)
  end
  if link_quality > 98 then
    lcd.drawLine(start_x + 42, start_y + 11, start_x + 42, start_y + 23, SOLID, FORCE)
  end

  if link_quality > 0 then
    lcd.drawLine(101, 5, 101, 5, SOLID, FORCE)
    lcd.drawLine(100, 2, 102, 2, SOLID, FORCE)
    lcd.drawLine(99, 3, 99, 3, SOLID, FORCE)
    lcd.drawLine(103, 3, 103, 3, SOLID, FORCE)
    lcd.drawLine(99, 0, 103, 0, SOLID, FORCE)
    lcd.drawLine(98, 1, 98, 1, SOLID, FORCE)
    lcd.drawLine(104, 1, 104, 1, SOLID, FORCE)
  end

end

local function drawVoltageText(start_x, start_y)
  -- First, try to get voltage from VFAS...
  local voltage = getValue('RxBt')
  -- local voltage = getValue('Cels')   -- For miniwhoop seems more accurate
  -- TODO: if that failed, get voltage from somewhere else from my bigger quads?  Or rebind the voltage to VFAS?

  if tonumber(voltage) >= 10 then
    lcd.drawText(start_x,start_y,string.format("%.2f", voltage),MIDSIZE)
  else
    lcd.drawText(start_x + 7,start_y,string.format("%.2f", voltage),MIDSIZE)
  end
  lcd.drawText(start_x + 31, start_y + 4, 'v', MEDSIZE)
end

local function drawPower(start_x, start_y, output_power)
  -- lcd.drawPixMap(start_x, start_y, "/test.bmp")
  lcd.drawRectangle( start_x, start_y, 44, 10 )
  lcd.drawText( start_x + 2, start_y + 2, "Power", SMLSIZE )
  lcd.drawRectangle( start_x, start_y + 10, 44, 20 )
  lcd.drawText(start_x + 5, start_y + 12, output_power, DBLSIZE)
end

local function drawQuadLocator(start_x, start_y, rssi_dbm)
  -- lcd.drawPixMap(start_x, start_y, "/test.bmp")
  lcd.drawText( start_x + 2, start_y + 2, "Quad Locator", SMLSIZE )
  lcd.drawGauge( start_x, start_y + 10, 64, 15, rssi_dbm, 100 )
  --  lcd.drawText(start_x + 5, start_y + 12, rssi_dbm, DBLSIZE)
end

local function drawSendIt(start_x, start_y, rssi_dbm)
  -- lcd.drawPixMap(start_x, start_y, "/test.bmp")
  lcd.drawText( start_x + 2, start_y + 2, "Send It !", DBLSIZE )

end

local function drawGPS(start_x, start_y, coords)
  -- lcd.drawPixMap(start_x, start_y, "/test.bmp")
  lcd.drawText( start_x + 2, start_y + 2, "GPS coordinates", SMLSIZE )
  if (type(coords) == "table") then
    local gpsValue = round(coords["lat"],4) .. ", " .. round(coords["lon"],4)
    lcd.drawText(start_x + 5, start_y + 12, gpsValue, SMLSIZE)
  end
end

local function drawVoltageImage(start_x, start_y)

  -- Define the battery width (so we can adjust it later)
  local batteryWidth = 12

  -- Draw our battery outline
  lcd.drawLine(start_x + 2, start_y + 1, start_x + batteryWidth - 2, start_y + 1, SOLID, 0)
  lcd.drawLine(start_x, start_y + 2, start_x + batteryWidth - 1, start_y + 2, SOLID, 0)
  lcd.drawLine(start_x, start_y + 2, start_x, start_y + 50, SOLID, 0)
  lcd.drawLine(start_x, start_y + 50, start_x + batteryWidth - 1, start_y + 50, SOLID, 0)
  lcd.drawLine(start_x + batteryWidth, start_y + 3, start_x + batteryWidth, start_y + 49, SOLID, 0)

  -- top one eighth line
  lcd.drawLine(start_x + batteryWidth - math.ceil(batteryWidth / 4), start_y + 8, start_x + batteryWidth - 1, start_y + 8, SOLID, 0)
  -- top quarter line
  lcd.drawLine(start_x + batteryWidth - math.ceil(batteryWidth / 2), start_y + 14, start_x + batteryWidth - 1, start_y + 14, SOLID, 0)
  -- third eighth line
  lcd.drawLine(start_x + batteryWidth - math.ceil(batteryWidth / 4), start_y + 20, start_x + batteryWidth - 1, start_y + 20, SOLID, 0)
  -- Middle line
  lcd.drawLine(start_x + 1, start_y + 26, start_x + batteryWidth - 1, start_y + 26, SOLID, 0)
  -- five eighth line
  lcd.drawLine(start_x + batteryWidth - math.ceil(batteryWidth / 4), start_y + 32, start_x + batteryWidth - 1, start_y + 32, SOLID, 0)
  -- bottom quarter line
  lcd.drawLine(start_x + batteryWidth - math.ceil(batteryWidth / 2), start_y + 38, start_x + batteryWidth - 1, start_y + 38, SOLID, 0)
  -- seven eighth line
  lcd.drawLine(start_x + batteryWidth - math.ceil(batteryWidth / 4), start_y + 44, start_x + batteryWidth - 1, start_y + 44, SOLID, 0)

  -- Voltage top
  lcd.drawText(start_x + batteryWidth + 4, start_y + 0, "4.2v", SMLSIZE)
  -- Voltage middle
  lcd.drawText(start_x + batteryWidth + 4, start_y + 24, "3.9v", SMLSIZE)
  -- Voltage bottom
  lcd.drawText(start_x + batteryWidth + 4, start_y + 47, "3.7v", SMLSIZE)

  -- Now draw how full our voltage is...
  local voltage = getValue('RxBt')
  voltageLow = 3.8
  voltageHigh = 4.20
  voltageIncrement = ((voltageHigh - voltageLow) / 47)

  local offset = 0  -- Start from the bottom up
  while offset < 47 do
    if ((offset * voltageIncrement) + voltageLow) < tonumber(voltage) then
      lcd.drawLine( start_x + 1, start_y + 49 - offset, start_x + batteryWidth - 1, start_y + 49 - offset, SOLID, 0)
    end
    offset = offset + 1
  end
end

local function gatherInput(event)

  -- Get our link_quality
  link_quality = getValue("TQly")
  -- Get the Output power of the transmitter
  output_power = getValue("TPWR")
  -- Get the downlink RSSI to be able to find the quad
  rssi_dbm = getValue("TSNR")
  -- Get GPS values
  coords = getValue("GPS")

  -- Get the seconds left in our timer
  timerLeft = getValue('timer1')
  -- And set our max timer if it's bigger than our current max timer
  if timerLeft > maxTimerValue then
    maxTimerValue = timerLeft
  end

  -- Get our current transmitter voltage
  currentVoltage = getValue('tx-voltage')

  -- Our "mode" switch
  flight_mode = getValue("FM")

  -- Do some event handling to figure out what button(s) were pressed  :)
  if event > 0 then
    lastNumberMessage = event
  end

  if event == 131 then
    lastMessage = "Page Button HELD"
    killEvents(131)
  end
  if event == 99 then
    lastMessage = "Page Button Pressed"
    killEvents(99)
  end
  if event == 97 then
    lastMessage = "Exit Button Pressed"
    killEvents(97)
  end

  if event == 96 then
    lastMessage = "Menu Button Pressed"
    killEvents(96)
  end

  if event == EVT_ROT_RIGHT then
    lastMessage = "Navigate Right Pressed"
    killEvents(EVT_ROT_RIGHT)
  end
  if event == EVT_ROT_LEFT then
    lastMessage = "Navigate Left Pressed"
    killEvents(EVT_ROT_LEFT)
  end
  if event == 98 then
    lastMessage = "Navigate Button Pressed"
    killEvents(98)
  end

end


local function getModeText()
  local modeText = "Unknown"

  if flight_mode == "!ERR" or flight_mode == "!ERR*" then
    modeText = "----"
  elseif flight_mode == "!FS!" or flight_mode == "!FS!*" then
    modeText = "FAILSAFE"
  elseif flight_mode == "RTH"then
    modeText = "RTH"
  elseif flight_mode == "MANU"then
    modeText = "MANUAL"
  elseif flight_mode == "STAB"then
    modeText = "ANGLE"
  elseif flight_mode == "HOR" then
    modeText = "HORIZON"
  elseif flight_mode == "AIR" then
    modeText = "AIR"
  elseif flight_mode == "ACRO" then
    modeText = "ACRO"
  elseif flight_mode == "WAIT" or flight_mode == "WAIT*" then
    modeText = "WgAIT"
  elseif ((string.sub(flight_mode,-1) == "*") and (flight_mode ~= "!ERR*") and (flight_mode ~= "!FS!*") and (flight_mode ~= "WAIT*")) then
    modeText = "DISARM"
  else
    modeText = "----"
  end
  return modeText
end

local function run(event)

  -- Now begin drawing...
  lcd.clear()

  -- Gather input from the user
  gatherInput(event)

  -- Set our animation "frame"
  setAnimationIncrement()

  -- Check if we just armed...
  if armed > 512 then
    isArmed = 1
  elseif armed < 512 and isArmed == 1 then
    isArmed = 0
  else
    isArmed = 0
  end

  -- Draw a horizontal line seperating the header
  lcd.drawLine(0, 7, 128, 7, SOLID, FORCE)

  -- Draw our model name centered at the top of the screen
  lcd.drawText( 64 - math.ceil((#modelName * 5) / 2),0, modelName, SMLSIZE)

  -- Draw our mode centered at the top of the screen just under that...
  modeText = getModeText()
  lcd.drawText( 64 - math.ceil((#modeText * 5) / 2),9, modeText, SMLSIZE)

  -- Draw our sexy quadcopter animated (if armed) from scratch
  drawQuadcopter(47, 16)

  -- Draw our sexy voltage
  drawTransmitterVoltage(0,0, currentVoltage)

  -- Draw our flight timer
  drawFlightTimer(84, 34)

  -- Draw link_quality
  drawlink_quality(84, 8)

  -- Draw Time in Top Right
  drawTime()

  -- Draw Voltage bottom middle
  drawVoltageText(45,50)

  -- Draw voltage battery graphic
  drawVoltageImage(3, 10)

  if(displayGPS == false) then
    if(displayQuadLocator == true) then
      drawQuadLocator(3,65, rssi_dbm)
    end
    if (displayPowerOutput == true) then
      drawPower(84,65, output_power)
    end
    if(displayRssi == false and displayPowerOutput == false and displayFillingText == true) then
      lcd.drawText(8,70, "Team Blacksheep", MIDSIZE)
    end
  else
    drawGPS(3, 65, coords)
  end





  --

  -- drawSendIt(47, 65)
  return 0
end


local function init_func()
  -- Called once when model is loaded, only need to get model name once...
  local modeldata = model.getInfo()
  if modeldata then
    modelName = modeldata['name']
  end
end


return { run=run, init=init_func  }
