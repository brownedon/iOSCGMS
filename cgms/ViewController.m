@import AudioToolbox;
#import "ViewController.h"
#import <PebbleKit/PebbleKit.h>

@interface ViewController ()


@property (nonatomic) UIBackgroundTaskIdentifier backgroundTask;

@end

@implementation ViewController

static CBUUID *send_uuid;
static CBUUID *receive_uuid;
CBCharacteristic *send_characteristic;

NSString *cgms = @"CGMS MICRO";
//NSString *cgms = @"CGMS1";

static int GLUCOSE=0x01;
static int GLUCOSE_FILT=0x02;
static int RAWCOUNT=0x03;
static int RAWCOUNT_FILT=0x04;
static int SLOPE=0x05;
static int INTERCEPT=0x06;
static int BTLE_BATTERY=0x07;
static int BTLE_RSSI=0x08;
static int TRANSMITTER_ID=0x09;
static int TRANSMITTER_BATTERY=0x0A;
static int TRANSMITTER_RSSI=0x0B;
static int SECONDS_SINCE_READING=0x0C;
static int CAL_GLUCOSE=0x0D;
static int NEW_SENSOR=0x0E;
static int TRANSMITTER_FULL_PACKET=0x0F;
static int RESET=0x10;

NSDictionary *update;

//arrows
static int ARROW_45_UP = 0x01;
static int ARROW_UP = 0x02;
static int ARROW_UP_UP = 0x03;
static int ARROW_45_DOWN = 0x04;
static int ARROW_DOWN = 0x05;
static int ARROW_DOWN_DOWN = 0x06;
int firstTime=TRUE;
int alertCount=0;
int vibCount=0;
int glucInt=0;
static int SLOPE_DOWN = 0x01;
static int SLOPE_UP = 0x02;
NSTimer *timer;
long lastReadingTime=0;
int timeInterval=5;
int pebbleConnected=0;
PBWatch *_targetWatch;
long long recordID;
long rawcount=0;
int loopCount=0;
int sensorConnected=0;
id updateHandler;
NSURLRequest *requestObj;

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    NSLog(@"viewDidLoad");
    
    self.glucose.text = @"0";
    
    [self.WatchStatus setTextColor:[UIColor redColor]];
    [self.SensorStatus setTextColor:[UIColor redColor]];
    
    // We'd like to get called when Pebbles connect and disconnect, so become the delegate of PBPebbleCentral:
    [[PBPebbleCentral defaultCentral] setDelegate:self];
    
    //pebble
    [self setTargetWatch:[[PBPebbleCentral defaultCentral] lastConnectedWatch]];
    
    self.backgroundTask = UIBackgroundTaskInvalid;
    
    self.backgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        NSLog(@"Background handler called. Not running background tasks anymore.");
        NSDate* now = [NSDate date];
        [self scheduleAlarmForDate:(now) : (@"Sensor is disconnected")];
        CBCentralManager *centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
        self.centralManager = centralManager;
        [[UIApplication sharedApplication] endBackgroundTask:self.backgroundTask];
        self.backgroundTask = UIBackgroundTaskInvalid;
        
        NSLog(@"finished running background task");    }];
    
    //this allows the applicaiton to ask if it can alert you
    UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeBadge categories:nil];
    [[UIApplication sharedApplication] registerUserNotificationSettings:settings];
    

    
    // Scan for all available CoreBluetooth LE devices
    CBCentralManager *centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
  	self.centralManager = centralManager;
    
    NSString *fullURL = @"http://someurl";
    NSURL *url = [NSURL URLWithString:fullURL];
    requestObj = [NSURLRequest requestWithURL:url];
    [self.glucoseGraph loadRequest:requestObj];
    [NSTimer scheduledTimerWithTimeInterval:5 target:(self) selector:@selector(requestGlucose) userInfo:nil repeats:NO];
    [NSTimer scheduledTimerWithTimeInterval:60 target:(self) selector:@selector(requestGlucose) userInfo:nil repeats:YES];
}


//
- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    NSLog(@"didReceiveMemoryWarning");
    // Dispose of any resources that can be recreated.
}

