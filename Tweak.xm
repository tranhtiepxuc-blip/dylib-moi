#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <MobileCoreServices/MobileCoreServices.h>

// --- BIẾN TOÀN CỤC QUẢN LÝ TRẠNG THÁI ---
static BOOL g_isSimulating = NO;
static double g_fakeLatitude = 10.9318;  // Tọa độ mặc định (Phan Thiết, Bình Thuận)
static double g_fakeLongitude = 108.1008;
static double g_fakeAltitude = 30.0;
static double g_speed = 5.0;            // Tốc độ di chuyển mặc định (m/s)

static NSMutableArray *g_gpxPoints = nil;
static NSInteger g_gpxIndex = 0;
static NSTimer *g_simTimer = nil;
static UIImage *g_fakeImage = nil;

// --- GIAO DIỆN ĐIỀU KHIỂN NỔI (FLOATING MENU) ---
@interface FMSMenuController : UIViewController <UIDocumentPickerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property (nonatomic, strong) UIView *panelView;
@property (nonatomic, strong) UIButton *floatBtn;
@property (nonatomic, strong) UIButton *btnPlay;
@property (nonatomic, strong) UILabel *lblStatus;
@end

@implementation FMSMenuController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // 1. Tạo nút bong bóng nổi (Floating Button)
    self.floatBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.floatBtn.frame = CGRectMake([UIScreen mainScreen].bounds.size.width - 80, 200, 60, 60);
    self.floatBtn.layer.cornerRadius = 30;
    self.floatBtn.backgroundColor = [UIColor colorWithRed:0.0 green:0.59 blue:0.53 alpha:0.9]; // Xanh Ngọc
    [self.floatBtn setTitle:@"FMS" forState:UIControlStateNormal];
    self.floatBtn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    [self.floatBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    
    // Thêm viền phát sáng nhẹ cho nút nổi
    self.floatBtn.layer.shadowColor = [UIColor blackColor].CGColor;
    self.floatBtn.layer.shadowOffset = CGSizeMake(0, 4);
    self.floatBtn.layer.shadowOpacity = 0.4;
    self.floatBtn.layer.shadowRadius = 5;
    
    [self.floatBtn addTarget:self action:@selector(togglePanel) forControlEvents:UIControlEventTouchUpInside];
    
    // Kéo thả nút nổi
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [self.floatBtn addGestureRecognizer:pan];
    [self.view addSubview:self.floatBtn];
    
    // 2. Tạo bảng Menu chức năng (Dashboard Panel) - Mặc định ẩn
    self.panelView = [[UIView alloc] initWithFrame:CGRectMake(([UIScreen mainScreen].bounds.size.width - 280)/2, -400, 280, 360)];
    self.panelView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.95]; // Nền tối mờ sang trọng
    self.panelView.layer.cornerRadius = 20;
    self.panelView.alpha = 0.0;
    self.panelView.layer.borderColor = [UIColor colorWithWhite:0.3 alpha:0.5].CGColor;
    self.panelView.layer.borderWidth = 1.0;
    
    // Tiêu đề Dashboard
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 15, 280, 25)];
    titleLabel.text = @"BẢN ĐỒ LÂM NGHIỆP PRO";
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.font = [UIFont boldSystemFontOfSize:15];
    [self.panelView addSubview:titleLabel];
    
    // Dòng thông báo trạng thái
    self.lblStatus = [[UILabel alloc] initWithFrame:CGRectMake(10, 45, 260, 35)];
    self.lblStatus.text = @"Vị trí: Chờ cấu hình tuyến GPX...";
    self.lblStatus.textColor = [UIColor yellowColor];
    self.lblStatus.numberOfLines = 2;
    self.lblStatus.textAlignment = NSTextAlignmentCenter;
    self.lblStatus.font = [UIFont systemFontOfSize:11];
    [self.panelView addSubview:self.lblStatus];
    
    // Tạo danh sách nút bấm dọc bằng UIStackView cho ngay ngắn
    UIStackView *stackView = [[UIStackView alloc] initWithFrame:CGRectMake(15, 90, 250, 250)];
    stackView.axis = UILayoutConstraintAxisVertical;
    stackView.distribution = UIStackViewDistributionFillEqually;
    stackView.spacing = 8;
    
    UIButton *btnGPX = [self createMenuButton:@"📥 NHẬP TỆP GPX" action:@selector(importGPX)];
    UIButton *btnSpeed = [self createMenuButton:@"⚡ TỐC ĐỘ DI CHUYỂN" action:@selector(changeSpeed)];
    UIButton *btnAlt = [self createMenuButton:@"🏔️ ĐỘ CAO GIẢ LẬP" action:@selector(changeAltitude)];
    self.btnPlay = [self createMenuButton:@"▶️ CHẠY TUYẾN ĐƯỜNG" action:@selector(toggleSimulation)];
    UIButton *btnFakeCam = [self createMenuButton:@"📸 FAKE ẢNH CHỤP" action:@selector(pickFakeImage)];
    
    [stackView addArrangedSubview:btnGPX];
    [stackView addArrangedSubview:btnSpeed];
    [stackView addArrangedSubview:btnAlt];
    [stackView addArrangedSubview:self.btnPlay];
    [stackView addArrangedSubview:btnFakeCam];
    
    [self.panelView addSubview:stackView];
    [self.view addSubview:self.panelView];
}

