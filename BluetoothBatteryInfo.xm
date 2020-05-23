#import "BluetoothBatteryInfo.h"
#import "SparkAppList.h"
#import "SparkColourPickerUtils.h"
#import <Cephei/HBPreferences.h>

#define DegreesToRadians(degrees) (degrees * M_PI / 180)

static double screenWidth;
static double screenHeight;
static UIDeviceOrientation orientationOld;

__strong static id bluetoothBatteryInfoObject;

static double windowWidth;
static double windowHeight;
static double labelsHeight;
static int margin;

static HBPreferences *pref;
static BOOL enabled;
static BOOL showOnLockScreen;
static BOOL hideOnLandscape;
static BOOL hideInternalBattery;
static BOOL hideGlyph;
static BOOL dynamicHeadphonesIcon;
static BOOL hideDeviceNameLabel;
static BOOL showPercentSymbol;
static long glyphSize;
static BOOL enableGlyphCustomTintColor;
static UIColor *glyphCustomTintColor;
static long percentageFontSize;
static BOOL percentageFontBold;
static long nameFontSize;
static BOOL nameFontBold;
static BOOL backgroundColorEnabled;
static float backgroundCornerRadius;
static BOOL customBackgroundColorEnabled;
static UIColor *customBackgroundColor;
static BOOL enableCustomDeviceNameColor;
static UIColor *customDeviceNameColor;
static double portraitX;
static double portraitY;
static double landscapeX;
static double landscapeY;
static BOOL followDeviceOrientation;
static BOOL enableBlackListedApps;
static NSArray *blackListedApps;
static BOOL defaultColorEnabled;
static BOOL chargingColorEnabled;
static BOOL lowPowerModeColorEnabled;
static BOOL lowBattery1ColorEnabled;
static BOOL lowBattery2ColorEnabled;
static UIColor *customDefaultColor;
static UIColor *chargingColor;
static UIColor *lowPowerModeColor;
static UIColor *lowBattery1Color;
static UIColor *lowBattery2Color;

static BOOL isBlacklistedAppInFront = NO;
static BOOL shouldHideBasedOnOrientation = NO;
static BOOL isLockScreenPresented = NO;
static BOOL noDevicesAvailable = NO;
static UIDeviceOrientation deviceOrientation;
static BOOL isOnLandscape;
static unsigned int deviceIndex;
static NSString *percentSymbol;
static BOOL useSystemColorForPercentage = YES;

static void orientationChanged()
{
	deviceOrientation = [[UIApplication sharedApplication] _frontMostAppOrientation];
	if(deviceOrientation == UIDeviceOrientationLandscapeRight || deviceOrientation == UIDeviceOrientationLandscapeLeft)
		isOnLandscape = YES;
	else
		isOnLandscape = NO;

	if((hideOnLandscape || followDeviceOrientation) && bluetoothBatteryInfoObject) 
		[bluetoothBatteryInfoObject updateWindowFrameWithAnimation: YES];
}

static void loadDeviceScreenDimensions()
{
	screenWidth = [[UIScreen mainScreen] _referenceBounds].size.width;
	screenHeight = [[UIScreen mainScreen] _referenceBounds].size.height;
}