#pragma mark - CBCentralManagerDelegate

// CBCentralManagerDelegate - This is called with the CBPeripheral class as its main input parameter. This contains most of the information there is to know about a BLE peripheral.
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    NSLog(@"didDiscoverPeripheral");
    
    NSString *localName = [advertisementData objectForKey:CBAdvertisementDataLocalNameKey];

    NSLog(localName);
    if ([localName isEqualToString:(cgms)]) {
        NSLog(@"Found the CGMS: %@", localName);
        [self.centralManager stopScan];
        self.CGMSDevice = peripheral;
        peripheral.delegate = self;
        [self.centralManager connectPeripheral:peripheral options:nil];
        
    }
}


// method called whenever you have successfully connected to the BLE peripheral
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    NSLog(@"didConnectPeripheral");
    [peripheral setDelegate:self];
    [peripheral discoverServices:nil];

    self.connected = [NSString stringWithFormat:@"Sensor Connected: %@", peripheral.state == CBPeripheralStateConnected ? @"YES" : @"NO"];
    
    NSLog(@"%@", self.connected);
}


-(void)requestGlucose
{
    NSLog(@"requestGlucose");
    if(sensorConnected){
        NSLog(@"sensorConnected");
        uint16_t tx[1];
        tx[0] = GLUCOSE;
        
        NSData *data = [NSData dataWithBytes:(void*)&tx length:1];
    	
        [self.CGMSDevice writeValue:data forCharacteristic:send_characteristic type:CBCharacteristicWriteWithoutResponse];
    }else{
         NSLog(@"sensorDisConnected");
        if(firstTime){
            NSLog(@"scan");
            [self.centralManager scanForPeripheralsWithServices:nil options:nil];
        }else{
            NSLog(@"connect directly");
            [self.centralManager connectPeripheral:self.CGMSDevice options:nil];
        }
    }
    
}

-(void)requestBattery
{
    NSLog(@"requestBattery");
    if(sensorConnected){

        uint16_t tx[1];
        tx[0] = BTLE_BATTERY;
        
        NSData *data = [NSData dataWithBytes:(void*)&tx length:1];
        
        [self.CGMSDevice writeValue:data forCharacteristic:send_characteristic type:CBCharacteristicWriteWithoutResponse];
    }
    
}


-(void)requestRawcount
{
    NSLog(@"requestRawcount");
    uint16_t tx[1];
    tx[0] = RAWCOUNT;
    
    NSData *data = [NSData dataWithBytes:(void*)&tx length:1];
    
    [self.CGMSDevice writeValue:data forCharacteristic:send_characteristic type:CBCharacteristicWriteWithoutResponse];

}

-(void)requestSlope
{
    NSLog(@"requestSlope");
    
    uint16_t tx[1];
    tx[0] = SLOPE;
    
    NSData *data = [NSData dataWithBytes:(void*)&tx length:1];
    
    [self.CGMSDevice writeValue:data forCharacteristic:send_characteristic type:CBCharacteristicWriteWithoutResponse];
    
}


-(void)requestIntercept
{
    NSLog(@"requestIntercept");
    
    uint16_t tx[1];
    tx[0] = INTERCEPT;
    
    NSData *data = [NSData dataWithBytes:(void*)&tx length:1];
    
    [self.CGMSDevice writeValue:data forCharacteristic:send_characteristic type:CBCharacteristicWriteWithoutResponse];
    
}