// Tạo nút bấm chuẩn phong cách tối giản
- (UIButton *)createMenuButton:(NSString *)title action:(SEL)action {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    [btn setTitle:title forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btn.backgroundColor = [UIColor colorWithWhite:0.2 alpha:0.8];
    btn.layer.cornerRadius = 8;
    btn.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return btn;
}

// Xử lý kéo thả nút nổi trên màn hình
- (void)handlePan:(UIPanGestureRecognizer *)sender {
    CGPoint translation = [sender translationInView:self.view];
    sender.view.center = CGPointMake(sender.view.center.x + translation.x, sender.view.center.y + translation.y);
    [sender setTranslation:CGPointZero inView:self.view];
}

// Ẩn/Hiện bảng điều khiển trung tâm
- (void)togglePanel {
    [UIView animateWithDuration:0.3 animations:^{
        if (self.panelView.alpha == 0.0) {
            self.panelView.alpha = 1.0;
            self.panelView.frame = CGRectMake(([UIScreen mainScreen].bounds.size.width - 280)/2, 100, 280, 360);
        } else {
            self.panelView.alpha = 0.0;
            self.panelView.frame = CGRectMake(([UIScreen mainScreen].bounds.size.width - 280)/2, -400, 280, 360);
        }
    }];
}

// Chức năng 1: Nhập tệp GPX từ iPhone
- (void)importGPX {
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"com.topografix.gpx", (NSString *)kUTTypeFileURL] inMode:UIDocumentPickerModeImport];
    picker.delegate = self;
    picker.allowsMultipleSelection = NO;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *fileURL = urls.firstObject;
    if (fileURL) {
        NSError *error = nil;
        NSString *content = [NSString stringWithContentsOfURL:fileURL encoding:NSUTF8StringEncoding error:&error];
        if (content) {
            g_gpxPoints = [NSMutableArray array];
            g_gpxIndex = 0;
            
            // Bộ phân tích thô GPX quét tìm các điểm <trkpt lat="..." lon="...">
            NSScanner *scanner = [NSScanner scannerWithString:content];
            while (![scanner isAtEnd]) {
                [scanner scanUpToString:@"<trkpt" intoString:nil];
                if ([scanner scanString:@"<trkpt" intoString:nil]) {
                    NSString *latStr = nil, *lonStr = nil;
                    [scanner scanUpToString:@"lat=\"" intoString:nil];
                    [scanner scanString:@"lat=\"" intoString:nil];
                    [scanner scanUpToString:@"\"" intoString:&latStr];
                    
                    [scanner scanUpToString:@"lon=\"" intoString:nil];
                    [scanner scanString:@"lon=\"" intoString:nil];
                    [scanner scanUpToString:@"\"" intoString:&lonStr];
                    
                    if (latStr && lonStr) {
                        CLLocationCoordinate2D coord = CLLocationCoordinate2DMake([latStr doubleValue], [lonStr doubleValue]);
                        [g_gpxPoints addObject:[NSValue valueWithBytes:&coord objCType:@encode(CLLocationCoordinate2D)]];
                    }
                } else {
                    break;
                }
            }
            
            if (g_gpxPoints.count > 0) {
                self.lblStatus.text = [NSString stringWithFormat:@"Đã nạp tuyến GPX!\nCó tất cả %lu điểm thực địa.", (unsigned long)g_gpxPoints.count];
                CLLocationCoordinate2D firstPoint;
                [g_gpxPoints[0] getValue:&firstPoint];
                g_fakeLatitude = firstPoint.latitude;
                g_fakeLongitude = firstPoint.longitude;
            } else {
                self.lblStatus.text = @"Tệp GPX trống hoặc sai định dạng mẫu!";
            }
        }
    }
}

