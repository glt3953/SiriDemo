//
//  ViewController.m
//  SiriDemoByObjectiveC
//
//  Created by guoliting on 2017/8/1.
//  Copyright © 2017年 NingXia. All rights reserved.
//

#import "ViewController.h"
#import <Speech/Speech.h>

@interface ViewController () <SFSpeechRecognizerDelegate>

@property (nonatomic, strong) UITextView *recognizeTextView;
@property (nonatomic, strong) UIButton *microphoneButton;
@property (nonatomic, strong) SFSpeechRecognizer *speechRecognizer;
@property (nonatomic, strong) SFSpeechAudioBufferRecognitionRequest *recognitionRequest; //处理了语音识别请求，它给语音识别提供了语音输入。
@property (nonatomic, strong) SFSpeechRecognitionTask *recognitionTask; //告诉你语音识别对象的结果，拥有这个对象很方便因为你可以用它删除或者中断任务。
@property (nonatomic, strong) AVAudioEngine *audioEngine; //语音引擎，它负责提供你的语音输入。

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    #ifdef GCD_STUDY
        //        [self syncConcurrent];
        //        [self asyncConcurrent];
        //          [self syncSerial];
        [self asyncSerial];
    #endif
    
    /*
     在info.plist文件里添加了两个键值：
     NSMicrophoneUsageDescription -为获取麦克风语音输入授权的自定义消息。注意这个语音输入授权仅仅只会在用户点击microphone按钮时发生。
     Your microphone will be used to record your speech when you press the 'Start Recording' button.
     NSSpeechRecognitionUsageDescription – 语音识别授权的自定义信息
     Speech recognition will be used to determine which words you speak into this device's microphone.
     */
    CGFloat originX = 10;
    CGFloat originY = 64 + 10;
    CGFloat spaceY = 10;
    CGFloat buttonHeight = 30;
    CGFloat viewWidth = CGRectGetWidth(self.view.bounds) - 2 * originX;
    CGFloat viewHeight = CGRectGetHeight(self.view.bounds) - 2 * originY - buttonHeight - spaceY;
    _recognizeTextView = [[UITextView alloc] initWithFrame:(CGRect){originX, originY, viewWidth, viewHeight}];
    [_recognizeTextView setFont:[UIFont systemFontOfSize:20]];
    [_recognizeTextView setText:@"This is the UITextView"];
    [self.view addSubview:_recognizeTextView];
    
    originY += viewHeight + spaceY;
    _microphoneButton = [[UIButton alloc] initWithFrame:(CGRect){originX, originY, viewWidth, buttonHeight}];
    [_microphoneButton.titleLabel setFont:[UIFont systemFontOfSize:20]];
    [_microphoneButton setTitle:@"Start Recording" forState:UIControlStateNormal];
    [_microphoneButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [self.view addSubview:_microphoneButton];
    [_microphoneButton addTarget:self action:@selector(microphoneButtonDidClicked:) forControlEvents:UIControlEventTouchUpInside];
    _microphoneButton.enabled = NO;
    
    /* 申请用户语音识别权限
     The app's Info.plist must contain an NSSpeechRecognitionUsageDescription key with a string value explaining to the user how the app uses this data.
     typedef NS_ENUM(NSInteger, SFSpeechRecognizerAuthorizationStatus) {
     //结果未知 用户尚未进行选择
     SFSpeechRecognizerAuthorizationStatusNotDetermined,
     //用户拒绝授权语音识别
     SFSpeechRecognizerAuthorizationStatusDenied,
     //设备不支持语音识别功能
     SFSpeechRecognizerAuthorizationStatusRestricted,
     //用户授权语音识别
     SFSpeechRecognizerAuthorizationStatusAuthorized,
     };*/
    [SFSpeechRecognizer requestAuthorization:^(SFSpeechRecognizerAuthorizationStatus status) {
        BOOL isButtonEnabled = NO;
        switch (status) {
            case SFSpeechRecognizerAuthorizationStatusAuthorized:
            {
                NSString *localeIdentifier = @"zh_CN"; //zh-CN:中文，en-US:英文，zh_TW:台湾繁体，zh_HK:香港繁体
                _speechRecognizer = [[SFSpeechRecognizer alloc] initWithLocale:[[NSLocale alloc] initWithLocaleIdentifier:localeIdentifier]];
                _speechRecognizer.delegate = self;
                
                _audioEngine = [[AVAudioEngine alloc] init];
                
                isButtonEnabled = YES;
            }
                break;
            case SFSpeechRecognizerAuthorizationStatusDenied:
                NSLog(@"User denied access to speech recognition");
                break;
            case SFSpeechRecognizerAuthorizationStatusRestricted:
                NSLog(@"Speech recognition restricted on this device");
                break;
            case SFSpeechRecognizerAuthorizationStatusNotDetermined:
                NSLog(@"Speech recognition not yet authorized");
                break;
            default:
                break;
        }
        
        // 进入主线程执行
        dispatch_async(dispatch_get_main_queue(), ^{
            _microphoneButton.enabled = isButtonEnabled;
        });
    }];
}

