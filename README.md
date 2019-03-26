# Taranis-XLite-Q7-Lua-Dashboard
A simple lua-based dashboard for the OpenTX XLite/QX7 Transmitters

A cool review and overview and howto video by a fellow user
[![](http://img.youtube.com/vi/ijMYaCudgWI/0.jpg)](http://www.youtube.com/watch?v=ijMYaCudgWI "Farleys Lua Dashboard - by DroneRacer101")

## Features
* Battery voltage (numerical and graphical)
* Transmitter battery percentage
* Model name
* Time
* RSSI (graphical and icon (top right))
* Flight Timer, perfect for whooping
* ANIMATED QUAD WHEN ARMED!!!

## Author
* Written by Farley Farley - farley <at> neonsurge __dot__ com
* From: https://github.com/AndrewFarley/Taranis-XLite-Q7-Lua-Dashboard

## Installing

Download the farl.lua script above and drag it to your radio. You should place this into your /SCRIPTS/TELEMETRY folder.

How to install:

Bootloader Method
1. Power off your transmitter and power it back on in boot loader mode.
2. Connect a USB cable and open the SD card drive on your computer.
3. Download and copy the the scripts to appropriate location on your SD card.  NOTE: If the folders do not exist, create them.
4. Unplug the USB cable and power cycle your transmitter.

Manual method (varies, based on the model of your transmitter)
1. Power off your transmitter.
2. Remove the SD card and plug it into a computer
3. Download and copy the the scripts to appropriate location on your SD card.  NOTE: If the folders do not exist, create them.
4. Reinsert your SD card into the transmitter
5. Power up your transmitter.

If you copied the files correctly, you can now go into the telemetry screen setup page and set up the script as telemetry page.

## Adding the script as a telemetry page
Setting up the script as a telemetry page will enable access at the press of a button.  These instructions are for the XLite.  The Q7 will also work but the instructions will be a bit different.
1. Hold the circular eraser D-Pad on the right side of the controller to the right until the Model Selection Menu Comes up
1. Press the eraser to the left briefly to rotate to page 13/13 (top right)
1. Press the eraser to the bottom position to select the first screen (which should say none)
1. Press down on the eraser so the "None" is flashing
1. Press right on the eraser repeatedly until it goes to "Script", then press down on the eraser to confirm.
1. Press right on the eraser to select which script, then press down on the eraser should bring up a menu, and "farl" should be in there, select it and press down on the eraser.
1. Press the bottom button to back out to the main menu.
1. From now on, while on the main menu with this model, simply move the eraser to the bottom position for about 2 seconds and it will activate your first telemetry screen!

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
