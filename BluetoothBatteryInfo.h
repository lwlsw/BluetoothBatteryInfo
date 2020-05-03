@interface BCBatteryDevice: NSObject
@property(nonatomic, readonly) UIImage *glyph;
- (long long)percentCharge;
- (BOOL)isBatterySaverModeActive;
- (BOOL)isCharging;
- (NSString*)identifier;
@end

@interface BCBatteryDeviceController: NSObject
+ (id)sharedInstance;
- (NSArray*)connectedDevices;
@end

@interface BluetoothBatteryInfo: NSObject
{
    UIWindow *bluetoothBatteryInfoWindow;
    UIImageView *glyphImageView;
    UILabel *percentageLabel;
    UILabel *deviceNameLabel;
    BOOL useOriginalGlyph;
    BCBatteryDevice *currentDevice;
    NSString *currentDeviceIdentifier;
    UIColor *backupColor;
    UIDeviceOrientation deviceOrientation;
}
- (id)init;
- (void)updateLabelsSize;
- (void)updateGlyphSize;
- (void)updateLabelProperties;
- (void)updatePercentage;
- (void)updatePercentageColor;
- (void)updateOrientation;
- (void)updateFrame;
- (void)updateTextColor: (UIColor*)color;
- (void)setHidden:(BOOL)arg;
@end

@interface UIImageAsset ()
@property(nonatomic, assign) NSString *assetName;
@end

@interface UIWindow ()
- (void)_setSecure:(BOOL)arg1;
@end

@interface SBApplication: NSObject
-(NSString*)bundleIdentifier;
@end

@interface SpringBoard: UIApplication
- (id)_accessibilityFrontMostApplication;
-(void)frontDisplayDidChange: (id)arg1;
@end

@interface UIApplication ()
- (UIDeviceOrientation)_frontMostAppOrientation;
- (BOOL)launchApplicationWithIdentifier:(id)arg1 suspended:(BOOL)arg2;
@end
@interface _UIStatusBarStyleAttributes: NSObject
@property(nonatomic, copy) UIColor *imageTintColor;
@end

@interface _UIStatusBar: UIView
@property(nonatomic, retain) _UIStatusBarStyleAttributes *styleAttributes;
@end

@interface UIImage ()
@property(nonatomic, assign) CGSize pixelSize;
- (UIImage *)sbf_resizeImageToSize:(CGSize)size;
@end

@interface _UIAssetManager
+ (id)assetManagerForBundle:(NSBundle *)bundle;
- (UIImage *)imageNamed:(NSString *)name;
@end

@interface UIStatusBarItem
@property(nonatomic, assign) NSString *indicatorName;
@property(nonatomic, assign) Class viewClass;
@end

@interface UIStatusBarItemView
@property(nonatomic, assign) UIStatusBarItem *item;
@end

@interface UIStatusBarIndicatorItemView : UIStatusBarItemView
@end

