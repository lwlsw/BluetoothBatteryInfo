#import "BluetoothBatteryInfo.h"

#import <Cephei/HBPreferences.h>

#define DegreesToRadians(degrees) (degrees * M_PI / 180)

UIColor *const GREEN_BATTERY_COLOR = [UIColor colorWithRed: 0.15 green: 0.68 blue: 0.38 alpha: 1.0f];
UIColor *const YELLOW_BATTERY_COLOR = [UIColor colorWithRed: 0.95 green: 0.77 blue: 0.06 alpha: 1.0f];
UIColor *const ORANGE_BATTERY_COLOR = [UIColor colorWithRed: 0.90 green: 0.49 blue: 0.13 alpha: 1.0f];
UIColor *const RED_BATTERY_COLOR = [UIColor colorWithRed: 0.91 green: 0.30 blue: 0.24 alpha: 1.0f];

static int const WINDOW_WIDTH = 95;
static int const WINDOW_HEIGHT = 20;
static int const LABEL_WIDTH = 70;

static double screenWidth;
static double screenHeight;
static UIDeviceOrientation orientationOld;

__strong static id bluetoothBatteryInfoObject;

static HBPreferences *pref;
static BOOL enabled;
static BOOL showOnLockScreen;
static BOOL hideInternalBattery;
static BOOL changeHeadphonesIcon;
static BOOL hideDeviceNameLabel;
static long glyphSize;
static long percentageFontSize;
static BOOL percentageFontBold;
static long nameFontSize;
static BOOL nameFontBold;
static double portraitX;
static double portraitY;
static double landscapeX;
static double landscapeY;
static BOOL followDeviceOrientation;

static unsigned int deviceIndex;

static void orientationChanged()
{
	if(followDeviceOrientation && bluetoothBatteryInfoObject) 
		[bluetoothBatteryInfoObject updateOrientation];
}

static void loadDeviceScreenDimensions()
{
	UIDeviceOrientation orientation = [[UIApplication sharedApplication] _frontMostAppOrientation];
	if(orientation == UIDeviceOrientationLandscapeLeft || orientation == UIDeviceOrientationLandscapeRight)
	{
		screenWidth = [[UIScreen mainScreen] bounds].size.height;
		screenHeight = [[UIScreen mainScreen] bounds].size.width;
	}
	else
	{
		screenWidth = [[UIScreen mainScreen] bounds].size.width;
		screenHeight = [[UIScreen mainScreen] bounds].size.height;
	}
}