// Chức năng 2: Đổi tốc độ di chuyển mô phỏng
- (void)changeSpeed {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Tốc độ di chuyển" message:@"Đơn vị tính bằng m/s (Ví dụ: 5 m/s)" preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.keyboardType = UIKeyboardTypeDecimalPad;
        textField.placeholder = [NSString stringWithFormat:@"%.1f", g_speed];
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"LƯU" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        UITextField *tf = alert.textFields.firstObject;
        if (tf.text.length > 0) {
            g_speed = [tf.text doubleValue];
            self.lblStatus.text = [NSString stringWithFormat:@"Đã cập nhật tốc độ: %.1f m/s", g_speed];
        }
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"HỦY" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

// Chức năng 3: Đổi độ cao giả lập
- (void)changeAltitude {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Độ cao lâm nghiệp" message:@"Nhập độ cao giả lập thực địa (mét)" preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.keyboardType = UIKeyboardTypeDecimalPad;
        textField.placeholder = [NSString stringWithFormat:@"%.1f", g_fakeAltitude];
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"LƯU" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        UITextField *tf = alert.textFields.firstObject;
        if (tf.text.length > 0) {
            g_fakeAltitude = [tf.text doubleValue];
            self.lblStatus.text = [NSString stringWithFormat:@"Độ cao cố định: %.1f mét", g_fakeAltitude];
        }
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"HỦY" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

// Chức năng 4: Chạy / Tạm dừng mô phỏng tuyến di chuyển
- (void)toggleSimulation {
    if (g_gpxPoints.count == 0) {
        self.lblStatus.text = @"Hãy nạp file GPX trước khi bấm chạy!";
        return;
    }
    
    if (g_isSimulating) {
        // TẠM DỪNG TUYẾN
        g_isSimulating = NO;
        [g_simTimer invalidate];
        g_simTimer = nil;
        [self.btnPlay setTitle:@"▶️ CHẠY TUYẾN ĐƯỜNG" forState:UIControlStateNormal];
        self.btnPlay.backgroundColor = [UIColor colorWithWhite:0.2 alpha:0.8];
        self.lblStatus.text = @"Đã tạm dừng tuyến đường.";
    } else {
        // CHẠY TUYẾN
        g_isSimulating = YES;
        [self.btnPlay setTitle:@"⏸️ TẠM DỪNG TUYẾN" forState:UIControlStateNormal];
        self.btnPlay.backgroundColor = [UIColor colorWithRed:0.9 green:0.26 blue:0.21 alpha:0.9]; // Đổi sang màu đỏ cảnh báo
        
        // Cứ mỗi 1 giây cập nhật dịch chuyển tọa độ một lần dựa trên vận tốc
        g_simTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer *timer) {
            if (g_gpxIndex < g_gpxPoints.count) {
                CLLocationCoordinate2D pt;
                [g_gpxPoints[g_gpxIndex] getValue:&pt];
                g_fakeLatitude = pt.latitude;
                g_fakeLongitude = pt.longitude;
                
                self.lblStatus.text = [NSString stringWithFormat:@"Đang di chuyển (%ld/%lu):\nLat: %.6f, Lon: %.6f", (long)g_gpxIndex + 1, (unsigned long)g_gpxPoints.count, g_fakeLatitude, g_fakeLongitude];
                g_gpxIndex++;
            } else {
                // Đi hết tuyến, tự động lặp lại từ điểm 0
                g_gpxIndex = 0;
            }
        }];
    }
}

