//
//  VonageClient.swift
//  inapp-voice
//
//  Created by iujie on 20/04/2023.
//

import Foundation
import VonageClientSDKVoice
import CallKit
import PushKit
import UserNotifications
import UIKit

struct PushInfo {
    let user: Data
    let voip: Data
}

class VonageClient: NSObject {
    static let shared = VonageClient()
    var voiceClient = VGVoiceClient()
    var user: UserModel?
    var isLoggedIn: Bool = false

    var currentCallStatus: CallStatusModel? {
        didSet {
            if (currentCallStatus != nil) {
                NotificationCenter.default.post(name:.callStatus, object: currentCallStatus)
                updateCallKit(call: currentCallStatus!)
            }
        }
    }
    
    var currentCallData: CallDataModel? {
        didSet {
            if (currentCallData != nil) {
                NotificationCenter.default.post(name:.handledCallData, object: currentCallData)
            }
        }
    }
    
    var isMuted: Bool = false {
          didSet {
              NotificationCenter.default.post(name:.muteState, object: isMuted)
          }
      }
    
    // Callkit
    var callProvider: CXProvider!
    var cxController = CXCallController()
    
    override init() {
        super.init()
        // setup call provider
        var config: CXProviderConfiguration
        if #available(iOS 14.0, *) {
            config = CXProviderConfiguration()
            config.supportsVideo = false

        } else {
            config = CXProviderConfiguration(localizedName: "Vonage Call")
            config.supportsVideo = false
        }
        callProvider = CXProvider(configuration: config)
        callProvider.setDelegate(self, queue: nil)
    }
    
    func initClient(user: UserModel){
        self.user = user
        VGBaseClient.setDefaultLoggingLevel(.error)
        let voiceClient = VGVoiceClient()
        let config = VGClientConfig()
        config.apiUrl = user.dc
        config.websocketUrl = user.ws
        voiceClient.setConfig(config)
        self.voiceClient  = voiceClient
        self.voiceClient.delegate = self
    }
    
    func login(user: UserModel, attempt:Int = 3) {
        if (!Session.isLoggedIn) {
            self.initClient(user: user)
        }

        self.voiceClient.createSession(user.token) { error, session in
            if error == nil {
                if (!Session.isLoggedIn) {
                    self.registerPushTokens()
                    do {
                        let encoder = JSONEncoder()
                        
                        let data = try encoder.encode(user)
                        
                        UserDefaults.standard.set(data, forKey: Constants.userKey)
                        
                    } catch {
                        print("Fail to encode user")
                    }
                }
                Session.isLoggedIn = true
                NotificationCenter.default.post(name: .clientStatus, object: VonageClientStatusModel(state: .connected, message: nil))
                
            } else {
                if (attempt > 0) {
                    self.login(user: user, attempt: attempt - 1)
                }
                else {
                    NotificationCenter.default.post(name: .clientStatus, object: VonageClientStatusModel(state: .disconnected, message: error!.localizedDescription))
                }
            }
        }
    }
    
    func logout() {
        self.unregisterPushTokens()
        Session.isLoggedIn = false
        self.currentCallStatus = nil
        self.currentCallData = nil
        self.voiceClient.deleteSession { error in
            NotificationCenter.default.post(name: .clientStatus, object: VonageClientStatusModel(state: .disconnected, message: nil))
        }
        NotificationCenter.default.removeObserver(self)
    }
    
    func startOutboundCall(user: UserModel, member: String, attempt:Int = 3) {
        voiceClient.createSession(user.token) { error, session in
            if error == nil {
                self.voiceClient.serverCall(["to": member]) { error, callId in
                    if error != nil {
                        self.currentCallStatus = CallStatusModel(uuid: nil, state: .completed(remote: false, reason: .failed), type: .outbound, member: nil, message: error!.localizedDescription)
                    } else {
                        if let callId = callId {
                            self.currentCallStatus = CallStatusModel(uuid: UUID(uuidString: callId)!, state: .ringing, type: .outbound, member: member, message: nil)
                        }
                    }
                }
            } else {
                if (attempt > 0){
                    self.startOutboundCall(user: user, member: member, attempt: attempt - 1 )
                }
                else {
                    self.currentCallStatus = CallStatusModel(uuid: nil, state: .completed(remote: false, reason: .failed), type: .outbound, member: nil, message: error!.localizedDescription)
                }
            }
        }
    }
    
    func registerPushTokens() {
        if (PushToken.voip == nil || PushToken.user == nil) { return }
        UserDefaults.standard.set(PushToken.voip!, forKey: Constants.pushTokenKey)
        UserDefaults.standard.set(PushToken.user!, forKey: Constants.deviceTokenKey)
        
        self.voiceClient.registerDevicePushToken(PushToken.voip!, userNotificationToken: PushToken.user!, isSandbox: false) { error, device in
            if (error != nil) {
                self.logout()
            }
            UserDefaults.standard.set(device, forKey: Constants.deviceIdKey)
            print("register push token successfully")
        }
        
        if let user = user, let fcmToken = PushToken.fcm {
            FcmManager().registerFcm(user: user, fcmToken: fcmToken)
        }
    }
    
    func unregisterPushTokens() {
        let deviceId = UserDefaults.standard.string(forKey: Constants.deviceIdKey)
        if (deviceId == nil) {return}
        self.voiceClient.unregisterDeviceTokens(byDeviceId: deviceId!) { error in
            if (error == nil) {
                // Remove user only if successfully unregister the device, to avoid receive false voip push
                UserDefaults.standard.removeObject(forKey: Constants.userKey)
                UserDefaults.standard.removeObject(forKey: Constants.deviceIdKey)
            }
        }
        if let user = user {
            FcmManager().unregisterFcm(user: user)
        }
    }
    
    func hangUpCall(callId: String?, attempt:Int = 3) {
        if let callId = callId {
            voiceClient.hangup(callId) { error in
                if (error != nil) {
                    if (attempt > 0) {
                     self.hangUpCall(callId: callId, attempt: attempt-1)
                   }
                   else {
                       self.currentCallStatus = CallStatusModel(uuid: UUID(uuidString: callId)!, state: .completed(remote: false, reason: nil), type: self.currentCallStatus!.type, member: nil, message: nil)
                   }
                }
                else {
                    self.currentCallStatus = CallStatusModel(uuid: UUID(uuidString: callId)!, state: .completed(remote: false, reason: nil), type: self.currentCallStatus!.type, member: nil, message: nil)
                }
            }
        }
    }
    
    func rejectByCallkit(calluuid: UUID?) {
        if let calluuid = calluuid {
            let endCallAction = CXEndCallAction(call: calluuid)
            self.cxController.requestTransaction(with: endCallAction) { error in
                guard error == nil else {
                    self.hangUpCall(callId: calluuid.toVGCallID())
                    return
                }
            }
        }
    }
    
    func rejectCall(callId: String?, attempt:Int = 3) {
        if let callId = callId {
            voiceClient.reject(callId) { error in
                if (error != nil) {
                    if (attempt > 0) {
                        self.rejectCall(callId: callId, attempt: attempt-1)
                    }
                    else {
                        self.currentCallStatus = CallStatusModel(uuid: UUID(uuidString: callId)!, state: .completed(remote: true, reason: nil), type: .inbound, member: nil, message: error!.localizedDescription)
                    }
                }
                else {
                    self.currentCallStatus = CallStatusModel(uuid: UUID(uuidString: callId)!, state: .completed(remote: true, reason: nil), type: .inbound, member: nil, message: nil)
                }
            }
        }
    }
    
    func answerByCallkit(calluuid: UUID?) {
        if let calluuid = calluuid {
            
            let connectCallAction = CXAnswerCallAction(call: calluuid)
            self.cxController.requestTransaction(with: connectCallAction) { error in
                guard error == nil else {
                    self.hangUpCall(callId: calluuid.toVGCallID())
                    return
                }
            }
        }
    }
    
    func answercall(callId:String?, completion: @escaping (_ isSucess: Bool) -> (), attempt:Int = 3) {
        if let callId = callId {
            voiceClient.answer(callId) { error in
                if (error != nil) {
                    if (attempt > 0) {
                        self.answercall(callId: callId, completion: completion, attempt: attempt-1)
                    }
                    else {
                        self.currentCallStatus = CallStatusModel(uuid: nil, state: .completed(remote: true, reason: .failed), type: .inbound, member: nil, message: error!.localizedDescription)
                            completion(false)
                    }
                }
                else {
                    self.currentCallStatus = CallStatusModel(uuid: UUID(uuidString: callId)!, state: .answered, type: .inbound, member: self.currentCallStatus?.member, message: nil)
                    completion(true)
                }
            }
        }
        
    }
    
    func toggleMute(calluuid: UUID?) {
        if let calluuid = calluuid {
            let muteCallAction = CXSetMutedCallAction(call: calluuid, muted: !isMuted)
            self.cxController.requestTransaction(with: muteCallAction) { error in
                guard error == nil else {
                    print("cx unmute error")
                    return
                }
            }
        }
    }
    
    func updateCallKit(call: CallStatusModel) {
        if (call.uuid == nil) {return}
        
        if (call.type == .outbound) {
            switch(call.state) {
            case .ringing:
                if let to = call.member {
                    // Report Data
                    if let user = user {
                        self.currentCallData = CallDataModel(username: user.username, memberName: to, myLegId: call.uuid!.toVGCallID(), memberLegId: nil, region: user.region)
                    }
                    self.cxController.requestTransaction(
                        with: CXStartCallAction(call: call.uuid!, handle: CXHandle(type: .generic, value: to)),
                        completion: { error in
                            guard error == nil else {
                                self.hangUpCall(callId: call.uuid?.toVGCallID())
                                return
                            }
                            
                            self.callProvider.reportOutgoingCall(with: call.uuid!, startedConnectingAt: Date())
                        }
                    )
                }
            case .answered:
                self.callProvider.reportOutgoingCall(with: call.uuid!, connectedAt: Date())
                
            case .completed:
                self.callProvider.reportCall(with: call.uuid!, endedAt: Date(), reason: .remoteEnded)
            }
            
        }
        
        else if (call.type == .inbound) {
            switch (call.state) {
            case .ringing:
                let update = CXCallUpdate()
                update.localizedCallerName = call.member ?? "Vonage Call"
                update.supportsDTMF = false
                update.supportsHolding = false
                update.supportsGrouping = false
                update.hasVideo = false
                if let user = user, let from = call.member {
                    self.currentCallData = CallDataModel(username: user.username, memberName: from, myLegId: call.uuid!.toVGCallID(), memberLegId: nil, region: user.region)
                }
                self.callProvider.reportNewIncomingCall(with: call.uuid!, update: update) { error in
                    if error != nil {
                        self.rejectByCallkit(calluuid: call.uuid)
                    }
                }
            case .completed:
                self.callProvider.reportCall(with: call.uuid!, endedAt: Date(), reason: .remoteEnded)
                
            default:
                return
            }
        }
        
    }
}