@implementation BluetoothBatteryInfo

	- (id)init
	{
		self = [super init];
		if(self)
		{
			@try
			{
				bluetoothBatteryInfoWindow = [[UIWindow alloc] initWithFrame: CGRectMake(0, 0, WINDOW_WIDTH, WINDOW_HEIGHT)];
				[bluetoothBatteryInfoWindow setHidden: NO];
				[bluetoothBatteryInfoWindow setAlpha: 1];
				[bluetoothBatteryInfoWindow _setSecure: YES];
				[bluetoothBatteryInfoWindow setUserInteractionEnabled: YES];
				[[bluetoothBatteryInfoWindow layer] setAnchorPoint: CGPointZero];

				glyphImageView = [[UIImageView alloc] initWithFrame: CGRectMake(0, WINDOW_HEIGHT / 2 - glyphSize / 2, glyphSize, glyphSize)];
				[glyphImageView setContentMode: UIViewContentModeScaleAspectFit];
				[glyphImageView setUserInteractionEnabled: YES];
				[bluetoothBatteryInfoWindow addSubview: glyphImageView];
				
				percentageLabel = [[UILabel alloc] initWithFrame: CGRectMake(glyphSize + 3, 0, LABEL_WIDTH, WINDOW_HEIGHT / 2)];
				[percentageLabel setNumberOfLines: 1];
				[percentageLabel setTextAlignment: NSTextAlignmentLeft];
				[percentageLabel setUserInteractionEnabled: YES];
				[bluetoothBatteryInfoWindow addSubview: percentageLabel];

				deviceNameLabel = [[UILabel alloc] initWithFrame: CGRectMake(glyphSize + 3, WINDOW_HEIGHT / 2, LABEL_WIDTH, WINDOW_HEIGHT / 2)];
				[deviceNameLabel setNumberOfLines: 1];
				[deviceNameLabel setTextAlignment: NSTextAlignmentLeft];
				[deviceNameLabel setUserInteractionEnabled: YES];
				[bluetoothBatteryInfoWindow addSubview: deviceNameLabel];

				[bluetoothBatteryInfoWindow addGestureRecognizer: [[UITapGestureRecognizer alloc] initWithTarget: self action: @selector(updateDeviceWithEffects)]];

				deviceIndex = 0;
				useOriginalGlyph = YES;

				[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(updateDeviceWithoutEffects) name: @"BCBatteryDeviceControllerConnectedDevicesDidChange" object: nil];

				[self updateFrame];

				CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)&orientationChanged, CFSTR("com.apple.springboard.screenchanged"), NULL, 0);
				CFNotificationCenterAddObserver(CFNotificationCenterGetLocalCenter(), NULL, (CFNotificationCallback)&orientationChanged, CFSTR("UIWindowDidRotateNotification"), NULL, CFNotificationSuspensionBehaviorCoalesce);
			}
			@catch (NSException *e) {}
		}
		return self;
	}

	- (void)updateFrame
	{
		[NSObject cancelPreviousPerformRequestsWithTarget: self selector: @selector(_updateFrame) object: nil];
		[self performSelector: @selector(_updateFrame) withObject: nil afterDelay: 0.3];
	}

	- (void)_updateFrame
	{
		if(showOnLockScreen) [bluetoothBatteryInfoWindow setWindowLevel: 1051];
		else [bluetoothBatteryInfoWindow setWindowLevel: 1000];
		
		[self updateGlyphSize];
		[self updateLabelsSize];

		[self updateLabelProperties];

		orientationOld = nil;
		[self updateOrientation];
	}

	- (void)updateLabelProperties
	{
		if(percentageFontBold) [percentageLabel setFont: [UIFont boldSystemFontOfSize: percentageFontSize]];
		else [percentageLabel setFont: [UIFont systemFontOfSize: percentageFontSize]];
		
		if(!hideDeviceNameLabel)
		{
			if(nameFontBold) [deviceNameLabel setFont: [UIFont boldSystemFontOfSize: nameFontSize]];
			else [deviceNameLabel setFont: [UIFont systemFontOfSize: nameFontSize]];
		}
	}

	- (void)updateGlyphSize
	{
		CGRect frame = [glyphImageView frame];
		frame.origin.y = WINDOW_HEIGHT / 2 - glyphSize / 2;
		frame.size.width = glyphSize;
		frame.size.height = glyphSize;
		[glyphImageView setFrame: frame];
	}

	- (void)updateLabelsSize
	{
		CGRect frame = [percentageLabel frame];
		frame.origin.x = glyphSize + 3;
		frame.size.height = hideDeviceNameLabel ? WINDOW_HEIGHT : WINDOW_HEIGHT / 2;
		[percentageLabel setFrame: frame];

		if(hideDeviceNameLabel) [deviceNameLabel setHidden: YES];
		else
		{
			[deviceNameLabel setHidden: NO];

			frame = [deviceNameLabel frame];
			frame.origin.x = glyphSize + 3;
			[deviceNameLabel setFrame: frame];
		}
	}

	- (void)updateOrientation
	{
		if(!followDeviceOrientation)
		{
			CGRect frame = [bluetoothBatteryInfoWindow frame];
			frame.origin.x = portraitX;
			frame.origin.y = portraitY;
			[bluetoothBatteryInfoWindow setFrame: frame];
		}
		else
		{
			deviceOrientation = [[UIApplication sharedApplication] _frontMostAppOrientation];
			if(deviceOrientation == orientationOld)
				return;
			
			CGAffineTransform newTransform;
			CGRect frame = [bluetoothBatteryInfoWindow frame];

			switch(deviceOrientation)
			{
				case UIDeviceOrientationLandscapeRight:
				{
					frame.origin.x = landscapeY;
					frame.origin.y = screenHeight - landscapeX;
					newTransform = CGAffineTransformMakeRotation(-DegreesToRadians(90));
					break;
				}
				case UIDeviceOrientationLandscapeLeft:
				{
					frame.origin.x = screenWidth - landscapeY;
					frame.origin.y = landscapeX;
					newTransform = CGAffineTransformMakeRotation(DegreesToRadians(90));
					break;
				}
				case UIDeviceOrientationPortraitUpsideDown:
				{
					frame.origin.x = screenWidth - portraitX;
					frame.origin.y = screenHeight - portraitY;
					newTransform = CGAffineTransformMakeRotation(DegreesToRadians(180));
					break;
				}
				case UIDeviceOrientationPortrait:
				default:
				{
					frame.origin.x = portraitX;
					frame.origin.y = portraitY;
					newTransform = CGAffineTransformMakeRotation(DegreesToRadians(0));
					break;
				}
			}

			[UIView animateWithDuration: 0.3f animations:
			^{
				[bluetoothBatteryInfoWindow setTransform: newTransform];
				[bluetoothBatteryInfoWindow setFrame: frame];
				orientationOld = deviceOrientation;
			} completion: nil];
		}
	}

	- (void)updatePercentageColor
	{
		if(deviceIndex <= [[[%c(BCBatteryDeviceController) sharedInstance] connectedDevices] count] && currentDevice)
		{
			if([currentDevice isCharging]) percentageLabel.textColor = GREEN_BATTERY_COLOR;
			else if([currentDevice isBatterySaverModeActive]) percentageLabel.textColor = YELLOW_BATTERY_COLOR;
			else if([currentDevice percentCharge] <= 15) percentageLabel.textColor = RED_BATTERY_COLOR;
			else if([currentDevice percentCharge] <= 25) percentageLabel.textColor = ORANGE_BATTERY_COLOR;
			else percentageLabel.textColor = backupColor;
		}
	}

	- (void)updatePercentage
	{
		if(deviceIndex <= [[[%c(BCBatteryDeviceController) sharedInstance] connectedDevices] count] && currentDevice)
		{
			[percentageLabel setText: [NSString stringWithFormat: @"%lld%%", [currentDevice percentCharge]]];
			[self updatePercentageColor];
		}
	}

	- (void)updateDeviceWithEffects
	{
		NSArray *devices = [[%c(BCBatteryDeviceController) sharedInstance] connectedDevices];

		deviceIndex++;
		if(deviceIndex > [devices count] - 1) deviceIndex = hideInternalBattery ? 1 : 0;
		if(deviceIndex > [devices count] - 1) [self resetDeviceValues];
		else
		{
			currentDevice = devices[deviceIndex];

			if(currentDeviceIdentifier && [[currentDevice identifier] isEqualToString: currentDeviceIdentifier])
			{
				UINotificationFeedbackGenerator *gen = [[UINotificationFeedbackGenerator alloc] init];
				[gen prepare];

				CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath: @"position"];
				[animation setDuration: 0.08];
				[animation setRepeatCount: 3];
				[animation setAutoreverses: YES];
				if(deviceOrientation == UIDeviceOrientationPortrait || deviceOrientation == UIDeviceOrientationPortraitUpsideDown || !followDeviceOrientation)
				{
					[animation setFromValue: [NSValue valueWithCGPoint: CGPointMake([bluetoothBatteryInfoWindow center].x - 4, [bluetoothBatteryInfoWindow center].y)]];
					[animation setToValue: [NSValue valueWithCGPoint: CGPointMake([bluetoothBatteryInfoWindow center].x + 4, [bluetoothBatteryInfoWindow center].y)]];
				}
				else
				{
					[animation setFromValue: [NSValue valueWithCGPoint: CGPointMake([bluetoothBatteryInfoWindow center].x, [bluetoothBatteryInfoWindow center].y - 4)]];
					[animation setToValue: [NSValue valueWithCGPoint: CGPointMake([bluetoothBatteryInfoWindow center].x, [bluetoothBatteryInfoWindow center].y + 4)]];
				}
				[[bluetoothBatteryInfoWindow layer] addAnimation: animation forKey: @"position"];

				[gen notificationOccurred: UINotificationFeedbackTypeError];
			}
			else
			{
				UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle: UIImpactFeedbackStyleMedium];
				[gen prepare];

				[CATransaction begin];
				[CATransaction setAnimationDuration: 0.25];
				[CATransaction setAnimationTimingFunction: [CAMediaTimingFunction functionWithName: kCAMediaTimingFunctionEaseInEaseOut]];

				[CATransaction setCompletionBlock:
				^{
					[self loadNewDeviceValues];

					CABasicAnimation *positionAnimation2 = [CABasicAnimation animationWithKeyPath: @"position"];
					if(deviceOrientation == UIDeviceOrientationPortrait || !followDeviceOrientation)
					{
						[positionAnimation2 setFromValue: [NSValue valueWithCGPoint: CGPointMake([bluetoothBatteryInfoWindow center].x + 15, [bluetoothBatteryInfoWindow center].y)]];
						[positionAnimation2 setToValue: [NSValue valueWithCGPoint: CGPointMake([bluetoothBatteryInfoWindow center].x, [bluetoothBatteryInfoWindow center].y)]];
					}
					else if(deviceOrientation == UIDeviceOrientationLandscapeLeft)
					{
						[positionAnimation2 setFromValue: [NSValue valueWithCGPoint: CGPointMake([bluetoothBatteryInfoWindow center].x, [bluetoothBatteryInfoWindow center].y + 15)]];
						[positionAnimation2 setToValue: [NSValue valueWithCGPoint: CGPointMake([bluetoothBatteryInfoWindow center].x, [bluetoothBatteryInfoWindow center].y)]];
					}
					else if(deviceOrientation == UIDeviceOrientationLandscapeRight)
					{
						[positionAnimation2 setFromValue: [NSValue valueWithCGPoint: CGPointMake([bluetoothBatteryInfoWindow center].x, [bluetoothBatteryInfoWindow center].y - 15)]];
						[positionAnimation2 setToValue: [NSValue valueWithCGPoint: CGPointMake([bluetoothBatteryInfoWindow center].x, [bluetoothBatteryInfoWindow center].y)]];
					}
					else
					{
						[positionAnimation2 setFromValue: [NSValue valueWithCGPoint: CGPointMake([bluetoothBatteryInfoWindow center].x - 15, [bluetoothBatteryInfoWindow center].y)]];
						[positionAnimation2 setToValue: [NSValue valueWithCGPoint: CGPointMake([bluetoothBatteryInfoWindow center].x, [bluetoothBatteryInfoWindow center].y)]];
					}
					[positionAnimation2 setDuration: 0.25];
					
					CABasicAnimation *opacityAnimation2 = [CABasicAnimation animationWithKeyPath: @"opacity"];
					[opacityAnimation2 setFromValue: [NSNumber numberWithFloat: 0]];
					[opacityAnimation2 setToValue: [NSNumber numberWithFloat: 1]];
					[opacityAnimation2 setDuration: 0.25];

					CAAnimationGroup *animationGroup2 = [CAAnimationGroup animation];
					[animationGroup2 setDuration: 0.25];
					[animationGroup2 setTimingFunction: [CAMediaTimingFunction functionWithName: kCAMediaTimingFunctionEaseInEaseOut]];
					[animationGroup2 setAnimations: @[positionAnimation2, opacityAnimation2]];
					[[bluetoothBatteryInfoWindow layer] addAnimation: animationGroup2 forKey: @"animationGroup2"];

					[[bluetoothBatteryInfoWindow layer] removeAnimationForKey: @"animationGroup1"];
				}];

				CABasicAnimation *positionAnimation1 = [CABasicAnimation animationWithKeyPath: @"position"];
				if(deviceOrientation == UIDeviceOrientationPortrait || !followDeviceOrientation)
				{
					[positionAnimation1 setFromValue: [NSValue valueWithCGPoint: CGPointMake([bluetoothBatteryInfoWindow center].x, [bluetoothBatteryInfoWindow center].y)]];
					[positionAnimation1 setToValue: [NSValue valueWithCGPoint: CGPointMake([bluetoothBatteryInfoWindow center].x - 15, [bluetoothBatteryInfoWindow center].y)]];
				}
				else if(deviceOrientation == UIDeviceOrientationLandscapeLeft)
				{
					[positionAnimation1 setFromValue: [NSValue valueWithCGPoint: CGPointMake([bluetoothBatteryInfoWindow center].x, [bluetoothBatteryInfoWindow center].y)]];
					[positionAnimation1 setToValue: [NSValue valueWithCGPoint: CGPointMake([bluetoothBatteryInfoWindow center].x, [bluetoothBatteryInfoWindow center].y - 15)]];
				}
				else if(deviceOrientation == UIDeviceOrientationLandscapeRight)
				{
					[positionAnimation1 setFromValue: [NSValue valueWithCGPoint: CGPointMake([bluetoothBatteryInfoWindow center].x, [bluetoothBatteryInfoWindow center].y)]];
					[positionAnimation1 setToValue: [NSValue valueWithCGPoint: CGPointMake([bluetoothBatteryInfoWindow center].x, [bluetoothBatteryInfoWindow center].y + 15)]];
				}
				else
				{
					[positionAnimation1 setFromValue: [NSValue valueWithCGPoint: CGPointMake([bluetoothBatteryInfoWindow center].x, [bluetoothBatteryInfoWindow center].y)]];
					[positionAnimation1 setToValue: [NSValue valueWithCGPoint: CGPointMake([bluetoothBatteryInfoWindow center].x + 15, [bluetoothBatteryInfoWindow center].y)]];
				}
				[positionAnimation1 setDuration: 0.25];
				
				CABasicAnimation *opacityAnimation1 = [CABasicAnimation animationWithKeyPath: @"opacity"];
				[opacityAnimation1 setFromValue: [NSNumber numberWithFloat: 1]];
				[opacityAnimation1 setToValue: [NSNumber numberWithFloat: 0]];
				[opacityAnimation1 setDuration: 0.25];

				CAAnimationGroup *animationGroup1 = [CAAnimationGroup animation];
				[animationGroup1 setDuration: 0.25];
				[animationGroup1 setTimingFunction: [CAMediaTimingFunction functionWithName: kCAMediaTimingFunctionEaseInEaseOut]];
				[animationGroup1 setAnimations: @[positionAnimation1, opacityAnimation1]];
				[animationGroup1 setFillMode: kCAFillModeForwards];
				[animationGroup1 setRemovedOnCompletion: NO];
				[[bluetoothBatteryInfoWindow layer] addAnimation: animationGroup1 forKey: @"animationGroup1"];

				[CATransaction commit];
				
				[gen impactOccurred];
			}
		}
	}

	- (void)updateDeviceWithoutEffects
	{
		NSArray *devices = [[%c(BCBatteryDeviceController) sharedInstance] connectedDevices];
		if(hideInternalBattery && deviceIndex == 0) deviceIndex++;
		if(deviceIndex > [devices count] - 1) deviceIndex = hideInternalBattery ? 1 : 0;
		if(deviceIndex > [devices count] - 1) [self resetDeviceValues];
		else
		{
			currentDevice = devices[deviceIndex];

			if(!currentDeviceIdentifier || ![[currentDevice identifier] isEqualToString: currentDeviceIdentifier])
				[self loadNewDeviceValues];
		}
	}

	- (void)loadNewDeviceValues
	{
		currentDeviceIdentifier = [currentDevice identifier];

		[glyphImageView setImage: [[currentDevice glyph] imageWithRenderingMode: UIImageRenderingModeAlwaysTemplate]];
		if(useOriginalGlyph) [glyphImageView setTintColor: [UIColor whiteColor]];
		else [glyphImageView setTintColor: [UIColor blackColor]];

		[deviceNameLabel setText: [self getDeviceName: [[[currentDevice glyph] imageAsset] assetName]]];
		[self updatePercentage];
	}

	- (void)resetDeviceValues
	{
		currentDevice = nil;
		currentDeviceIdentifier = nil;
		[glyphImageView setImage: nil];
		[percentageLabel setText: @""];
		[deviceNameLabel setText: @""];
	}

	- (void)updateTextColor: (UIColor*)color
	{
		CGFloat r;
    	[color getRed: &r green: nil blue: nil alpha: nil];
		if(r == 0 || r == 1)
		{
			if([glyphImageView image])
			{
				if(r == 0) 
				{
					useOriginalGlyph = NO;
					[glyphImageView setTintColor: [UIColor blackColor]];
				}
				else
				{
					useOriginalGlyph = YES;
					[glyphImageView setTintColor: [UIColor whiteColor]];
				} 
			}

			[deviceNameLabel setTextColor: color];
			backupColor = color;

			[[percentageLabel textColor] getRed: &r green: nil blue: nil alpha: nil];
			if(r == 0 || r == 1)
				[percentageLabel setTextColor: color];
		}
	}

	- (NSString*)getDeviceName: (NSString*)assetName
	{
		if([assetName containsString: @"case"] || [assetName containsString: @"r7x"]) return @"Case";
		else if([assetName containsString: @"iphone"]) return @"iPhone";
		else if(([assetName containsString: @"airpods"] || [assetName containsString: @"b298"]) && [assetName containsString: @"left"] && [assetName containsString: @"right"]) return @"Airpods";
		else if(([assetName containsString: @"airpods"] || [assetName containsString: @"b298"]) && [assetName containsString: @"left"]) return @"L Airpod";
		else if(([assetName containsString: @"airpods"] || [assetName containsString: @"b298"]) && [assetName containsString: @"right"]) return @"R Airpod";
		else if([assetName containsString: @"ipad"]) return @"iPad";
		else if([assetName containsString: @"watch"]) return @"Watch";
		else if([assetName containsString: @"beats"] && [assetName containsString: @"left"] && [assetName containsString: @"right"]) return @"Beats";
		else if([assetName containsString: @"beatspro"] && [assetName containsString: @"left"]) return @"L Beats";
		else if([assetName containsString: @"beatspro"] && [assetName containsString: @"right"]) return @"R Beats";
		else if([assetName containsString: @"beats"] || [assetName containsString: @"b419"] || [assetName containsString: @"b364"]) return @"Beats";
		else if([assetName containsString: @"gamecontroller"]) return @"Controller";
		else if([assetName containsString: @"pencil"]) return @"Pencil";
		else if([assetName containsString: @"ipod"]) return @"iPod";
		else if([assetName containsString: @"mouse"] || [assetName containsString: @"a125"]) return @"Mouse";
		else if([assetName containsString: @"trackpad"]) return @"Trackpad";
		else if([assetName containsString: @"keyboard"]) return @"Keyboard";
		else return @"Uknown";
	}