// Chức năng 5: Chọn ảnh trong máy để bẻ khóa Camera
- (void)pickFakeImage {
    UIImagePickerController *imgPicker = [[UIImagePickerController alloc] init];
    imgPicker.delegate = self;
    imgPicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    [self presentViewController:imgPicker animated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey,id> *)info {
    UIImage *image = info[UIImagePickerControllerOriginalImage];
    if (image) {
        // Xoay ảnh đứng 90 độ nếu là ảnh ngang để vừa khít màn hình chụp đứng FMS
        if (image.imageOrientation == UIImageOrientationLeft || image.imageOrientation == UIImageOrientationRight) {
            UIGraphicsBeginImageContextWithOptions(image.size, NO, image.scale);
            [image drawInRect:CGRectMake(0, 0, image.size.width, image.size.height)];
            g_fakeImage = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
        } else {
            g_fakeImage = image;
        }
        self.lblStatus.text = @"🟢 Đã khóa ảnh gốc thành công!";
    }
    [picker dismissViewController:animated:YES completion:nil];
}

@end

// --- HOOK TẦNG CORE LOCATION (GIẢ LẬP TỌA ĐỘ VÀ ĐỘ CAO CHUYÊN SÂU) ---
%hook CLLocation

- (CLLocationCoordinate2D)coordinate {
    if (g_isSimulating) {
        return CLLocationCoordinate2DMake(g_fakeLatitude, g_fakeLongitude);
    }
    return %orig;
}

- (CLLocationDistance)altitude {
    if (g_fakeAltitude > 0) {
        return g_fakeAltitude;
    }
    return %orig;
}

%end

%hook CLLocationManager

- (CLLocation *)location {
    CLLocation *origLocation = %orig;
    NSDate *currentDate = origLocation ? [origLocation timestamp] : [NSDate date];
    
    return [[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(g_fakeLatitude, g_fakeLongitude)
                                          altitude:g_fakeAltitude
                                horizontalAccuracy:5.0
                                  verticalAccuracy:5.0
                                         timestamp:currentDate];
}

%end

// --- HOOK TẦNG AVFOUNDATION (TRÁO ĐỔI LUỒNG VIDEO CAMERA) ---
// Chuyển đổi UIImage thành CVPixelBufferRef để nạp vào driver camera
static CVPixelBufferRef CreatePixelBufferFromUIImage(UIImage *image) {
    CGImageRef cgImage = image.CGImage;
    NSDictionary *options = @{
        (id)kCVPixelBufferCGImageCompatibilityKey: @(YES),
        (id)kCVPixelBufferCGBitmapContextCompatibilityKey: @(YES)
    };
    CVPixelBufferRef pxbuffer = NULL;
    size_t width = CGImageGetWidth(cgImage);
    size_t height = CGImageGetHeight(cgImage);
    
    CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, (__bridge CFDictionaryRef)options, &pxbuffer);
    CVPixelBufferLockBaseAddress(pxbuffer, 0);
    void *pxdata = CVPixelBufferGetBaseAddress(pxbuffer);
    
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pxdata, width, height, 8, CVPixelBufferGetBytesPerRow(pxbuffer), rgbColorSpace, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
    
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), cgImage);
    CGColorSpaceRelease(rgbColorSpace);
    CGContextRelease(context);
    CVPixelBufferUnlockBaseAddress(pxbuffer, 0);
    
    return pxbuffer;
}

%hook AVCaptureVideoDataOutput

- (void)setSampleBufferDelegate:(id)delegate queue:(dispatch_queue_t)sampleBufferCallbackQueue {
    %orig;
}

%end

// Tráo khung hình camera xem trước (Preview) theo thời gian thực
%hookf(void, captureOutput_didOutputSampleBuffer_fromConnection, id self, SEL _cmd, AVCaptureOutput *output, CMSampleBufferRef sampleBuffer, AVCaptureConnection *connection) {
    if (g_fakeImage != nil) {
        CVPixelBufferRef imageBuffer = CreatePixelBufferFromUIImage(g_fakeImage);
        if (imageBuffer != NULL) {
            CMSampleTimingInfo timingInfo;
            CMSampleBufferGetSampleTimingInfo(sampleBuffer, 0, &timingInfo);
            
            CMVideoFormatDescriptionRef formatDesc = NULL;
            CMVideoFormatDescriptionCreateForImageBuffer(NULL, imageBuffer, &formatDesc);
            
            CMSampleBufferRef fakeSampleBuffer = NULL;
            CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault, imageBuffer, YES, NULL, NULL, formatDesc, &timingInfo, &fakeSampleBuffer);
            
            if (fakeSampleBuffer != NULL) {
                %orig(self, _cmd, output, fakeSampleBuffer, connection);
                CFRelease(fakeSampleBuffer);
            } else {
                %orig(self, _cmd, output, sampleBuffer, connection);
            }
            CFRelease(formatDesc);
            CVPixelBufferRelease(imageBuffer);
            return;
        }
    }
    %orig(self, _cmd, output, sampleBuffer, connection);
}

// --- KHỞI TẠO VÀ BƠM VIEW NỔI KHI APP MỞ LÊN ---
%ctor {
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = nil;
            if (@available(iOS 13.0, *)) {
                for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
                    if (scene.activationState == UISceneActivationStateForegroundActive) {
                        for (UIWindow *window in scene.windows) {
                            if (window.isKeyWindow) {
                                keyWindow = window;
                                break;
                            }
                        }
                    }
                }
            }
            if (!keyWindow) {
                keyWindow = [UIApplication sharedApplication].keyWindow;
            }
            
            if (keyWindow) {
                FMSMenuController *menuVC = [[FMSMenuController alloc] init];
                // Thêm View nổi trực tiếp vào lớp phủ cao nhất của cửa sổ ứng dụng
                [keyWindow addSubview:menuVC.view];
                // Giữ tham chiếu để vòng đời view controller hoạt động hoàn hảo
                objc_setAssociatedObject(keyWindow, @"FMSMenuControllerKey", menuVC, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
        });
    }];
}