//pebble
- (void)setTargetWatch:(PBWatch*)watch {
    NSLog(@"setTargetWatch");
    _targetWatch = watch;
    
    [watch appMessagesGetIsSupported:^(PBWatch *watch, BOOL isAppMessagesSupported) {
        if (isAppMessagesSupported) {
            uint8_t bytes[] = {0x7f, 0x7a, 0x38, 0x90, 0x1a, 0x1c, 0x43, 0xa3, 0xad, 0xF1, 0x21, 0x44, 0x9e, 0x4f, 0x35, 0x2d};
            
            NSData *uuid = [NSData dataWithBytes:bytes length:sizeof(bytes)];
            [[PBPebbleCentral defaultCentral] setAppUUID:uuid];
            
            NSLog(@"Connected to Pebble");
             [self.WatchStatus setTextColor:[UIColor blackColor]];
        } else {
            
            NSString *message = [NSString stringWithFormat:@"Blegh... %@ does NOT support AppMessages :'(", [watch name]];
            [[[UIAlertView alloc] initWithTitle:@"Connected..." message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
        }
    }];
    
}


/*
 *  PBPebbleCentral delegate methods
 */

- (void)pebbleCentral:(PBPebbleCentral*)central watchDidConnect:(PBWatch*)watch isNew:(BOOL)isNew {
    NSLog(@"watchDidConnect");
    [self setTargetWatch:watch];
    
    [self.WatchStatus setTextColor:[UIColor blackColor]];
}

- (void)pebbleCentral:(PBPebbleCentral*)central watchDidDisconnect:(PBWatch*)watch {
    NSLog(@"watchDidDiconnect");
        [self.WatchStatus setTextColor:[UIColor redColor]];
}


- (void)closeSession {
     NSLog(@"closeSession(Watch).");
    [_targetWatch closeSession:^{
        NSLog(@"Session closed.");
    }];
    [self.WatchStatus setTextColor:[UIColor redColor]];
}

//
//
//


- (void)glucoseAlert:(NSTimer *)incomingTimer{
     NSLog(@"glucoseAlert");
    vibCount--;
    NSLog(@"vibcount %i",vibCount);
    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
    if(vibCount<=0){
        [timer invalidate];
    }
}

- (void)postData {
     NSLog(@"postData(Glucose).");
    //initialize new mutable data
    NSMutableData *data = [[NSMutableData alloc] init];
    self.receivedData = data;
    
    //initialize url that is going to be fetched.
    NSString *tmp=[NSString stringWithFormat:@"someurl",glucInt,rawcount,recordID];
    
    NSURL *url = [NSURL URLWithString:tmp];
    // [NSString stringWithFormat:@"%ld", lastReading]
    
    //initialize a request from url
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    
    //initialize a connection from request
    NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
    self.connection = connection;
    
    //start the connection
    [connection start];
}




-(void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data{
    [self.receivedData appendData:data];
}
/*
 if there is an error occured, this method will be called by connection
 */
-(void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error{
    
    NSLog(@"%@" , error);
}

/*
 if data is successfully received, this method will be called by connection
 */
-(void)connectionDidFinishLoading:(NSURLConnection *)connection{
    
    //initialize convert the received data to string with UTF8 encoding
    NSString *htmlSTR = [[NSString alloc] initWithData:self.receivedData
                                              encoding:NSUTF8StringEncoding];
    NSLog(@"%@" , htmlSTR);
    
}


// method called whenever the device state changes.
- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    switch (central.state)
    {
        case CBCentralManagerStateUnsupported:
        {
            NSLog(@"State: Unsupported");
        } break;
            
        case CBCentralManagerStateUnauthorized:
        {
            NSLog(@"State: Unauthorized");
        } break;
            
        case CBCentralManagerStatePoweredOff:
        {
            NSLog(@"State: Powered Off");
        } break;
            
        case CBCentralManagerStatePoweredOn:
        {
            NSLog(@"State: Powered On");

        } break;
            
        case CBCentralManagerStateUnknown:
        {
            NSLog(@"State: Unknown");
        } break;
            
        default:
        {
        }
            
    }
}



#pragma mark - CBPeripheralDelegate

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    NSLog(@"didDiscoverServices");

    for (CBService *service in peripheral.services) {
        NSLog(@"Discovered service: %@", service.UUID);
        [peripheral discoverCharacteristics:nil forService:service];
    }
}

// Invoked when you discover the characteristics of a specified service.
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    NSLog(@"didDiscoverCharacteristicsForService");
    //
    if ([service.UUID isEqual:[CBUUID UUIDWithString:SERVICE_UUID]])  {  // 1
        for (CBCharacteristic *aChar in service.characteristics)
        {
            if ([aChar.UUID isEqual:[CBUUID UUIDWithString:CGMS_READ]]) { // 2
                [self.CGMSDevice setNotifyValue:YES forCharacteristic:aChar];
                NSLog(@"Found CGMS_READ characteristic");
            }
            if ([aChar.UUID isEqual:[CBUUID UUIDWithString:CGMS_WRITE]]) { // 2
                [self.CGMSDevice setNotifyValue:YES forCharacteristic:aChar];
                NSLog(@"Found CGMS_WRITE characteristic");
                sensorConnected=1;
                send_characteristic = aChar;

                [self.SensorStatus setTextColor:[UIColor blackColor]];
                //connected now start the job
              
                // call it directly also so we don't have to wait for a minute
                [self requestGlucose];
            }
        }
    }
}

// Invoked when you retrieve a specified characteristic's value, or when the peripheral device notifies your app that the characteristic's value has changed.
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    NSLog(@"DidUpdateValueForCharacteristic");
    
    // Updated value for heart rate measurement received
    // this is a read of anything.
    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:CGMS_READ]]) { // 1
        [self getBTLEData:characteristic error:error];
    }
}