@end

%hook SpringBoard

- (void)applicationDidFinishLaunching: (id)application
{
	%orig;

	loadDeviceScreenDimensions();
	if(!bluetoothBatteryInfoObject) 
	{
		bluetoothBatteryInfoObject = [[BluetoothBatteryInfo alloc] init];
		[bluetoothBatteryInfoObject updateDeviceWithoutEffects];
	}
}

%end

%hook BCBatteryDevice

-(void)setCharging:(BOOL)arg1
{
	%orig;

	dispatch_async(dispatch_get_main_queue(), ^{ [bluetoothBatteryInfoObject updatePercentageColor]; });
}

-(void)setPercentCharge:(long long)arg1
{
	%orig;

	dispatch_async(dispatch_get_main_queue(), ^{ [bluetoothBatteryInfoObject updatePercentage]; });
}

-(void)setBatterySaverModeActive:(BOOL)arg1
{
	%orig;

	dispatch_async(dispatch_get_main_queue(), ^{ [bluetoothBatteryInfoObject updatePercentageColor]; });
}

%end

%hook _UIStatusBar

-(void)setForegroundColor: (UIColor*)color
{
	%orig;
	
	if(bluetoothBatteryInfoObject && [self styleAttributes] && [[self styleAttributes] imageTintColor]) 
		[bluetoothBatteryInfoObject updateTextColor: [[self styleAttributes] imageTintColor]];
}

