//
//  ViewController.h
//  cgms
//
//  Created by Donald Browne on 11/1/14.
//  Copyright (c) 2014 ___FULLUSERNAME___. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

@import CoreBluetooth;
@import QuartzCore;
@import HealthKit;

#define SERVICE_UUID @"2220"
#define CGMS_READ @"2221"
#define CGMS_WRITE @"2222"

@interface ViewController : UIViewController <CBCentralManagerDelegate, CBPeripheralDelegate,UITextFieldDelegate>



@property (nonatomic) HKHealthStore *healthStore;

@property (nonatomic, strong) CBCentralManager *centralManager;
@property (nonatomic, strong) CBPeripheral     *CGMSDevice;

@property (retain, nonatomic) NSURLConnection *connection;

@property (retain, nonatomic) NSMutableData *receivedData;
@property (weak, nonatomic) IBOutlet UITextField *glucoseTxt;
@property (weak, nonatomic) IBOutlet UITextField *glucose;

@property (weak, nonatomic) IBOutlet UIButton *getGlucose;

// Properties for your Object controls
//
@property (nonatomic, strong) IBOutlet UIImageView *heartImage;
@property (nonatomic, strong) IBOutlet UITextView  *deviceInfo;

@property (nonatomic, strong) NSString   *connected;



@property (strong, nonatomic) IBOutlet UITextField *calibrate;
//- (IBAction)calibrationChanged:(id)sender;

@property (weak, nonatomic) IBOutlet UILabel *SensorStatus;
@property (weak, nonatomic) IBOutlet UILabel *WatchStatus;
@property (weak, nonatomic) IBOutlet UITextField *slopeTxt;
@property (weak, nonatomic) IBOutlet UITextField *interceptTxt;
@property (weak, nonatomic) IBOutlet UIWebView *glucoseGraph;

@end