- (IBAction)microphoneButtonDidClicked:(id)sender {
    if (_audioEngine.isRunning) {
        [_audioEngine stop];
        [_recognitionRequest endAudio];
        _microphoneButton.enabled = NO;
        [_microphoneButton setTitle:@"Start Recording" forState:UIControlStateNormal];
    } else {
        [self startRecording];
        [_microphoneButton setTitle:@"Stop Recording" forState:UIControlStateNormal];
    }
}

- (void)startRecording {
    //检查 recognitionTask 是否在运行，如果运行就取消任务和识别。
    if (_recognitionTask) {
        [_recognitionTask cancel];
        _recognitionTask = nil;
    }
    
    //创建一个 AVAudioSession来为记录语音做准备，在这里我们设置session的类别为recording，模式为measurement，然后激活它。
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    NSError *errorSession = nil;
    @try {
        [audioSession setCategory:AVAudioSessionCategoryRecord error:&errorSession];
        [audioSession setMode:AVAudioSessionModeMeasurement error:&errorSession];
        [audioSession setActive:YES withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:&errorSession];
    } @catch (NSException *exception) {
        NSLog(@"audioSession properties weren't set because of an error.");
    }
    
    //实例化recognitionRequest，在这里我们创建了SFSpeechAudioBufferRecognitionRequest对象，利用它把语音数据传到苹果后台。
    _recognitionRequest = [[SFSpeechAudioBufferRecognitionRequest alloc] init];
    if (!_recognitionRequest) {
        NSLog(@"Unable to create an SFSpeechAudioBufferRecognitionRequest object");
    } else {
        //当用户说话的时候让recognitionRequest报告语音识别的部分结果
        _recognitionRequest.shouldReportPartialResults = YES;
    }
    
    //检查 audioEngine（你的设备）是否有录音功能作为语音输入，如果没有，我们就报告一个错误。
    AVAudioInputNode *inputNode = _audioEngine.inputNode;
    if (!inputNode) {
        NSLog(@"Audio engine has no input node");
    }
    
    //调用 speechRecognizer的recognitionTask 方法来开启语音识别。这个方法有一个completion handler回调，这个回调每次都会在识别引擎收到输入并完善当前识别信息时，或者被删除、停止时被调用，最后返回一个最终文本。
    _recognitionTask = [_speechRecognizer recognitionTaskWithRequest:_recognitionRequest resultHandler:^(SFSpeechRecognitionResult * _Nullable result, NSError * _Nullable error) {
        //定义一个布尔值决定识别是否已经结束
        BOOL isFinal = NO;
        
        if (result) {
            //如果结果 result 不是nil, 把 textView.text 的值设置为我们的最优文本。如果结果是最终结果，设置 isFinal为true。
            _recognizeTextView.text = result.bestTranscription.formattedString;
            isFinal = result.isFinal;
        }
        
        if (error || isFinal) {
            //如果没有错误或者结果是最终结果，停止 audioEngine(语音输入)并且停止 recognitionRequest 和 recognitionTask.同时，使Start Recording按钮有效。
            [_audioEngine stop];
            [inputNode removeTapOnBus:0];
            _recognitionRequest = nil;
            _recognitionTask = nil;
            _microphoneButton.enabled = YES;
            [_microphoneButton setTitle:@"Start Recording" forState:UIControlStateNormal];
        }
    }];
    
    //向 recognitionRequest增加一个语音输入，注意在开始了recognitionTask之后增加语音输入是OK的，Speech Framework 会在语音输入被加入的同时就开始进行解析识别。
    AVAudioFormat *recordingFormat = [inputNode outputFormatForBus:0];
    [inputNode installTapOnBus:0 bufferSize:1024 format:recordingFormat block:^(AVAudioPCMBuffer * _Nonnull buffer, AVAudioTime * _Nonnull when) {
        [_recognitionRequest appendAudioPCMBuffer:buffer];
    }];
    
    //准备并且开始audioEngine
    [_audioEngine prepare];
    @try {
        NSError *outError = nil;
        [_audioEngine startAndReturnError:&outError];
    } @catch (NSException *exception) {
        NSLog(@"audioEngine couldn't start because of an error.");
    } @finally {
        
    }
    
    _recognizeTextView.text = @"Say something, I'm listening!";
}