%end

%group changeHeadphonesIconGroup

	UIImage* getHeadphonesImage(UIImage *image)
	{
		NSString *glyphName = nil;
		CGSize imgsize = image.size;
		for(BCBatteryDevice *device in [[%c(BCBatteryDeviceController) sharedInstance] connectedDevices])
		{
			if([device.glyph.imageAsset.assetName containsString: @"airpods"]) glyphName = @"batteryglyphs-airpods-left-right";
			else if([device.glyph.imageAsset.assetName containsString: @"b298"]) 
			{
				glyphName = @"batteryglyphs-b298-left-right";
				imgsize = CGSizeMake(imgsize.width * 0.70, imgsize.height);
			}
			else if([device.glyph.imageAsset.assetName containsString: @"b364"]) 
			{
				glyphName = @"batteryglyphs-b364";
				imgsize = CGSizeMake(imgsize.width * 0.65, imgsize.height);
			}
			else if([device.glyph.imageAsset.assetName containsString: @"b419"])
			{
				glyphName = @"batteryglyphs-b419";
				imgsize = CGSizeMake(imgsize.width * 0.88, imgsize.height);

			} 
			else if([device.glyph.imageAsset.assetName containsString: @"beatssolo"])
			{
				glyphName = @"batteryglyphs-beatssolo";
				imgsize = CGSizeMake(imgsize.width * 0.92, imgsize.height);

			} 
			else if([device.glyph.imageAsset.assetName containsString: @"beatsstudio"]) 
			{
				glyphName = @"batteryglyphs-beatsstudio";
				imgsize = CGSizeMake(imgsize.width * 0.92, imgsize.height);
			}
			else if([device.glyph.imageAsset.assetName containsString: @"beatsx"]) 
			{
				glyphName = @"batteryglyphs-beatsx";
				imgsize = CGSizeMake(imgsize.width, imgsize.height * 0.92);
			}
			else if([device.glyph.imageAsset.assetName containsString: @"powerbeatspro"]) 
			{
				glyphName = @"batteryglyphs-powerbeatspro-left-right";
				imgsize = CGSizeMake(imgsize.width, imgsize.height * 0.75);
			}
			else if([device.glyph.imageAsset.assetName containsString: @"powerbeats"]) 
			{
				glyphName = @"batteryglyphs-powerbeats";
				imgsize = CGSizeMake(imgsize.width * 0.75, imgsize.height);
			}
			else if([device.glyph.imageAsset.assetName containsString: @"beats"]) glyphName = @"batteryglyphs-beats";

			if(glyphName) break;
		}
		
		if(glyphName) return [[[[%c(_UIAssetManager) assetManagerForBundle: [NSBundle bundleWithIdentifier: @"com.apple.BatteryCenter"]] imageNamed: glyphName] 
			sbf_resizeImageToSize: imgsize] imageWithRenderingMode: UIImageRenderingModeAlwaysTemplate];
		else return nil;
	}

	%hook UIImage

	+ (UIImage*)_kitImageNamed: (NSString*)name withTrait: (id)trait
	{
		UIImage *newImage;
		if([name containsString: @"BTHeadphones"]) newImage = getHeadphonesImage(%orig);
		
		if(newImage) return newImage;
		else return %orig();
	}

	- (UIImage*)_imageWithImageAsset: (UIImageAsset*)asset
	{
		UIImage *newImage;
		if([asset.assetName isEqualToString: @"headphones"] && [MSHookIvar<NSBundle*>(asset, "_containingBundle").bundleIdentifier isEqualToString: @"com.apple.CoreGlyphs"])
			newImage = getHeadphonesImage(%orig);
		
		if(newImage) return newImage;
		else return %orig();
	}

	%end

	%hook UIStatusBarIndicatorItemView

	- (UIImageView*)contentsImage
	{
		UIImage *newImage;
		UIImageView *imageView = %orig;
		if([self.item.indicatorName isEqualToString: @"BTHeadphones"] || [NSStringFromClass(self.item.viewClass) containsString: @"Bluetooth"])
			newImage = getHeadphonesImage(imageView.image);

		if(newImage) imageView.image = newImage;
		return imageView;
	}

	- (BOOL)shouldTintContentImage
	{
		if([self.item.indicatorName isEqualToString: @"BTHeadphones"] || [NSStringFromClass(self.item.viewClass) containsString: @"Bluetooth"])
			return true;
		return %orig;
	}

	%end

	%hook _UIStatusBarImageView

	- (UIImage*)image
	{
		return [%orig imageWithRenderingMode: UIImageRenderingModeAlwaysTemplate];
	}

	%end

