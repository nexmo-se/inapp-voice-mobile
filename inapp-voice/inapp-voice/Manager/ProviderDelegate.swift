//
//  ProviderDelegate.swift
//  inapp-voice
//
//  Created by iujie on 25/04/2023.
//

import Foundation
import CallKit
import AVFoundation
import VonageClientSDKVoice

struct PushCall {
    var call: String?
    var uuid: UUID?
    var answerAction: CXAnswerCallAction?
}

final class ProviderDelegate: NSObject {
    private let provider: CXProvider
    private let callController = CXCallController()
    private var activeCall: PushCall? = PushCall()
    var voiceClient: VGVoiceClient
    
    init(voiceClient: VGVoiceClient) {
        provider = CXProvider(configuration: ProviderDelegate.providerConfiguration)
        super.init()
        provider.setDelegate(self, queue: nil)
        
        self.voiceClient = voiceClient
        
//        NotificationCenter.default.addObserver(self, selector: #selector(callReceived(_:)), name: .incomingCall, object: nil)
//        NotificationCenter.default.addObserver(self, selector: #selector(callHandled), name: .handledCallApp, object:nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    static var providerConfiguration: CXProviderConfiguration = {
        let providerConfiguration = CXProviderConfiguration()
        providerConfiguration.supportsVideo = false
        providerConfiguration.maximumCallsPerCallGroup = 1
        providerConfiguration.supportedHandleTypes = [.generic]
        return providerConfiguration
    }()
}

extension ProviderDelegate: CXProviderDelegate {
    func providerDidReset(_ provider: CXProvider) {
        activeCall = PushCall()
    }
    
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        NotificationCenter.default.post(name: .handledCallCallKit, object: nil)
        configureAudioSession()
        activeCall?.answerAction = action
        
        if activeCall?.call != nil {
            action.fulfill()
        }
    }
    
    private func answerCall(with action: CXAnswerCallAction) {
        activeCall?.call?.answer(nil)
        activeCall?.call?.setDelegate(self)
        activeCall?.uuid = action.callUUID
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        hangup()
        action.fulfill()
    }

    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        assert(activeCall?.answerAction != nil, "Call not ready - see provider(_:perform:CXAnswerCallAction)")
        assert(activeCall?.call != nil, "Call not ready - see callReceived")
        answerCall(with: activeCall!.answerAction!)
    }

    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        hangup()
    }

    func reportCall(callerID: String) {
        let update = CXCallUpdate()
        let callerUUID = UUID()
        
        update.remoteHandle = CXHandle(type: .generic, value: callerID)
        update.localizedCallerName = callerID
        update.hasVideo = false
        
        provider.reportNewIncomingCall(with: callerUUID, update: update) { [weak self] error in
            guard error == nil else { return }
            self?.activeCall?.uuid = callerUUID
        }
    }

    /*
     If the app is in the foreground and the call is answered via the
     ViewController alert, there is no need to display the CallKit UI.
     */
    @objc private func callHandled() {
        provider.invalidate()
    }

    @objc private func callReceived(_ notification: NSNotification) {
        if let call = notification.object as? NXMCall {
            activeCall?.call = call
            activeCall?.answerAction?.fulfill()
        }
    }

    // When the device is locked, the AVAudioSession needs to be configured.
    private func configureAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(AVAudioSession.Category.playAndRecord, mode: .default)
            try audioSession.setMode(AVAudioSession.Mode.voiceChat)
        } catch {
            print(error)
        }
    }
}