#ifdef GCD_STUDY
//并行队列 + 同步执行(sync)，不会开启新线程，执行完一个任务，再执行下一个任务
- (void)syncConcurrent {
    //所有任务都是在主线程中执行的，由于只有一个线程，所以任务只能一个一个执行。
    NSLog(@"syncConcurrent---begin");
    
    dispatch_queue_t queue= dispatch_queue_create("test.queue", DISPATCH_QUEUE_CONCURRENT);
    
    dispatch_sync(queue, ^{
        for (int i = 0; i < 2; ++i) {
            NSLog(@"1------%@",[NSThread currentThread]);
        }
    });
    dispatch_sync(queue, ^{
        for (int i = 0; i < 2; ++i) {
            NSLog(@"2------%@",[NSThread currentThread]);
        }
    });
    dispatch_sync(queue, ^{
        for (int i = 0; i < 2; ++i) {
            NSLog(@"3------%@",[NSThread currentThread]);
        }
    });
    
    NSLog(@"syncConcurrent---end");
    //所有任务都在打印的syncConcurrent---begin和syncConcurrent---end之间，这说明任务是添加到队列中马上执行的。
}

//并行队列 + 异步执行，可同时开启多线程，任务交替执行
- (void)asyncConcurrent {
    //除了主线程，又开启了3个线程，并且任务是交替着同时执行的。
    NSLog(@"asyncConcurrent---begin");
    
    dispatch_queue_t queue= dispatch_queue_create("test.queue", DISPATCH_QUEUE_CONCURRENT);
    
    dispatch_async(queue, ^{
        for (int i = 0; i < 2; ++i) {
            NSLog(@"1------%@",[NSThread currentThread]);
        }
    });
    dispatch_async(queue, ^{
        for (int i = 0; i < 2; ++i) {
            NSLog(@"2------%@",[NSThread currentThread]);
        }
    });
    dispatch_async(queue, ^{
        for (int i = 0; i < 2; ++i) {
            NSLog(@"3------%@",[NSThread currentThread]);
        }
    });
    
    NSLog(@"asyncConcurrent---end");
    //所有任务是在打印syncConcurrent---begin和syncConcurrent---end之后才开始执行的，说明任务不是马上执行，而是将所有任务添加到队列之后才开始异步执行。
}

//串行队列 + 同步执行，不会开启新线程，在当前线程执行任务。任务是串行的，执行完一个任务，再执行下一个任务
- (void)syncSerial {
    //所有任务都是在主线程中执行的，并没有开启新的线程，而且由于串行队列，所以按顺序一个一个执行。
    NSLog(@"syncSerial---begin");
    
    dispatch_queue_t queue = dispatch_queue_create("test.queue", DISPATCH_QUEUE_SERIAL);
    
    dispatch_sync(queue, ^{
        for (int i = 0; i < 2; ++i) {
            NSLog(@"1------%@",[NSThread currentThread]);
        }
    });
    dispatch_sync(queue, ^{
        for (int i = 0; i < 2; ++i) {
            NSLog(@"2------%@",[NSThread currentThread]);
        }
    });
    dispatch_sync(queue, ^{
        for (int i = 0; i < 2; ++i) {
            NSLog(@"3------%@",[NSThread currentThread]);
        }
    });
    
    NSLog(@"syncSerial---end");
    //所有任务都在打印的syncConcurrent---begin和syncConcurrent---end之间，这说明任务是添加到队列中马上执行的。
}

//串行队列 + 异步执行，会开启新线程，但是因为任务是串行的，执行完一个任务，再执行下一个任务
- (void)asyncSerial {
    //开启了一条新线程，但是任务还是串行，所以任务是一个一个执行。
    NSLog(@"asyncSerial---begin");
    
    dispatch_queue_t queue = dispatch_queue_create("test.queue", DISPATCH_QUEUE_SERIAL);
    
    dispatch_async(queue, ^{
        for (int i = 0; i < 2; ++i) {
            NSLog(@"1------%@",[NSThread currentThread]);
        }
    });
    dispatch_async(queue, ^{
        for (int i = 0; i < 2; ++i) {
            NSLog(@"2------%@",[NSThread currentThread]);
        }
    });
    dispatch_async(queue, ^{
        for (int i = 0; i < 2; ++i) {
            NSLog(@"3------%@",[NSThread currentThread]);
        }
    });
    
    NSLog(@"asyncSerial---end");
    //所有任务是在打印的syncConcurrent---begin和syncConcurrent---end之后才开始执行的。说明任务不是马上执行，而是将所有任务添加到队列之后才开始同步执行。
}
#endif

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - SFSpeechRecognizerDelegate
- (void)speechRecognizer:(SFSpeechRecognizer *)speechRecognizer availabilityDidChange:(BOOL)available {
    _microphoneButton.enabled = available;
}

@end