%end

static void settingsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	if(!pref) pref = [[HBPreferences alloc] initWithIdentifier: @"com.johnzaro.bluetoothbatteryinfoprefs"];
	enabled = [pref boolForKey: @"enabled"];
	showOnLockScreen = [pref boolForKey: @"showOnLockScreen"];
	hideInternalBattery = [pref boolForKey: @"hideInternalBattery"];
	hideDeviceNameLabel = [pref boolForKey: @"hideDeviceNameLabel"];
	glyphSize = [pref integerForKey: @"glyphSize"];
	percentageFontSize = [pref integerForKey: @"percentageFontSize"];
	percentageFontBold = [pref boolForKey: @"percentageFontBold"];
	nameFontSize = [pref integerForKey: @"nameFontSize"];
	nameFontBold = [pref boolForKey: @"nameFontBold"];
	portraitX = [pref floatForKey: @"portraitX"];
	portraitY = [pref floatForKey: @"portraitY"];
	landscapeX = [pref floatForKey: @"landscapeX"];
	landscapeY = [pref floatForKey: @"landscapeY"];
	followDeviceOrientation = [pref boolForKey: @"followDeviceOrientation"];

	if(bluetoothBatteryInfoObject)
	{
		[bluetoothBatteryInfoObject updateFrame];
		[bluetoothBatteryInfoObject updateDeviceWithoutEffects];
	}
}