#pragma mark - CBCharacteristic helpers



// Instance method to get the heart rate BPM information
- (void) getBTLEData:(CBCharacteristic *)characteristic error:(NSError *)error
{
    NSLog(@"getBTLEData");
    NSData *data = [characteristic value];      // 1
    const uint8_t *value = [data bytes];
    NSDate *date = [NSDate date];
    recordID= [@(floor([date timeIntervalSince1970])) longLongValue];

    
    if(value[0]==SLOPE){
        int slope = value[1] | value[2] << 8;
        NSString* slopeStr = [NSString stringWithFormat:@"%i", slope];
        self.slopeTxt.text=slopeStr;
        NSLog(@"slope = %i", slope);
        
    }
    
    
    if(value[0]==INTERCEPT){
        long intercept = ( (value[1] << 24)
                         + (value[2] << 16)
                         + (value[3] << 8)
                         + (value[4] ) );
        NSLog(@"Last reading = %li", intercept);
        NSString* interceptStr = [NSString stringWithFormat:@"%li", intercept];
        self.interceptTxt.text=interceptStr;
        
    }

    if(value[0]==RAWCOUNT){
        long rawcount = ( (value[1] << 24)
                         + (value[2] << 16)
                         + (value[3] << 8)
                         + (value[4] ) );
        NSLog(@"Last reading = %li", rawcount);
        
    }
    
    if(value[0]==BTLE_BATTERY){
        int number = value[1] | value[2] << 8;
        NSString* battery = [NSString stringWithFormat:@"%i", number];
        NSLog(@"Battery %i",battery);
    }
    
    //
    //
    
    if(value[0]==GLUCOSE){
        int number = value[1] | value[2] << 8;
        NSString* gluc = [NSString stringWithFormat:@"%i", number];
        self.glucose.text=gluc;
        glucInt=number;
        int ARROW=value[3];
        int SLOPEDIRECTION=value[4];
        int TIMETOLIMIT=value[5];
        
        long lastReading = ( (value[6] << 24)
                            + (value[7] << 16)
                            + (value[8] << 8)
                            + (value[9] ) );
        
        rawcount = ( (value[10] << 24)
                    + (value[11] << 16)
                    + (value[12] << 8)
                    + (value[13] ) );
        
        NSLog(@"Arrow = %i", ARROW);
        NSLog(@"Slope Direction = %i", SLOPEDIRECTION);
        NSLog(@"Time To Limit = %i", TIMETOLIMIT);
        NSLog(@"Last reading = %li", lastReading);
        NSLog(@"Last rawcount = %li", rawcount);
        
        //Get current time
        NSDate* now = [NSDate date];
        NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
        NSDateComponents *dateComponents = [gregorian components:(NSHourCalendarUnit  | NSMinuteCalendarUnit | NSSecondCalendarUnit) fromDate:now];
        NSInteger hour = [dateComponents hour];
        NSString *am_OR_pm=@"AM";

        //based on glucose
        //send alerts if things are critical
        //if time between 10pm and 8am have the phone do a notification for low and high blood sugar
        //
        
        //new glucose value  should be every 5 minutes
        if(hour>21 || hour< 8){
            if(lastReadingTime!=lastReading){
                //for rapid rise or fall notify every time it occurs
                if(ARROW==ARROW_DOWN_DOWN){
                    vibCount=3;
                    timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self
                                                           selector:@selector(glucoseAlert:) userInfo:nil repeats:YES];
                }
                
                if(ARROW==ARROW_UP_UP){
                    vibCount=3;
                    timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self
                                                           selector:@selector(glucoseAlert:) userInfo:nil repeats:YES];
                }
                
                //
                if (number<80 && alertCount==0 && number>60){
                    vibCount=5;
                    timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self
                                                           selector:@selector(glucoseAlert:) userInfo:nil repeats:YES];
                }
                
                if(number<80 && alertCount>0 && number>60){
                    alertCount++;
                    if(alertCount==3){
                        alertCount=0;
                    }
                }
                
                if (number<60 && alertCount==0){
                    alertCount++;
                    vibCount=10;
                    timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self
                                                           selector:@selector(glucoseAlert:) userInfo:nil repeats:YES];
                    
                }
                if(number<60 && alertCount>0){
                    alertCount++;
                    if(alertCount>2){
                        alertCount=0;
                    }
                }
                
                if(number>180 && alertCount==0)
                {
                    vibCount=5;
                    alertCount++;
                    timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self
                                                           selector:@selector(glucoseAlert:) userInfo:nil repeats:YES];
                }
                
                if(number>180 && alertCount>0){
                    alertCount++;
                    if(alertCount==24){
                        alertCount=0;
                    }
                }
                
                if(number>80 &&number<180){
                    alertCount=0;
                }
            }
        }
        
        
        NSNumber *glucoseKey = @(1);
        NSNumber *arrowKey = @(2);
        NSNumber *slopeDirectionKey = @(3);
        NSNumber *timetolimitKey = @(4);
        NSNumber *lastreadingKey = @(5);
        
        NSString *arrow_str=@" ";
        if (ARROW==ARROW_DOWN){
            arrow_str=@"V";
        }
        
        if (ARROW==ARROW_DOWN_DOWN){
            arrow_str=@"VV";
        }
        
        if (ARROW==ARROW_45_DOWN){
            arrow_str=@"\\";
        }
        
        if (ARROW==ARROW_UP){
            arrow_str=@"^";
        }
        
        if (ARROW==ARROW_UP_UP){
            arrow_str=@"^^";
        }
        
        if (ARROW==ARROW_45_UP){
            arrow_str=@"/";
        }
        
        char slope_ch=' ';
        if (SLOPEDIRECTION==SLOPE_DOWN){
            slope_ch='V';
        }
        
        if (SLOPEDIRECTION==SLOPE_UP){
            slope_ch='^';
        }
        ;
        
        
       // timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self
       //                                        selector:@selector(glucoseAlert:) userInfo:nil repeats:YES];
        
       //[self scheduleAlarmForDate:(now) : (@"You are low")];
        
        NSLog(@"reading %ld:%ld",lastReading,lastReadingTime);
        NSLog(@"firstTime %i",firstTime);
        
        if(firstTime) {
            timeInterval=30;
        }else{
            timeInterval=60;
        }

        
        if(TIMETOLIMIT>99){
            TIMETOLIMIT=0;
        }
        
        if(lastReading!=lastReadingTime){
            if(lastReadingTime>0){
                loopCount=2;
            }
            lastReadingTime=lastReading;
            [self postData];
            [self.glucoseGraph loadRequest:requestObj];
        }
        
        
        NSLog(@"%d  %@   	%c%d", number,arrow_str,slope_ch,TIMETOLIMIT);
        
        
        update = @{glucoseKey:[NSNumber numberWithInt:number],
                   arrowKey:[NSNumber numberWithUint8:ARROW],
                   slopeDirectionKey:[NSNumber numberWithUint8: SLOPEDIRECTION],
                   timetolimitKey:[NSNumber numberWithInt:TIMETOLIMIT],
                   lastreadingKey:[NSString stringWithFormat:@"%ld", lastReading]
                   };
        
        if(!firstTime){
            NSLog(@"Attempt watch update");
            __block NSString *message = @"";
            
            [_targetWatch appMessagesPushUpdate:update onSent:^(PBWatch *watch, NSDictionary *update, NSError *error) {
                message = error ? [error localizedDescription] : @"Update sent!";
                NSLog(message);
                NSLog(@"Done with Glucose");
            }];
        }
        self.glucoseTxt.text=gluc;
        firstTime=FALSE;

    }
    
    return;
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSLog(@"didFailToConnectPeripheral");

    [self.SensorStatus setTextColor:[UIColor redColor]];
    sensorConnected=0;
    
}



- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
     NSLog(@"didDisconnectPeripheral");


    [self.SensorStatus setTextColor:[UIColor redColor]];
    sensorConnected=0;
}

#pragma mark - Writing HealthKit Data

- (void)addGlucoseVal{
    // Create a new food correlation for the given food item.
   // HKCorrelation *foodCorrelationForFoodItem = [self foodCorrelationForFoodItem:foodItem];
    //HKCorrelation
    
    //[self.healthStore saveObject:<#(HKObject *)#> withCompletion:<#^(BOOL success, NSError *error)completion#>
    
   // [self.healthStore saveObject:foodCorrelationForFoodItem withCompletion:^(BOOL success, NSError *error) {
    //    dispatch_async(dispatch_get_main_queue(), ^{
     //       if (success) {
     //           [self.foodItems insertObject:foodItem atIndex:0];
                
      //          NSIndexPath *indexPathForInsertedFoodItem = [NSIndexPath indexPathForRow:0 inSection:0];
      //
       //         [self.tableView insertRowsAtIndexPaths:@[indexPathForInsertedFoodItem] withRowAnimation:UITableViewRowAnimationAutomatic];
       //     }
       //     else {
       //         NSLog(@"An error occured saving the food %@. In your app, try to handle this gracefully. The error was: %@.", foodItem.name, error);
       //
       //         abort();
       //     }
       // });
   // }];
}

