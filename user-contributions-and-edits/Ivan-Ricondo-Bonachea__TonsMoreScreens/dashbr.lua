----------------------------------------------------------
-- Original file Written by Farley Farley
-- farley <at> neonsurge __dot__ com
-- modified by Ivan Ricondo
-- From: https://github.com/AndrewFarley/Taranis-XLite-Q7-Lua-Dashboard
-- This file gets some information from telemetry (Voltage), and some information
-- from the current receiver (RSSI,Switch position). To show a nice dashboard
-- Original fije
-- This file currently have the dependency on qr library, download qrencode.lua
-- from  https://github.com/speedata/luaqrcode/ and copy it to /SCRIPTS/FUNCTIONS/
--
-- Instrucciones:
-- Podríamos tener 2 tipos de drones, los que tienen telemetria y los que no.
-- En base a eso vamos a definir dos sitios desde donde se puede obtener información:
-- o bien por telemetría o bien por medio de comprobar los switches de la emisora
-- (ej. en mi configuración típica en base a cómo tenga el switch SA estará en modo
-- horizon, angle o acro... en base al SE yo tendré el dron armado o desarmado)
-- Si tiene telemetría se puede sacar toda esta información del registro Tmp1
-- (El original de Farley tomaba casi todo de los switches locales).
-- Yo he cambiado todo a que tome por telemetría toda la información.
-- La telemetría nos da más información.
-- Para hacer funcionar este programa es necesario copiar el fichero LUA
-- en el directorio \SCRIPTS\TELEMETRY, y después configurar en el modelo, en la
-- pantalla DISPLAY (13) que ScreenX sea de tipo Script y ejecutando este script(
-- Hay que hacer dos cambios más en el modelo para que esto funcione. En la pantalla
-- MODEL SETUP (1) poner que el Timer 1 se active con el Switch de armado (en mi caso SE-)
-- por el mismo precio activar el Minute Call y nos ira avisando cada minuto que pase.
-- En la pantalla TELEMETRY (12), tendrás dos registros Tmp1. El que tenga 5 números
-- tendras que renombrarlo a "Mode", o bien el que tenga 2 números renombrarlo a 
-- cualquier cosa (ej. Tmp3).
-- Este script tiene más de una pantalla, para cambiar de pantalla utilizar las teclas
-- + y -.
-- En principio tendrá 4 pantallas:
--   * Pantalla de dron sin armar
--   * Pantalla de dron armado (esta por ahora no existe)
--   * Pantalla de recuperación de dron
--   * Pantalla de ayuda
-- La pantalla de ayuda tiene texto estático que podrás personalizar (yo tengo resumen
-- de los switches que tengo configurados en cada dron). Buscar HelpScreen.

----------------------------------------------------------


------- GLOBALS -------
-- The model name when it can't detect a model name from the handset
local modelName = "Unknown"

-- config de los voltajes de drones (baterías LIPO o LIHV)
local LIHV = 0	-- do you use LIHV battery (1) or LIPO (0). Default 0, and if detected high voltage change


-- variables de los voltajes del receptor (lo cojo del propio receptor), asi
-- que al final innecesarias
-- I'm using 8 NiMH Batteries in my QX7, which is 1.1v low, and ~1.325v high
-- local lowVoltage = 8.8
-- local highVoltage = 10.6
-- For an X-Lite you will need...
-- local lowVoltage = 6.6
-- local highVoltage = 8.4
-- Default baterys for X9D 6 NiMH
local lowVoltage = 6.6
local highVoltage = 8.0

local VoltageSourceId = -1
local GPSId = -1
local GSpdId = -1
local GpsStatusId = -1
local HomeDistanceId = -1
local VFASId = -1
local AltId = -1
local CurrId = -1
local CelsId = -1
local FuelId = -1
local HdgId = -1
local ModeId = -1
local PitchId = -1
local RollId = -1

local MY_LCD_W = LCD_W


-- screen to show
local defaultscreen = 0		-- iniciar en pantalla por defecto
local maxscreen = 4	-- number of screens to show (change screen with + and - buttons, and page button)
local screen = defaultscreen
-- For our timer tracking
-- local timerLeft = 0
-- local maxTimerValue = 0
-- For armed drawing
local armed = 0
-- For mode drawing
local mode = 0
-- Animation increment
local animationIncrement = 0
-- is off trying to go on...
local isArmed = 0
-- Our global to get our current rssi
local rssi = 0
local status = ""

-- si no hay otra dirección: bilbao, centro del mundo :-P
local lat = "43.2649914"
local lon = "-2.9463711"
local dist = 0

-- For debugging / development
-- local lastMessage = "None"
-- local lastNumberMessage = "0"

local voltage = 0	-- voltaje ultimo visto (para resetear timer1 cuando se quita bateria)
local volzero = 0	-- boolean para saber si se ha quitado bateria
local volmin = 0	-- voltaje minimo (se actualiza desde background)
local volminreset = 1	-- boolean para saber cuando se ha desarmado (para
			--  que al armar se vuelva a poner voltaje correcto)
local currmax = 0	-- consumo mas alto
local timearmed = 0	-- hora de armado desarmado
local timeunarmed = 0	-- hora de armado desarmado




-- CONFIG: una pantalla con información de usuario, instrucciones o lo que sea
-- yo llevo recordatorio de los switches que tengo configurados
local function HelpScreen()
    -- estara dibujado un header, si no lo quieres ejecuta un borrar pantalla
    lcd.drawText(2, 9, "SE: Disarm / Arm / Beeper",SMLSIZE)
    lcd.drawText(2, 17, "SA: Angle / Horizon / AcroTrain",SMLSIZE)
    lcd.drawText(2, 25, "SB: - / AirMode / Antigravity",SMLSIZE)
    lcd.drawText(2, 33, "SC: - / HeadFree Adj / HeadFree",SMLSIZE)
    lcd.drawText(2, 41, "SD: - / Horizon / GPS Rescue",SMLSIZE)
    lcd.drawText(2, 49, "SF: - / Flip over after crash",SMLSIZE)
    lcd.drawText(2, 57, "SG: Change OSD (1/2/3)",SMLSIZE)
end


------- HELPERS -------
-- function to handle three position switchs
-- mode is a value from -1024 to 1024. Check in what
-- position is the switch, and return 
-- local function threePos(value,option1,option2,option3)
--   if value < -512 then
--     return option1
--   elseif value > 512 then
--     return option3
--   else
--     return option2
--   end
-- end

-- lo mismo que el anterior para switches de 2 posiciones
-- local function twoPos(value,option1,option2)
--   if value < 100 then	-- en lugar del 0 poneos un poco mas por si es uno de tres?
--     return option1
--   else
--     return option2
--   end
-- end

-- returns a % b
local function mod(a,b)
  return a - math.floor(a/b)*b
end

-- returns a / b
local function div(a,b)
  return math.floor(a/b)
end


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

-- esta rutina sirve para ejecutar ciertas cosas cada cierto tiempo
-- si le pone divisor 100, dara 0 durante 1 segundo y 1 durante otro...
-- si le pone divisor 200, dara 0 durante 2 segundos y 1 durante otros dos ..
local function stepsTime(divisor)
  return math.ceil(math.fmod(getTime() / divisor, 2) )
end


-- A little animation / frame counter to help us with various animations
local function setAnimationIncrement()
  animationIncrement = math.fmod(math.ceil(math.fmod(getTime() / 100, 2) * 8), 4)
end


------- DRAW ROUTINE -------
-- dibujar las helices del dron
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


-- Sexy voltage helper without bmp (for QX7
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

-- Imprimir el tiempo de vuelo (se coge del timer 1 
-- de la emisora. Habra que programar en el modelo 
-- correspondiente que cuando el switch de armado este
-- activado cuente). Creo que este tio en lugar de tenerlo
-- como un timer lo tiene como una cuenta atras y por eso
-- lia todo esta rutina 
local function drawFlightTimer(start_x, start_y)
  local timerWidth = 44
  local timerHeight = 20
  local myWidth = 0
  local percentageLeft = 0
  
  lcd.drawRectangle( start_x, start_y, timerWidth, 10 )
  lcd.drawText( start_x + 2, start_y + 2, "Fly Timer", SMLSIZE )
  lcd.drawRectangle( start_x, start_y + 10, timerWidth, timerHeight )

--   if timerLeft < 0 then
--     lcd.drawRectangle( start_x + 2, start_y + 20, 3, 2 )
--     lcd.drawText( start_x + 2 + 3, start_y + 12, (timerLeft * -1).."s", DBLSIZE + BLINK )
--   else
    lcd.drawTimer( start_x + 2, start_y + 12, timerLeft, DBLSIZE )
--   end 
  
--   percentageLeft = (timerLeft / maxTimerValue)
--   local offset = 0
--   while offset < (timerWidth - 2) do
--     if (percentageLeft * (timerWidth - 2)) > offset then
--       -- print("Percent left: "..percentageLeft.." width: "..myWidth.." offset: "..offset.." timerHeight: "..timerHeight)
--       lcd.drawLine( start_x + 1 + offset, start_y + 11, start_x + 1 + offset, start_y + 9 + timerHeight - 1, SOLID, 0)
--     end
--     offset = offset + 1
--   end
end

--  Dibujar la hora
local function drawTime(starx,stary)
  -- Draw date time
  local datenow = getDateTime()
  local min = string.format("%02.0f", datenow.min)
  -- local min = datenow.min .. ""
  -- if datenow.min < 10 then
  --   min = "0" .. min
  -- end
  local hour = string.format("%02.0f", datenow.hour)
  -- local hour = datenow.hour .. ""
  -- if datenow.hour < 10 then
  --   hour = "0" .. hour
  -- end
  if stepsTime(100) == 1 then  -- parpadeo de los : de la hora
    hour = hour .. ":"
  end
  lcd.drawText(starx,stary,hour, SMLSIZE)
  lcd.drawText(starx+12,stary,min, SMLSIZE)
end

-- dibujar rssi
local function drawRSSI(start_x, start_y)
  local timerWidth = 44
  local timerHeight = 15
  local myWidth = 0
  local percentageLeft = 0
  
  lcd.drawRectangle( start_x, start_y, timerWidth, 10 )
  lcd.drawText( start_x + 2, start_y + 2, "RSSI:", SMLSIZE)
  if rssi < 50 then
    lcd.drawText( start_x + 23, start_y + 2, rssi, SMLSIZE + BLINK + INVERS)
  else
    lcd.drawText( start_x + 23, start_y + 2, rssi, SMLSIZE)
  end
  lcd.drawRectangle( start_x, start_y + 10, timerWidth, timerHeight )
  
  local end_y = start_y + 23

  if rssi > 0 then
    lcd.drawLine(start_x + 1,  start_y + 20, start_x + 1,  end_y, SOLID, FORCE)
    lcd.drawLine(start_x + 2,  start_y + 20, start_x + 2,  end_y, SOLID, FORCE)
    lcd.drawLine(start_x + 3,  start_y + 20, start_x + 3,  end_y, SOLID, FORCE)
    lcd.drawLine(start_x + 4,  start_y + 20, start_x + 4,  end_y, SOLID, FORCE)
  end
  if rssi > 10 then
    lcd.drawLine(start_x + 5,  start_y + 19, start_x + 5,  end_y, SOLID, FORCE)
    lcd.drawLine(start_x + 6,  start_y + 19, start_x + 6,  end_y, SOLID, FORCE)
  end
  if rssi > 13 then
    lcd.drawLine(start_x + 7,  start_y + 19, start_x + 7,  end_y, SOLID, FORCE)
    lcd.drawLine(start_x + 8,  start_y + 19, start_x + 8,  end_y, SOLID, FORCE)
  end
  if rssi > 16 then
    lcd.drawLine(start_x + 9,  start_y + 18, start_x + 9,  end_y, SOLID, FORCE)
    lcd.drawLine(start_x + 10, start_y + 18, start_x + 10, end_y, SOLID, FORCE)
  end
  if rssi > 19 then
    lcd.drawLine(start_x + 11, start_y + 18, start_x + 11, end_y, SOLID, FORCE)
    lcd.drawLine(start_x + 12, start_y + 18, start_x + 12, end_y, SOLID, FORCE)
  end
  if rssi > 22 then
    lcd.drawLine(start_x + 13, start_y + 17, start_x + 13, end_y, SOLID, FORCE)
    lcd.drawLine(start_x + 14, start_y + 17, start_x + 14, end_y, SOLID, FORCE)
  end
  if rssi > 25 then
    lcd.drawLine(start_x + 15, start_y + 17, start_x + 15, end_y, SOLID, FORCE)
    lcd.drawLine(start_x + 16, start_y + 17, start_x + 16, end_y, SOLID, FORCE)
  end
  if rssi > 28 then
    lcd.drawLine(start_x + 17, start_y + 16, start_x + 17, end_y, SOLID, FORCE)
    lcd.drawLine(start_x + 18, start_y + 16, start_x + 18, end_y, SOLID, FORCE)
  end
  if rssi > 31 then
    lcd.drawLine(start_x + 19, start_y + 16, start_x + 19, end_y, SOLID, FORCE)
  end
  if rssi > 34 then
    lcd.drawLine(start_x + 20, start_y + 16, start_x + 20, end_y, SOLID, FORCE)
  end
  if rssi > 37 then
    lcd.drawLine(start_x + 21, start_y + 15, start_x + 21, end_y, SOLID, FORCE)
  end
  if rssi > 40 then
    lcd.drawLine(start_x + 22, start_y + 15, start_x + 22, end_y, SOLID, FORCE)
  end
  if rssi > 43 then
    lcd.drawLine(start_x + 23, start_y + 15, start_x + 23, end_y, SOLID, FORCE)
  end
  if rssi > 46 then
    lcd.drawLine(start_x + 24, start_y + 15, start_x + 24, end_y, SOLID, FORCE)
  end
  if rssi > 49 then
    lcd.drawLine(start_x + 25, start_y + 14, start_x + 25, end_y, SOLID, FORCE)
  end
  if rssi > 52 then
    lcd.drawLine(start_x + 26, start_y + 14, start_x + 26, end_y, SOLID, FORCE)
  end
  if rssi > 55 then
    lcd.drawLine(start_x + 27, start_y + 14, start_x + 27, end_y, SOLID, FORCE)
  end
  if rssi > 58 then
    lcd.drawLine(start_x + 28, start_y + 14, start_x + 28, end_y, SOLID, FORCE)
  end
  if rssi > 61 then
    lcd.drawLine(start_x + 29, start_y + 13, start_x + 29, end_y, SOLID, FORCE)
  end
  if rssi > 64 then
    lcd.drawLine(start_x + 30, start_y + 13, start_x + 30, end_y, SOLID, FORCE)
  end
  if rssi > 67 then
    lcd.drawLine(start_x + 31, start_y + 13, start_x + 31, end_y, SOLID, FORCE)
  end
  if rssi > 70 then
    lcd.drawLine(start_x + 32, start_y + 13, start_x + 32, end_y, SOLID, FORCE)
  end
  if rssi > 73 then
    lcd.drawLine(start_x + 33, start_y + 12, start_x + 33, end_y, SOLID, FORCE)
  end
  if rssi > 76 then
    lcd.drawLine(start_x + 34, start_y + 12, start_x + 34, end_y, SOLID, FORCE)
  end
  if rssi > 79 then
    lcd.drawLine(start_x + 35, start_y + 12, start_x + 35, end_y, SOLID, FORCE)
  end
  if rssi > 82 then
    lcd.drawLine(start_x + 36, start_y + 12, start_x + 36, end_y, SOLID, FORCE)
  end
  if rssi > 85 then
    lcd.drawLine(start_x + 37, start_y + 11, start_x + 37, end_y, SOLID, FORCE)
  end
  if rssi > 88 then
    lcd.drawLine(start_x + 38, start_y + 11, start_x + 38, end_y, SOLID, FORCE)
  end
  if rssi > 91 then
    lcd.drawLine(start_x + 39, start_y + 11, start_x + 39, end_y, SOLID, FORCE)
  end
  if rssi > 94 then
    lcd.drawLine(start_x + 40, start_y + 11, start_x + 40, end_y, SOLID, FORCE)
  end
  if rssi > 97 then
    lcd.drawLine(start_x + 41, start_y + 11, start_x + 41, end_y, SOLID, FORCE)
  end
  if rssi > 98 then
    lcd.drawLine(start_x + 42, start_y + 11, start_x + 42, end_y, SOLID, FORCE)
  end
end

-- si tiene señal rssi dibujar especie de onditas
-- por defecto que vaya en drawHeaderSignal(MY_LCD_W-30,0)
local function drawHeaderSignal(starx,stary)  
  if rssi > 0 then
    lcd.drawLine(starx+3, stary+5, starx+3, stary+5, SOLID, FORCE)
    lcd.drawLine(starx+2, stary+2, starx+4, stary+2, SOLID, FORCE)
    lcd.drawLine(starx+1, stary+3, starx+1, stary+3, SOLID, FORCE)
    lcd.drawLine(starx+5, stary+3, starx+5, stary+3, SOLID, FORCE)
    lcd.drawLine(starx+1, stary, starx+5, stary, SOLID, FORCE)
    lcd.drawLine(starx, stary+1, starx, stary+1, SOLID, FORCE)
    lcd.drawLine(starx+6, stary+1, starx+6, stary+1, SOLID, FORCE)
  end
end


local function drawStatus()
  if ( status ~= "" ) then
    local x=(MY_LCD_W-7*#status)/2
    lcd.drawText(x,LCD_H/2-5,status,MIDSIZE+INVERS+BLINK)
    lcd.drawRectangle(x-1,LCD_H/2-6,lcd.getLastPos()-x+2,14,ERASE)
    lcd.drawRectangle(x-2,LCD_H/2-7,lcd.getLastPos()-x+4,16,SOLID)
    lcd.drawRectangle(x-3,LCD_H/2-8,lcd.getLastPos()-x+6,18,ERASE)
    status = ""
  end
end


-- Tenemos una recta que pasa por (x1,y1) y por (x2,y2).
-- esta rutina nos dara el punto (xxxx,size) manteniendo
-- la misma recta (xxxx sera lo que devolvera)
local function Interpolar(x1,y1,x2,y2,size)
  return (size-y1)/(y2-y1)*(x2-x1)+x1
end


-- dibujar linea de horizonte virtual
-- le pasamos el centro, no el punto arriba izquierda
-- algunas ideas cogidas de https://github.com/iNavFlight/LuaTelemetry/blob/master/src/iNav/pilot.lua
-- por ahora es una prueba rapida. La línea se sale del recuardo por arriba y por abajo
local function drawHorizon(starx,stary,size)
  local pitch=getValue(PitchId)/10
  local roll=getValue(RollId)/10
  local dx=math.cos(math.rad(roll)) * size
  local dy=math.sin(math.rad(roll)) * size
  local p=math.sin(math.rad(pitch)) * size * 0.85
  local x1,y1=-dx,-dy-p
  local x2,y2=dx,dy-p

  -- dibujar rectangulo
  lcd.drawFilledRectangle(starx-size,stary-size,size+size+1,size+size+1,ERASE)
  lcd.drawRectangle(starx-size-1,stary-size-1,size+size+3,size+size+3,SOLID)

  -- lcd.drawText(0,0,string.format("%2.1f,%2.1f,%2.1f,%2.1f",x1,y1,x2,y2),SMLSIZE) -- for debugging

  -- ver si se sale y corregir
  if (y1>size) then		-- se sale linea por arriba? esta bien comparacion?
    x1=Interpolar(x2,y2,x1,y1,size)  -- deberiamos calcular esto
    y1=size
  end
  if (y2>size) then		-- se sale linea por arriba? esta bien comparacion?
    x2=Interpolar(x1,y1,x2,y2,size)  -- deberiamos calcular esto
    y2=size
  end
  if (y1<-size) then		-- se sale linea por abajo? esta bien comparacion?
    x1=Interpolar(x2,y2,x1,y1,-size)  -- deberiamos calcular esto
    y1=-size
  end
  if (y2<-size) then		-- se sale linea por abajo? esta bien comparacion?
    x2=Interpolar(x1,y1,x2,y2,-size)  -- deberiamos calcular esto
    y2=-size
  end

  -- lcd.drawText(0,8,string.format("%2.1f,%2.1f,%2.1f,%2.1f",x1,y1,x2,y2),SMLSIZE) -- for debuging
  -- texto con el angulo de pitch
  -- lcd.drawText(starx-size,stary+size-7,string.format("%3.0fº", pitch),SMLSIZE)
  -- dibujar linea
  lcd.drawLine(starx+x1, stary+y1, starx+x2, stary+y2, SOLID, FORCE)	-- dibujar linea horizonte
  -- dibujar cruz en medio
  lcd.drawLine(starx-2,stary,starx+2,stary,SOLID,FORCE)	-- dibujar cruz en medio
  lcd.drawLine(starx,stary-2,starx,stary+2,SOLID,FORCE)	-- dibujar cruz en medio
end


-- vamos a coger de la telemetria el registro Tmp1
-- https://github.com/betaflight/betaflight/blob/master/docs/Telemetry.md
-- problema Betaflight te envia dos registros Tmp1 (el de smartport y el suyo
-- propio). Hay que renombrar uno (o el bueno, el de 5 cifras que podemos
-- renombrarlo a Mode, o bien quitar el Tmp1 que no interesa (renombrarlo
-- por ejemplo a Tmp3?)
local function getModeTelemetry()
  if (ModeId==-1) then		-- si no hay variable Tmp1 salir sin mas
    return 0
  end
  local mode=getValue(ModeId)	-- leer telemetria
  if (mode) then
    if(mode<10000 and mode~=0) then		-- si no es el tmp1 correcto....
      status="There are 2 Tmp1, remove one"
      return 0
    end
    return mode
  else
    return 0
  end
end


-- obtener cuantos satelites de GPS tenemos
local function getGpsSat()
  local n = mod(getValue (GpsStatusId),100)
  return n
end


local function getArmed()
  armed=mod(getModeTelemetry(),10)
  if (armed>=4) then
    return 1
  else
    return 0
  end
end

-- fuente de donde coger modo y los diferentes modos
-- equivalentes:
-- get mode text (read mode switch, and put the mode text)

local function getModeText()
  -- Our "mode" switch
  -- mode = getValue('sb')
  mode = mod(div(getModeTelemetry(),10),10)
  if(mode==0) then
    return "Acro"
  elseif(mode==1) then
    return "Angle"
  elseif(mode==2) then
    return "Horizon"
  else
    return "Mode " .. mode
  end
end


local function getVoltage()
  -- conseguir el voltaje por celda
  local voltage = getValue(VoltageSourceId)
 
  -- pudiera ser que consiguiesemos por detector de celdas y cojamos el mínimo
  if CelsId ~= -1 then
    local cells = getValue(CelsId)
    if typeof(cells) == 'table' then
      for k, v in pairs(cells) do
        if(k==0) then
          voltage=v
        elseif(v<voltage) then
          voltage=v
        end
      end
    end
  end

  return voltage
end


local function drawVoltageText(start_x, start_y)
  local voltage=getVoltage()

  local mode=0
  if LIHV and voltage<=3.3 then
    mode=BLINK+INVERS
  end
  if LIHV==0 and voltage<=3.45 then 
    mode=BLINK+INVERS
  end
  lcd.drawText(start_x,start_y,string.format("%4.2f", voltage),MIDSIZE+mode)
  lcd.drawText(lcd.getLastPos(), start_y + 4, 'V',0+mode)
  -- lcd.drawText(lcd.getLastPos(), start_y, 'v',MIDSIZE+mode)
end


local function drawVoltageImage(start_x, start_y)
  -- Define the battery width (so we can adjust it later)
  local batteryWidth = 12 

  -- read cell value
  local voltage = getValue(VoltageSourceId)

  if voltage>=4.21 then		-- si celda en algun momento esta por encima de 4.21 supondremos que es bateria LIHV
    LIHV = 1
  end

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

  if (LIHV == 1) then  -- if LIHV
    -- Voltage top
    lcd.drawText(start_x + batteryWidth + 4, start_y + 0, "4.35v", SMLSIZE)
    -- Voltage middle
    lcd.drawText(start_x + batteryWidth + 4, start_y + 24, "3.85v", SMLSIZE)
    -- Voltage bottom
    lcd.drawText(start_x + batteryWidth + 4, start_y + 47, "3.35v", SMLSIZE)
    voltageLow = 3.35
    voltageHigh = 4.35
  else  -- if LIPO
    -- Voltage top
    lcd.drawText(start_x + batteryWidth + 4, start_y + 0, "4.2v", SMLSIZE)
    -- Voltage middle
    lcd.drawText(start_x + batteryWidth + 4, start_y + 24, "3.7v", SMLSIZE)
    -- Voltage bottom
    lcd.drawText(start_x + batteryWidth + 4, start_y + 47, "3.2v", SMLSIZE)
    voltageLow = 3.2
    voltageHigh = 4.2
  end
 
  -- Now draw how full our voltage is...
  voltageIncrement = ((voltageHigh - voltageLow) / 47)
  
  local offset = 0  -- Start from the bottom up
  while offset < 47 do
    if ((offset * voltageIncrement) + voltageLow) < tonumber(voltage) then
      lcd.drawLine( start_x + 1, start_y + 49 - offset, start_x + batteryWidth - 1, start_y + 49 - offset, SOLID, 0)
    end
    offset = offset + 1
  end
end

-- le pasamos posicion, el texto de descripcion, el valor y las unidades
-- ej. drawValue(20,8,"Curr: ",string.format("%.1f", getValue(CurrId)),"A")
-- ocupara 12 vertical... ancho mas o menos (#desc+#unit)*6+#value*7
local function drawValueH(starx,stary,desc,value,unit)
  lcd.drawText(starx, stary+4, desc,SMLSIZE)
  local mode=0
  if rssi==0 then
    mode=BLINK+INVERS
  end
  lcd.drawText(lcd.getLastPos(), stary, value,MIDSIZE+mode)
  lcd.drawText(lcd.getLastPos(), stary+4, unit, mode)
end


-- igual que anterior pero pone el texto en un formato que ocupa mas en vertical y menos en horizontal
-- ocupara 20 vertical... ancho mas o menos #unit*6+#value*7
local function drawValueV(starx,stary,desc,value,unit)
  lcd.drawText(starx, stary, desc,SMLSIZE)
  local mode=0
  if rssi==0 then
    mode=BLINK+INVERS
  end
  lcd.drawText(starx, stary+8, value,MIDSIZE+mode)
  if(unit=="º") then
    lcd.drawText(lcd.getLastPos(), stary+9, "o", SMLSIZE+mode)
  elseif (#unit<=2) then
    lcd.drawText(lcd.getLastPos(), stary+12, unit, mode)
  else
    lcd.drawText(lcd.getLastPos(), stary+13, unit, SMLSIZE+mode)
  end
end


-- Valores a mostrar eni:
--   * dron grande sin armar pantalla grande: mah, voltaje, sat gps, current
--   * dron peque sin armar pantalla grande: voltaje min, voltaje, mah, current
--   * dron grande armado pantalla grande: + altitud, + velocidad (cambiar cada 2 segundos a otros)
--   * dron peque armado pantalla grande: + hgd +current max
--   * ...
-- Por defecto drawValuesBigScreen(83,12,0) o drawValuesBigScreen(40,12,1)
local function drawValuesBigScreen(starx,stary,threecols)
    local nextx=43
    local nexty=24
    local step=stepsTime(200)

    if (GPSId == -1) then
      drawValueV(starx,stary,"Vol-:",string.format("%4.2f", volmin),"V") -- voltage
      drawValueV(starx+nextx,stary+nexty,"Fuel: ",string.format("%2.0f", getValue(FuelId)),"mah") -- si es peque
    else
      drawValueV(starx,stary,"Fuel:",string.format("%2.0f", getValue(FuelId)),"mah") -- si es grande
      if (threecols==1) then
        drawValueV(starx+nextx,stary+nexty,"Fuel:",string.format("%2.0f", getValue(FuelId)),"mah") -- si es peque
      else
        drawValueV(starx+nextx,stary+nexty,"Sats:",getGpsSat(),"")   -- gps
      end
    end

    if (step==1 or GPSId==-1) then
      lcd.drawText(starx,stary+nexty,"Vol:",SMLSIZE)
      drawVoltageText(starx,stary+nexty+8)
      drawValueV(starx+nextx,stary,"Curr:",string.format("%3.1f", getValue(CurrId)),"A")
    else
      drawValueV(starx,stary+nexty,"Vol-:",string.format("%4.2f", volmin),"V") -- voltage
      drawValueV(starx+nextx,stary,"Curr+:",string.format("%3.1f", currmax),"A") -- consumo
    end

    if threecols == 1 then
      if (AltId == -1) then	-- si no tienen altitud imprimir heading (de relleno)
        drawValueV(starx+nextx+nextx,stary,"Hdg: ",string.format("%3.0f", getValue(HdgId)),"º")
      else
        drawValueV(starx+nextx+nextx,stary,"Alt: ",string.format("%5.1f", getValue(AltId)),"m")
      end

      if (GSpdId == -1) then	-- si no tienen gps poner inclinacion
        -- drawValueV(starx+nextx,stary+nexty,"Vol:",string.format("%5.2f", getValue(VFASId)),"V")
        drawValueV(starx+nextx+nextx,stary+nexty,"Pitch: ",string.format("%3.0f", getValue(PitchId)/10),"º")
      else
        drawValueV(starx+nextx+nextx,stary+nexty,"Spd: ",string.format("%2.0f", getValue(GSpdId)),"km/h")
      end
    end
end


-- drawValuesSmallScreen(40,12)
local function drawValuesSmallScreen(starx,stary)
    local nexty=24
    local step=stepsTime(200)
    if (step == 1) then
      drawValueV(starx,stary,"Fuel: ",string.format("%2.0f", getValue(FuelId)),"mah") -- consumo
      drawValueV(starx,stary+nexty,"Vol:",string.format("%4.2f", getVoltage()),"V") -- voltage
    else
      drawValueV(starx,stary,"Curr: ",string.format("%3.1f", getValue(CurrId)),"A") -- consumo
      drawValueV(starx,stary+nexty,"Vol-:",string.format("%4.2f", volmin),"V") -- voltage minimo
    end
end


-- drawHeader
local function drawHeader(title)
  -- Draw a horizontal line seperating the header
  lcd.drawLine(0, 7, MY_LCD_W, 7, SOLID, FORCE)

  -- Get our current transmitter voltage
  local currentVoltage = getValue('tx-voltage')
   
  -- Draw our sexy voltage
  drawTransmitterVoltage(0,0, currentVoltage)

  -- Draw our model name centered at the top of the screen
  -- prueba quito titulo para ver que se escribe
  lcd.drawText( MY_LCD_W/2 - math.ceil((#title * 5) / 2),0, title, SMLSIZE)

  -- Draw Time in Top Right
  drawTime(MY_LCD_W-21,0)

  -- Draw signal indicator
  drawHeaderSignal(MY_LCD_W-30,0)
end

------------ Otras rutinas -------------------
local function gatherInput(event)
  -- Do some event handling to figure out what button(s) were pressed  :)
  -- if event > 0 then
  --   lastNumberMessage = event
  -- end
  
  if event == 131 then
    -- lastMessage = "Page Button HELD"
    killEvents(131)

  elseif event == 99 then
    -- lastMessage = "Page Button Pressed"
    screen = defaultscreen		-- si cambiamos de pantalla ir a pantalla 0

--  elseif event == 97 then
--    -- lastMessage = "Exit Button Pressed"
--    killEvents(97)

  elseif event == 96 then
    -- lastMessage = "Menu Button Pressed"
    -- killEvents(96)

    screen = screen + 1		-- change screen
    if(screen>=maxscreen) then
      screen = 0
    end

  elseif event == EVT_PLUS_FIRST then
    screen = screen + 1		-- change screen
    if(screen>=maxscreen) then
      screen = 0
    end
    killEvents(EVT_PLUS_FIRST)

  elseif event == EVT_MINUS_FIRST then
    screen = screen - 1		-- change screen
    if(screen<0) then
      screen = maxscreen - 1
    end
    killEvents(EVT_MINUS_FIRST)

--  elseif event == EVT_ROT_RIGHT then
--    -- lastMessage = "Navigate Right Pressed"
--    killEvents(EVT_ROT_RIGHT)

--  elseif event == EVT_ROT_LEFT then
--    -- lastMessage = "Navigate Left Pressed"
--    killEvents(EVT_ROT_LEFT)

--  elseif event == 98 then
--    -- lastMessage = "Navigate Button Pressed"
--    killEvents(98)
  end

end


local function screenprearm()
  -- Set our animation "frame"
  setAnimationIncrement()

  isArmed = getArmed()

  -- en base a ancho (LCD_H) podriamos modificar y adaptarnos a pantalla
  -- local despx = (MY_LCD_W-128)/2
  -- local despy = (LCD_H-64)/2


  drawHeader(modelName .. " - Prearm")
  

  -- Draw our mode centered at the top of the screen just under that...
  modeText = getModeText()
  lcd.drawText( 60 - math.ceil((#modeText * 5) / 2),9, modeText, SMLSIZE)

  -- Draw our sexy quadcopter animated (if armed) from scratch
  drawQuadcopter(42, 16)
 
  -- Draw our flight timer
  drawFlightTimer(MY_LCD_W-44, 34)
  
  -- Draw RSSI
  drawRSSI(MY_LCD_W-44, 8)
  
  -- Draw Voltage bottom middle
  if(MY_LCD_W<=128) then
    drawVoltageText(41,50)
  end
 
  -- Draw voltage battery graphic
  drawVoltageImage(3, 10)

  -- Draw some other information
  if(MY_LCD_W>128) then
    drawValuesBigScreen(83,12,0)
  end

  drawStatus()

  -- 3 segundos despues de armar cambiar a pantalla 1
  if(isArmed == 1) then
    if (timearmed ~= 0 and getTime()-timearmed>300) then
      screen=1
      timearmed=0
    end
  else
    timearmed=getTime()
  end
end


local function screenarm()

  drawHeader(modelName .. " - Arm")
  
  -- Draw our flight timer
  drawFlightTimer(MY_LCD_W-44, 34)
  
  -- Draw RSSI
  drawRSSI(MY_LCD_W-44, 8)
  
  -- Draw voltage battery graphic
  drawVoltageImage(3, 10)

  -- Draw some other information
  if(MY_LCD_W>128) then
    drawValuesBigScreen(40,12,1)
  else
    drawValuesSmallScreen(40,12)
  end

  -- drawHorizon(126,47,10)

  drawStatus()

  -- 5 segundos despues de desarmar cambiar a pantalla 0
  isArmed = getArmed()
  if (isArmed == 0) then
    if (timeunarmed ~= 0 and getTime()-timeunarmed>500) then
      screen=0
      timeunarmed=0
    end
  else
    timeunarmed=getTime()
  end
end


-- pantalla de recuperacion del drone
local function screenrecover()
  drawHeader("Drone Recover")

  drawValueH(8, 12, "RSSI: ",rssi,"")

  local voltage=getVoltage()

  local mode=0
  if LIHV and voltage<=3.3 then
    mode=BLINK+INVERS
  end
  if LIHV==0 and voltage<=3.45 then
    mode=BLINK+INVERS
  end
  drawValueH(8, 24, "Vol:", string.format("%5.2f", voltage),"V")

  if (GPSId ~= -1) then
    local url = ""
    if lat ~= "" then
      --url = "HTTPS://WWW.GOOGLE.ES/maps/@" .. lat .. "," .. lon .. ",99m/data=!3m1!1e3"
      url = lat .. "," .. lon
    end

    if HomeDistanceId ~= -1 then
      drawValueH(MY_LCD_W/2+2, 36, "Dis: ",string.format("%3.0f", dist),"")
    end

    if type(pos) == "table" then
      lcd.drawText(MY_LCD_W/2+2, 12+4, "Lat: ", SMLSIZE)	-- si hay posicion gps (hay cobertura)
      lcd.drawText(lcd.getLastPos(), 12, lat, MIDSIZE)
      lcd.drawText(MY_LCD_W/2+2, 24+4, "Lon: ", SMLSIZE)
      lcd.drawText(lcd.getLastPos(), 24, lon, MIDSIZE)
    else						-- si no hay posicion gps (sin cobertura o sin telemetria)
      lcd.drawText(MY_LCD_W/2+2, 12+4, "Lat: ", SMLSIZE)
      lcd.drawText(lcd.getLastPos(), 12, lat,MIDSIZE+BLINK+INVERS)
      lcd.drawText(MY_LCD_W/2+2, 24+4, "Lon: ", SMLSIZE)
      lcd.drawText(lcd.getLastPos(), 24, lon,MIDSIZE+BLINK+INVERS)
    end

    -- draw qr with the url
    -- lcd.drawRectangle(100, 6, 37, 37, SOLID)
    -- pruebaQR(102,3,table_pruebaQR)
  
    if url ~= "" then
      -- draw qr
      -- print url
      -- lcd.drawText(0, 36, string.sub(url,1,208/8),0)
      -- lcd.drawText(0, 50, string.sub(url,208/8+1),MIDSIZE)
      lcd.drawText(0, 44, "Search in Google Maps:",SMLSIZE)
      lcd.drawText(0, 56, "GEO: ",SMLSIZE)
      lcd.drawText(lcd.getLastPos(), 52, url,MIDSIZE)
    end
  else
    lcd.drawText(0, 44, "Your Quad doesn't have GPS",SMLSIZE)
  end
end


-- Pantalla 4, pantalla con ayuda
local function screenhelp()
  drawHeader("Help")
  HelpScreen()  -- screen2 is help screen
end 


-- run
local function run(event)
 

  if (mod(getModeTelemetry(),10)==2) then
    status = "Arming disabled"
  else
    status = ""
  end

 
-- Get our RSSI
  rssi = getRSSI()

  -- Get the seconds left in our timer
  timerLeft = getValue('timer1')
  -- And set our max timer if it's bigger than our current max timer
  -- if timerLeft > maxTimerValue then
  --   maxTimerValue = timerLeft
  -- end

  
  -- Now begin drawing...
  lcd.clear()
  
  -- Gather input from the user
  gatherInput(event)
 
  if (screen==1) then
    screenarm()
  elseif (screen==2) then
    screenrecover()
  elseif (screen==3) then
    screenhelp()
  else
    screenprearm()
  end

  return 0
end


-- function from: https://opentx.gitbooks.io/opentx-lua-reference-guide/content/handling_gps_sensor_data.html
local function getTelemetryId(name)
    field = getFieldInfo(name)
    if field then
      return field.id
    else
      return -1
    end
end



-- independientemente de pantalla actualizar datos
-- para el rescate del drone y voltaje minimo
local function background()
  -- actualizar distancia de home al drone
  if HomeDistanceId ~= -1 then
    local distnow=getValue(HomeDistanceId)
    if distnow ~= 0 then
      dist = distnow
    end
  end
  -- guardar lat y lon
  if (GPSId ~= -1) then
    local pos = getValue(GPSId)
    if type(pos) == "table" then
      lat = pos["lat"]
      lon = pos["lon"]
    end
  end
  -- si se cambia bateria por una nueva resetear timer 2
  local v = getVoltage()
  if (v == 0) then
    voltzero = 1
  else
    if (voltzero == 1 and v > voltage + 0.3) then
      model.resetTimer(0)	-- resetear timer 1 (que es el 0 :-P
    end
    voltage = v
    volzero = 0
  end
  -- actualizar el voltaje minimo (si armado)
  -- v tiene el valor del voltaje ya
  if (volmin==0) then	-- si es 0 poneos el actual
    volmin = v
  end
  local armed = getArmed()
  local a = getValue(CurrId)
  if armed == 1 then
    if volminreset == 1 or volmin > v then
       volmin = v
    end
    if volminreset == 1 or currmax < a then
       currmax = a
    end

    volminreset = 0
  else
    volminreset = 1
  end
end


local function init_func()
  -- Called once when model is loaded, only need to get model name once...
  local modeldata = model.getInfo()
  if modeldata then
    modelName = modeldata['name']
  end

  local settings = getGeneralSettings()		-- obtener bateria minima y maxima
  lowVoltage = settings['battMin']
  highVoltage = settings['battMax']

  screen = defaultscreen		-- iniciar en pantalla por defecto

  VoltageSourceId = getTelemetryId('A4')	-- indicadores de telemetría
  GPSId = getTelemetryId("GPS")
  GSpdId = getTelemetryId("GSpd")
  GpsStatusId = getTelemetryId("Tmp2")
  HomeDistanceId = getTelemetryId("0420")
  VFASId = getTelemetryId("VFAS")
  AltId = getTelemetryId("Alt")
  CurrId = getTelemetryId("Curr")
  CelsId = getTelemetryId("Cels")
  FuelId = getTelemetryId("Fuel")
  HdgId = getTelemetryId("Hdg")
  PitchId = getTelemetryId("5230")
  RollId = getTelemetryId("5240")

  ModeId = getTelemetryId("Mode")		-- buscamos primero si hemos renombrado Tmp1 a Mode
  if(ModeId==-1) then				-- y sino buscamos el Tmp1
    ModeId = getTelemetryId("Tmp1")		-- en teoria no se pueden leer varios registros con mismo nombre
  end

  -- constantes (por ejemplo LCD_W) https://opentx.gitbooks.io/opentx-2-2-lua-reference-guide/content/lcd/lcd_functions-overview.html
  MY_LCD_W = LCD_W		-- usamos esto por si queremos probar en X9D como se vería en una X7
end


return { run=run, init=init_func, background=background  }


