# iOSCGMS
BLE CGMS Application

This is a working RFDuino to iOS program.  Should serve as a good example of a BLE program that supports BLE reconnect from the background.  RFDuino stays connected to the iPhone for Days.
Reconnects are automatic.  If the RFDuino is out of range for an extended period (something in excess of 3 minutes) the background process will shut down and you will get a notification.  In that case you'll need to restart the program.



