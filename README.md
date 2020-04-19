# TBS Tango2 Dashboard
A simple lua-based dashboard for the TBS Tango2

# Thank you Farley Farley for the original dashboard !



## Crossfire does not display Average cells values - If it does, please open an issue to make me correct this (not an expert)
By default, you will see the cumulated voltages on the display screen. That means that the battery gauge on the left will display irrelevant informations. If you want to fetch average cells voltage, type `set report_cell_voltage = ON` on Betaflight CLI.

## So, what does it look like ?
### farl.lua
#### default
![](/screenshots/default.bmp)
#### with Drone locator & Power ouput
![](/screenshots/locator-output.bmp)
#### with GPS
![](/screenshots/gps.bmp)

### farllh.lua
![](/screenshots/default-lh.bmp)


## Features
* Battery voltage (numerical and graphical) (graphical will only work correctly if you put `set  report_cell_voltage = ON` on Betaflight CLI.)
* Transmitter battery percentage
* Model name
* Time
* Link Quality
* Signal to noise ratio
* GPS Coordinates
* Power output
* Customized text 
* Flight Timer, perfect for whooping
* ANIMATED QUAD WHEN ARMED!!!

## Update - Template

### Two layouts available
The first as options to display more informations, it's called farl.lua :

I added a (very) light template system : you can edit farl.lua and fill the blank space that is on bottom of the screen with the following options : 
```
-- If you set the GPS, it will no show Rssi Quality & Power ouput in order to keep a readable screen
-- Display the GPS Coordinates of the quad 
local displayGPS = false

-- Display Signal to Noise ratio
local displayRssi = false

-- Display the Tango2 PowerOuput (useful to avoid to fly at 25mw in a bando)
local displayPowerOutput = false

-- Will be displayed only if displayGPS, Rssi and PowerOuput are set to false
local displayFillingText = true
```

You can choose what you want to display ! If everything is set to False, it will be blank as it was.

The second one is a more simple one, but occupying all the space available : it's the farllh.lua

## Author
* Written by Farley Farley - farley <at> neonsurge __dot__ com
* Adapted by Alexandre Santini for Tango2
* From: https://github.com/AndrewFarley/Taranis-XLite-Q7-Lua-Dashboard

## Installing

Download the farl.lua script above and drag it to your radio. You should place this into your /SCRIPTS/TELEMETRY folder.

How to install:

1. Power the Tango2
2. Choose "USB Storage (SD)"
3. Download and copy the script farl.lua or/and farllh.lua to "SCRIPTS/TELEMETRY" on your SD card.
4. Eject the Tango2
5. Power up your transmitter.

If you copied the files correctly, you can now go into the telemetry screen setup page and set up the script as telemetry page.

## Adding the script as a telemetry page
Setting up the script as a telemetry page will enable access at the press of a button.  
1. Click on "Menu" then click on "Page", go to page "12"
2. Click on "None", just right after "Screen 1" (or 2,3,4)
3. Scroll and find "Script", then click to validate
4. Choose farl.lua
5. Click on "Exit"
6. Hold "Page"
7. You can do the same for farllh.lua
8. Ta-da

## Script Editing / Modification Notes
Since not everyone uses the same controller configuration as myself, here's some tips to edit the script for your uses...

1. To change which button arms the dashboard... please change the value of 'sa' to a different input [here](https://github.com/AndrewFarley/Taranis-XLite-Q7-Lua-Dashboard/blob/master/farl.lua#L417)

1. To change to a two-stage arming mechanism, change the above option to a "logical" switch.  Eg: `armed = getValue('ls2')`.  See: [Issue #2](https://github.com/AndrewFarley/Taranis-XLite-Q7-Lua-Dashboard/issues/2)

1. To invert the arming switch to be backwards from how it is (eg: if you are armed when this dashboard says it is disarmed) please modify the code [here](https://github.com/AndrewFarley/Taranis-XLite-Q7-Lua-Dashboard/blob/master/farl.lua#L485).  Typically you'd just invert all the `<` and `>`'s in those two lines related to armed.

1. To change which button sets your mode, please modify [this line](https://github.com/AndrewFarley/Taranis-XLite-Q7-Lua-Dashboard/blob/master/farl.lua#L421) to a different input.

1. To change the name of each mode on the mode switch, please modify [these lines](https://github.com/AndrewFarley/Taranis-XLite-Q7-Lua-Dashboard/blob/master/farl.lua#L462)

1. To setup your handset to do a timer this is a standard OpenTX feature.  You can google how to do this, or see [this](https://github.com/AndrewFarley/Taranis-XLite-Q7-Lua-Dashboard/issues/1#issuecomment-467408335) bug report for more info.

1. For more information on how to program in Lua specifically for OpenTX, please [See Here](https://opentx.gitbooks.io/opentx-2-2-lua-reference-guide/content/)



## Support, etc
* Please feel free to submit issues, feedback, etc. to the gitlab page, or email me!  :)  Any time you guys do, I will try to update this README to include more information for future users.