%ctor
{
	@autoreleasepool
	{
		pref = [[HBPreferences alloc] initWithIdentifier: @"com.johnzaro.bluetoothbatteryinfoprefs"];
		[pref registerDefaults:
		@{
			@"enabled": @NO,
			@"showOnLockScreen": @NO,
			@"hideInternalBattery": @NO,
			@"changeHeadphonesIcon": @NO,
			@"hideDeviceNameLabel": @NO,
			@"glyphSize": @20,
			@"percentageFontSize": @10,
			@"percentageFontBold": @NO,
			@"nameFontSize": @8,
			@"nameFontBold": @NO,
			@"portraitX": @165,
			@"portraitY": @32,
			@"landscapeX": @735,
			@"landscapeY": @32,
			@"followDeviceOrientation": @NO,
    	}];

		settingsChanged(NULL, NULL, NULL, NULL, NULL);

		if(enabled)
		{
			CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, settingsChanged, CFSTR("com.johnzaro.bluetoothbatteryinfoprefs/reloadprefs"), NULL, CFNotificationSuspensionBehaviorCoalesce);

			changeHeadphonesIcon = [pref boolForKey: @"changeHeadphonesIcon"];
			if(changeHeadphonesIcon) %init(changeHeadphonesIconGroup);
			%init;
		}
	}
}