- (void)scheduleAlarmForDate:(NSDate*)theDate:(NSString*)msg
{
    UIApplication* app = [UIApplication sharedApplication];
    NSArray*    oldNotifications = [app scheduledLocalNotifications];
    
    // Clear out the old notification before scheduling a new one.
    if ([oldNotifications count] > 0)
        [app cancelAllLocalNotifications];
    
    // Create a new notification.
    UILocalNotification* alarm = [[UILocalNotification alloc] init];
    NSLog(@"In Alert");
    if (alarm)
    {
        alarm.fireDate = theDate;
        alarm.timeZone = [NSTimeZone defaultTimeZone];
        alarm.repeatInterval = 0;
        alarm.soundName = @"alarmsound.caf";
        alarm.alertBody = msg;
        
        [app scheduleLocalNotification:alarm];
    }
}


- (BOOL)textFieldShouldReturn:(UITextField *)textField
{

    NSLog(@"You entered %@",self.calibrate.text);
    [self.calibrate resignFirstResponder];
    int calValue=[self.calibrate.text intValue];

    if(sensorConnected){

        
        if(calValue>60 && calValue<220){
            NSLog(@"Calibrate");
            uint8_t tx[3];
            
            tx[0] = CAL_GLUCOSE;
            tx[1] = (Byte) (calValue & 0xFF);
            tx[2] = (Byte) ((calValue >> 8) & 0xFF);
            
            NSData *data = [NSData dataWithBytes:(void*)&tx length:3];
        
            [self.CGMSDevice writeValue:data forCharacteristic:send_characteristic type:CBCharacteristicWriteWithoutResponse];
            

        }
        
    }
    
    self.calibrate.text=@"";
    [self requestSlope];
    [self requestIntercept];
    [self requestGlucose];
    return YES;
}
@end