@implementation BluetoothBatteryInfo

	- (id)init
	{
		self = [super init];
		if(self)
		{
			glyphImageView = [[UIImageView alloc] initWithFrame: CGRectMake(0, 0, 0, 0)];
			[glyphImageView setContentMode: UIViewContentModeScaleAspectFit];
			
			percentageLabel = [[UILabel alloc] initWithFrame: CGRectMake(0, 0, 0, 0)];
			deviceNameLabel = [[UILabel alloc] initWithFrame: CGRectMake(0, 0, 0, 0)];
			
			bluetoothBatteryInfoWindow = [[UIWindow alloc] initWithFrame: CGRectMake(0, 0, 0, 0)];
			[bluetoothBatteryInfoWindow _setSecure: YES];
			[[bluetoothBatteryInfoWindow layer] setAnchorPoint: CGPointZero];
			[bluetoothBatteryInfoWindow addSubview: glyphImageView];
			[bluetoothBatteryInfoWindow addSubview: percentageLabel];
			[bluetoothBatteryInfoWindow addSubview: deviceNameLabel];
			[bluetoothBatteryInfoWindow addGestureRecognizer: [[UITapGestureRecognizer alloc] initWithTarget: self action: @selector(updateDeviceWithEffects)]];

			deviceIndex = 0;
			backupForegroundColor = [UIColor whiteColor];
			backupBackgroundColor = [[UIColor blackColor] colorWithAlphaComponent: 0.5];

			[self updateObjectWithNewSettings];

			[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(updateDeviceWithoutEffects) name: @"BCBatteryDeviceControllerConnectedDevicesDidChange" object: nil];
			CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)&orientationChanged, CFSTR("com.apple.springboard.screenchanged"), NULL, 0);
			CFNotificationCenterAddObserver(CFNotificationCenterGetLocalCenter(), NULL, (CFNotificationCallback)&orientationChanged, CFSTR("UIWindowDidRotateNotification"), NULL, CFNotificationSuspensionBehaviorCoalesce);
		}
		return self;
	}

	- (void)updateObjectWithNewSettings
	{
		[NSObject cancelPreviousPerformRequestsWithTarget: self selector: @selector(_updateObjectWithNewSettings) object: nil];
		[self performSelector: @selector(_updateObjectWithNewSettings) withObject: nil afterDelay: 0.3];
	}

	- (void)_updateObjectWithNewSettings
	{
		orientationOld = nil;
		
		if(showOnLockScreen)
			[bluetoothBatteryInfoWindow setWindowLevel: 1075];
		else
			[bluetoothBatteryInfoWindow setWindowLevel: 1000];

		if(!backgroundColorEnabled)
			[bluetoothBatteryInfoWindow setBackgroundColor: [UIColor clearColor]];
		else
		{
			if(customBackgroundColorEnabled)
				[bluetoothBatteryInfoWindow setBackgroundColor: customBackgroundColor];
			else
				[bluetoothBatteryInfoWindow setBackgroundColor: backupBackgroundColor];

			[[bluetoothBatteryInfoWindow layer] setCornerRadius: backgroundCornerRadius];
		}

		if(enableGlyphCustomTintColor)
			[glyphImageView setTintColor: glyphCustomTintColor];
		else
			[glyphImageView setTintColor: backupForegroundColor];

		if(enableCustomDeviceNameColor)
			[deviceNameLabel setTextColor: customDeviceNameColor];
		else
			[deviceNameLabel setTextColor: backupForegroundColor];
		
		[self updateLabelsFont];

		[self calculateNewWindowSize];

		[self updateGlyphFrame];
		[self updateLabelsFrame];
		[self updateWindowFrameWithAnimation: NO];
	}

	- (void)calculateNewWindowSize
	{
		windowWidth = (hideGlyph ? 0 : glyphSize) + 3 + MAX([percentageLabel frame].size.width, (hideDeviceNameLabel ? 0 : [deviceNameLabel frame].size.width)) + 2 * margin;
		windowHeight = MAX((hideGlyph ? 0 : glyphSize), labelsHeight) + 2 * margin;
	}

	- (void)updateLabelsFont
	{
		if(percentageFontBold) [percentageLabel setFont: [UIFont boldSystemFontOfSize: percentageFontSize]];
		else [percentageLabel setFont: [UIFont systemFontOfSize: percentageFontSize]];
		[percentageLabel sizeToFit];
		
		if(!hideDeviceNameLabel)
		{
			if(nameFontBold) [deviceNameLabel setFont: [UIFont boldSystemFontOfSize: nameFontSize]];
			else [deviceNameLabel setFont: [UIFont systemFontOfSize: nameFontSize]];
			[deviceNameLabel sizeToFit];
		}

		labelsHeight = [percentageLabel frame].size.height + (hideDeviceNameLabel ? 0 : [deviceNameLabel frame].size.height);
	}

	- (void)updateGlyphFrame
	{
		if(hideGlyph)
			[glyphImageView setHidden: YES];
		else
		{
			[glyphImageView setHidden: NO];
			
			CGRect frame = [glyphImageView frame];
			frame.origin.x = margin;
			frame.origin.y = windowHeight / 2 - glyphSize / 2;
			frame.size.width = glyphSize;
			frame.size.height = glyphSize;
			[glyphImageView setFrame: frame];
		}
	}

	- (void)updateLabelsFrame
	{
		CGRect frame = [percentageLabel frame];
		frame.origin.x = margin + (hideGlyph ? 0 : glyphSize + 3);
		frame.origin.y = windowHeight / 2 - labelsHeight / 2;
		[percentageLabel setFrame: frame];

		if(hideDeviceNameLabel)
			[deviceNameLabel setHidden: YES];
		else
		{
			[deviceNameLabel setHidden: NO];

			frame = [deviceNameLabel frame];
			frame.origin.x = margin + (hideGlyph ? 0 : glyphSize + 3);
			frame.origin.y = windowHeight / 2 - labelsHeight / 2 + [percentageLabel frame].size.height;
			[deviceNameLabel setFrame: frame];
		}
	}

	- (void)updateWindowFrameWithAnimation: (BOOL)animation
	{
		shouldHideBasedOnOrientation = hideOnLandscape && isOnLandscape;
		[self hideIfNeeded];

		if(!followDeviceOrientation)
		{
			CGRect frame = [bluetoothBatteryInfoWindow frame];
			frame.origin.x = portraitX;
			frame.origin.y = portraitY;
			frame.size.width = windowWidth;
			frame.size.height = windowHeight;
			[bluetoothBatteryInfoWindow setFrame: frame];
		}
		else
		{
			CGAffineTransform newTransform;
			CGRect frame = [bluetoothBatteryInfoWindow frame];

			if(deviceOrientation == UIDeviceOrientationLandscapeRight)
			{
				frame.origin.x = landscapeY;
				frame.origin.y = screenHeight - landscapeX;
				if(deviceOrientation != orientationOld)
					newTransform = CGAffineTransformMakeRotation(-DegreesToRadians(90));
			}
			else if(deviceOrientation == UIDeviceOrientationLandscapeLeft)
			{
				frame.origin.x = screenWidth - landscapeY;
				frame.origin.y = landscapeX;
				if(deviceOrientation != orientationOld)
					newTransform = CGAffineTransformMakeRotation(DegreesToRadians(90));
			}
			else if(deviceOrientation == UIDeviceOrientationPortraitUpsideDown)
			{
				frame.origin.x = screenWidth - portraitX;
				frame.origin.y = screenHeight - portraitY;
				if(deviceOrientation != orientationOld)
					newTransform = CGAffineTransformMakeRotation(DegreesToRadians(180));
			}
			else if(deviceOrientation == UIDeviceOrientationPortrait)
			{
				frame.origin.x = portraitX;
				frame.origin.y = portraitY;
				if(deviceOrientation != orientationOld)
					newTransform = CGAffineTransformMakeRotation(DegreesToRadians(0));
			}

			if(isOnLandscape)
			{
				frame.size.width = windowHeight;
				frame.size.height = windowWidth;
			}
			else
			{
				frame.size.width = windowWidth;
				frame.size.height = windowHeight;
			}

			if(animation)
			{
				[UIView animateWithDuration: 0.3f animations:
				^{
					if(deviceOrientation != orientationOld)
						[bluetoothBatteryInfoWindow setTransform: newTransform];
					[bluetoothBatteryInfoWindow setFrame: frame];
					orientationOld = deviceOrientation;
				} completion: nil];
			}
			else
			{
				if(deviceOrientation != orientationOld)
					[bluetoothBatteryInfoWindow setTransform: newTransform];
				[bluetoothBatteryInfoWindow setFrame: frame];
				orientationOld = deviceOrientation;
			}
		}
	}

	- (void)updatePercentageColor
	{
		if(deviceIndex <= [[[%c(BCBatteryDeviceController) sharedInstance] connectedDevices] count] && currentDevice)
		{
			useSystemColorForPercentage = NO;
			if([currentDevice isCharging] && chargingColorEnabled)
				[percentageLabel setTextColor: chargingColor];
			else if([currentDevice isBatterySaverModeActive] && lowPowerModeColorEnabled)
				[percentageLabel setTextColor: lowPowerModeColor];
			else if([currentDevice percentCharge] <= 15 && lowBattery2ColorEnabled)
				[percentageLabel setTextColor: lowBattery2Color];
			else if([currentDevice percentCharge] <= 25 && lowBattery1ColorEnabled)
				[percentageLabel setTextColor: lowBattery1Color];
			else if(defaultColorEnabled)
				[percentageLabel setTextColor: customDefaultColor];
			else 
			{
				useSystemColorForPercentage = YES;
				[percentageLabel setTextColor: backupForegroundColor];
			}
		}
	}

	- (void)updatePercentage
	{
		if(deviceIndex <= [[[%c(BCBatteryDeviceController) sharedInstance] connectedDevices] count] && currentDevice)
		{
			[percentageLabel setText: [NSString stringWithFormat: @"%lld%@", [currentDevice percentCharge], percentSymbol]];
			[percentageLabel sizeToFit];
			[self updatePercentageColor];

			[self calculateNewWindowSize];
			[self updateWindowFrameWithAnimation: NO];
		}
	}

	- (void)updateDeviceWithEffects
	{
		NSArray *devices = [[%c(BCBatteryDeviceController) sharedInstance] connectedDevices];

		deviceIndex++;
		if(deviceIndex > [devices count] - 1) deviceIndex = hideInternalBattery ? 1 : 0;
		
		if(deviceIndex > [devices count] - 1) noDevicesAvailable = YES;
		else
		{
			noDevicesAvailable = NO;

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

		[self hideIfNeeded];
	}

	- (void)updateDeviceWithoutEffects
	{
		NSArray *devices = [[%c(BCBatteryDeviceController) sharedInstance] connectedDevices];
		if(hideInternalBattery && deviceIndex == 0) deviceIndex++;
		if(deviceIndex > [devices count] - 1) deviceIndex = hideInternalBattery ? 1 : 0;
		
		if(deviceIndex > [devices count] - 1) noDevicesAvailable = YES;
		else
		{
			noDevicesAvailable = NO;

			currentDevice = devices[deviceIndex];

			if(!currentDeviceIdentifier || ![[currentDevice identifier] isEqualToString: currentDeviceIdentifier])
				[self loadNewDeviceValues];
		}

		[self hideIfNeeded];
	}

	- (void)loadNewDeviceValues
	{
		currentDeviceIdentifier = [currentDevice identifier];

		if([[[[currentDevice glyph] imageAsset] assetName] containsString: @"bluetooth"])
			[glyphImageView setImage: [[UIImage imageWithContentsOfFile: @"/Library/PreferenceBundles/BluetoothBatteryInfoPrefs.bundle/genericBluetoothIcon.png"] imageWithRenderingMode: UIImageRenderingModeAlwaysTemplate]];
		else
			[glyphImageView setImage: [[currentDevice glyph] imageWithRenderingMode: UIImageRenderingModeAlwaysTemplate]];

		[deviceNameLabel setText: [self getDeviceName: [[[currentDevice glyph] imageAsset] assetName]]];
		[deviceNameLabel sizeToFit];
		[self updatePercentage];
	}

	- (void)updateTextColor: (UIColor*)color
	{
		backupForegroundColor = color;
		CGFloat r;
    	[color getRed: &r green: nil blue: nil alpha: nil];
		if(r == 0 || r == 1)
		{
			if(backgroundColorEnabled && !customBackgroundColorEnabled) 
			{
				if(r == 0) [bluetoothBatteryInfoWindow setBackgroundColor: [[UIColor whiteColor] colorWithAlphaComponent: 0.5]];
				else [bluetoothBatteryInfoWindow setBackgroundColor: [[UIColor blackColor] colorWithAlphaComponent: 0.5]];
				backupBackgroundColor = [bluetoothBatteryInfoWindow backgroundColor];
			}

			if(!enableGlyphCustomTintColor)
				[glyphImageView setTintColor: color];

			if(!enableCustomDeviceNameColor)
				[deviceNameLabel setTextColor: color];

			if(useSystemColorForPercentage)
			{
				[[percentageLabel textColor] getRed: &r green: nil blue: nil alpha: nil];
				if(r == 0 || r == 1)
					[percentageLabel setTextColor: color];
			}
		}
	}

	- (void)hideIfNeeded
	{
		[bluetoothBatteryInfoWindow setHidden: noDevicesAvailable || !isLockScreenPresented && (shouldHideBasedOnOrientation || isBlacklistedAppInFront)];
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
		else return @"Device";
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

- (void)frontDisplayDidChange: (id)arg1 
{
	%orig;

	NSString *currentApp = [(SBApplication*)[self _accessibilityFrontMostApplication] bundleIdentifier];
	isBlacklistedAppInFront = blackListedApps && currentApp && [blackListedApps containsObject: currentApp];
	[bluetoothBatteryInfoObject hideIfNeeded];
}

%end

%hook SBCoverSheetPresentationManager

- (BOOL)isPresented
{
	isLockScreenPresented = %orig;
	[bluetoothBatteryInfoObject hideIfNeeded];
	return isLockScreenPresented;
}

%end

%hook BCBatteryDevice

- (void)setCharging: (BOOL)arg1
{
	%orig;
	dispatch_async(dispatch_get_main_queue(), ^{ [bluetoothBatteryInfoObject updatePercentageColor]; });
}

- (void)setPercentCharge: (long long)arg1
{
	%orig;
	dispatch_async(dispatch_get_main_queue(), ^{ [bluetoothBatteryInfoObject updatePercentage]; });
}

- (void)setBatterySaverModeActive: (BOOL)arg1
{
	%orig;
	dispatch_async(dispatch_get_main_queue(), ^{ [bluetoothBatteryInfoObject updatePercentageColor]; });
}

%end

%hook _UIStatusBar

- (void)setForegroundColor: (UIColor*)color
{
	%orig;
	
	if(bluetoothBatteryInfoObject && [self styleAttributes] && [[self styleAttributes] imageTintColor]) 
		[bluetoothBatteryInfoObject updateTextColor: [[self styleAttributes] imageTintColor]];
}

%end

%group dynamicHeadphonesIconGroup

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
	hideOnLandscape = [pref boolForKey: @"hideOnLandscape"];
	hideInternalBattery = [pref boolForKey: @"hideInternalBattery"];
	hideGlyph = [pref boolForKey: @"hideGlyph"];
	hideDeviceNameLabel = [pref boolForKey: @"hideDeviceNameLabel"];
	glyphSize = [pref integerForKey: @"glyphSize"];
	enableGlyphCustomTintColor = [pref boolForKey: @"enableGlyphCustomTintColor"];
	percentageFontSize = [pref integerForKey: @"percentageFontSize"];
	percentageFontBold = [pref boolForKey: @"percentageFontBold"];
	nameFontSize = [pref integerForKey: @"nameFontSize"];
	nameFontBold = [pref boolForKey: @"nameFontBold"];
	backgroundColorEnabled = [pref boolForKey: @"backgroundColorEnabled"];
	margin = [pref integerForKey: @"margin"];
	backgroundCornerRadius = [pref floatForKey: @"backgroundCornerRadius"];
	customBackgroundColorEnabled = [pref boolForKey: @"customBackgroundColorEnabled"];
	enableCustomDeviceNameColor = [pref boolForKey: @"enableCustomDeviceNameColor"];
	portraitX = [pref floatForKey: @"portraitX"];
	portraitY = [pref floatForKey: @"portraitY"];
	landscapeX = [pref floatForKey: @"landscapeX"];
	landscapeY = [pref floatForKey: @"landscapeY"];
	followDeviceOrientation = [pref boolForKey: @"followDeviceOrientation"];
	enableBlackListedApps = [pref boolForKey: @"enableBlackListedApps"];
	showPercentSymbol = [pref boolForKey: @"showPercentSymbol"];
	defaultColorEnabled = [pref boolForKey: @"defaultColorEnabled"];
	chargingColorEnabled = [pref boolForKey: @"chargingColorEnabled"];
	lowPowerModeColorEnabled = [pref boolForKey: @"lowPowerModeColorEnabled"];
	lowBattery1ColorEnabled = [pref boolForKey: @"lowBattery1ColorEnabled"];
	lowBattery2ColorEnabled = [pref boolForKey: @"lowBattery2ColorEnabled"];

	NSDictionary *preferencesDictionary = [NSDictionary dictionaryWithContentsOfFile: @"/var/mobile/Library/Preferences/com.johnzaro.bluetoothbatteryinfoprefs.colors.plist"];
	customBackgroundColor = [SparkColourPickerUtils colourWithString: [preferencesDictionary objectForKey: @"customBackgroundColor"] withFallback: @"#000000:0.50"];
	glyphCustomTintColor = [SparkColourPickerUtils colourWithString: [preferencesDictionary objectForKey: @"glyphCustomTintColor"] withFallback: @"#FF9400:1.0"];
	customDeviceNameColor = [SparkColourPickerUtils colourWithString: [preferencesDictionary objectForKey: @"customDeviceNameColor"] withFallback: @"#FF9400:1.0"];
	customDefaultColor = [SparkColourPickerUtils colourWithString: [preferencesDictionary objectForKey: @"customDefaultColor"] withFallback: @"#FF9400"];
	chargingColor = [SparkColourPickerUtils colourWithString: [preferencesDictionary objectForKey: @"chargingColor"] withFallback: @"#26AD61"];
	lowPowerModeColor = [SparkColourPickerUtils colourWithString: [preferencesDictionary objectForKey: @"lowPowerModeColor"] withFallback: @"#F2C40F"];
	lowBattery1Color = [SparkColourPickerUtils colourWithString: [preferencesDictionary objectForKey: @"lowBattery1Color"] withFallback: @"#E57C21"];
	lowBattery2Color = [SparkColourPickerUtils colourWithString: [preferencesDictionary objectForKey: @"lowBattery2Color"] withFallback: @"#E84C3D"];

	if(showPercentSymbol) percentSymbol = @"%";
	else percentSymbol = @"";

	if(enableBlackListedApps)
		blackListedApps = [SparkAppList getAppListForIdentifier: @"com.johnzaro.bluetoothbatteryinfoprefs.blackListedApps" andKey: @"blackListedApps"];
	else
		blackListedApps = nil;

	if(bluetoothBatteryInfoObject)
	{
		[bluetoothBatteryInfoObject updateObjectWithNewSettings];
		[bluetoothBatteryInfoObject updateDeviceWithoutEffects];
		[bluetoothBatteryInfoObject updatePercentage];
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
			@"hideOnLandscape": @NO,
			@"hideInternalBattery": @NO,
			@"hideGlyph": @NO,
			@"dynamicHeadphonesIcon": @NO,
			@"hideDeviceNameLabel": @NO,
			@"showPercentSymbol": @NO,
			@"glyphSize": @20,
			@"enableGlyphCustomTintColor": @NO,
			@"percentageFontSize": @10,
			@"percentageFontBold": @NO,
			@"nameFontSize": @8,
			@"nameFontBold": @NO,
			@"backgroundColorEnabled": @NO,
			@"margin": @3,
			@"backgroundCornerRadius": @6,
			@"customBackgroundColorEnabled": @NO,
			@"enableCustomDeviceNameColor": @NO,
			@"portraitX": @165,
			@"portraitY": @32,
			@"landscapeX": @735,
			@"landscapeY": @32,
			@"followDeviceOrientation": @NO,
			@"enableBlackListedApps": @NO,
			@"defaultColorEnabled": @NO,
			@"chargingColorEnabled": @NO,
			@"lowPowerModeColorEnabled": @NO,
			@"lowBattery1ColorEnabled": @NO,
			@"lowBattery2ColorEnabled": @NO,
    	}];

		settingsChanged(NULL, NULL, NULL, NULL, NULL);

		if(enabled)
		{
			CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, settingsChanged, CFSTR("com.johnzaro.bluetoothbatteryinfoprefs/reloadprefs"), NULL, CFNotificationSuspensionBehaviorCoalesce);

			dynamicHeadphonesIcon = [pref boolForKey: @"dynamicHeadphonesIcon"];
			if(dynamicHeadphonesIcon) %init(dynamicHeadphonesIconGroup);
			%init;
		}
	}
}