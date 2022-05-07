# Auspex Gate Systems Dialing Program
### 0.8.16:
* Compatibility fix for updated Universe Stargates
### 0.8.5:
* Added ability to turn on or off admin only access for various functions of the dialer.
* Fixed issues with using a DHD or handheld dialer to input gate addresses.
* Added ability for computer to use DHD to dial.
* Various bug fixes and performance adjustments.
### 0.7.1:
* Added basic security via an admin list. Located at /ags/adminList.txt
* Each player name in the adminList.txt file must be on its own separate line.
* Only players whose name is on the list will be able to edit Gate Entries, add new Entries, change Settings, and Quit the program.
* All other users will be denied access to the mentioned functions.
### 0.7.0: IDC Update
* Added IDC functionality. You can now assign an IDC to your gate, as well as set whether the Iris/Shield should auto close. IDC can also be received by network messages. These options can be changed in the settings menu.
* Added 'Settings' menu tab, located next the the 'This Stargate's Addresses'.
* Gate Entries can be given an IDC, and will auto send their IDC when dialing.
* Changes to the UI when editing a Gate Entry.
* Various minor performance tweaks.
### 0.6.4:
* Added Dialing History
* Added ability to tag favorite address entries
* Added ability to move the position of address entries
### 0.6.3:
* Added support of Pegasus Stargates
### 0.6.1:
* Adjusted Alteran signal decoding, again
* Dial button becomes gray if gate is busy
* Hopefully stopped the Ori Priors from meddling with 'Orion'
* Adjust some timing to accommodate AUNIS 1.9.8
### 0.6.0:
* Images of the dialed glyph will now show on screen when dialing
* Adjusted the phase of Alteran signal decoding, to improve duplex communication
### 0.5.1:
* Added encoding traces to Stargate Ring Display.
* Relocated position of some buttons.
* Fixed bugs with manual address entry and handheld dialer address entry
* Hopefully fixed 'Orion' showing as 'Urion' on some systems
### 0.5.0:
* Added 'Smart Dialing' System, which dials only the needed glyphs to make a connection.
* Added Stargate Ring Display
* Added Touch Screen Mode Toggle 'F4'

# Auspex Gate Systems Launcher
### 1.1.14:
* Removed access to dev mode, due to abuse
### 1.1.13:
* AGS logo will no longer scroll with text
### 1.1.7:
* Added kiosk mode, and is ran when using the command argument '-k'.
* Kiosk mode will force the dialing program to auto restart if it exits or crashes.
### 1.1.4:
* Fixed Crash from unicode error
### 1.1.0:
* Added a backup to floppy utility which can be found in the '/ags' directory