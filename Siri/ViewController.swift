//
//  ViewController.swift
//  Siri
//
//  Created by Sahand Edrisian on 7/14/16.
//  Copyright © 2016 Sahand Edrisian. All rights reserved.
//

import UIKit
import Speech

class ViewController: UIViewController, SFSpeechRecognizerDelegate {
	
	@IBOutlet weak var textView: UITextView!
	@IBOutlet weak var microphoneButton: UIButton!
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale.init(identifier: "en-US"))  //1
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest? //处理了语音识别请求，它给语音识别提供了语音输入。
    private var recognitionTask: SFSpeechRecognitionTask? //告诉你语音识别对象的结果，拥有这个对象很方便因为你可以用它删除或者中断任。
    private let audioEngine = AVAudioEngine() //语音引擎，它负责提供你的语音输入。
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
        microphoneButton.isEnabled = false  //2

        speechRecognizer?.delegate = self  //3
        
        SFSpeechRecognizer.requestAuthorization { (authStatus) in  //4
            
            var isButtonEnabled = false
            
            switch authStatus {  //5
                case .authorized:
                    isButtonEnabled = true
                    
                case .denied:
                    isButtonEnabled = false
                    print("User denied access to speech recognition")
                    
                case .restricted:
                    isButtonEnabled = false
                    print("Speech recognition restricted on this device")
                    
                case .notDetermined:
                    isButtonEnabled = false
                    print("Speech recognition not yet authorized")
            }
            
            OperationQueue.main.addOperation() {
                self.microphoneButton.isEnabled = isButtonEnabled
            }
        }
	}

	@IBAction func microphoneTapped(_ sender: AnyObject) {
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            microphoneButton.isEnabled = false
            microphoneButton.setTitle("Start Recording", for: .normal)
        } else {
            startRecording()
            microphoneButton.setTitle("Stop Recording", for: .normal)
        }
	}

    func startRecording() {
        //检查 recognitionTask 是否在运行，如果在就取消任务和识别。
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }
        
        //创建一个 AVAudioSession来为记录语音做准备，在这里我们设置session的类别为recording，模式为measurement，然后激活它。
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(AVAudioSessionCategoryRecord)
            try audioSession.setMode(AVAudioSessionModeMeasurement)
            try audioSession.setActive(true, with: .notifyOthersOnDeactivation)
        } catch {
            print("audioSession properties weren't set because of an error.")
        }
        
        //实例化recognitionRequest，在这里我们创建了SFSpeechAudioBufferRecognitionRequest对象，利用它把语音数据传到苹果后台。
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        //检查 audioEngine（你的设备）是否有做录音功能作为语音输入，如果没有，我们就报告一个错误。
        guard let inputNode = audioEngine.inputNode else {
            fatalError("Audio engine has no input node")
        }
        
        //检查recognitionRequest对象是否被实例化并且不为nil
        guard let recognitionRequest = recognitionRequest else {
            fatalError("Unable to create an SFSpeechAudioBufferRecognitionRequest object")
        }
        
        //当用户说话的时候让recognitionRequest报告语音识别的部分结果
        recognitionRequest.shouldReportPartialResults = true
        
        //调用 speechRecognizer的recognitionTask 方法来开启语音识别。这个方法有一个completion handler回调，这个回调每次都会在识别引擎收到输入的时候，完善了当前识别的信息时候，或者被删除或者停止的时候被调用，最后会返回一个最终的文本。
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest, resultHandler: { (result, error) in
            
            //定义一个布尔值决定识别是否已经结束
            var isFinal = false
            
            if result != nil {
                //如果结果 result 不是nil, 把 textView.text 的值设置为我们的最优文本。如果结果是最终结果，设置 isFinal为true。
                self.textView.text = result?.bestTranscription.formattedString
                isFinal = (result?.isFinal)!
            }
            
            if error != nil || isFinal {
                //如果没有错误或者结果是最终结果，停止 audioEngine(语音输入)并且停止 recognitionRequest 和 recognitionTask.同时，使Start Recording按钮有效。
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                
                self.recognitionRequest = nil
                self.recognitionTask = nil
                
                self.microphoneButton.isEnabled = true
            }
        })
        
        //向 recognitionRequest增加一个语音输入，注意在开始了recognitionTask之后增加语音输入是OK的，Speech Framework 会在语音输入被加入的同时就开始进行解析识别。
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, when) in
            self.recognitionRequest?.append(buffer)
        }
        
        //准备并且开始audioEngine
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            print("audioEngine couldn't start because of an error.")
        }
        
        textView.text = "Say something, I'm listening!"
    }
    
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
            microphoneButton.isEnabled = true
        } else {
            microphoneButton.isEnabled = false
        }
    }
}
