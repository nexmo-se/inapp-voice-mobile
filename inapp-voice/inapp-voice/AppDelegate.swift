//
//  AppDelegate.swift
//  inapp-voice
//
//  Created by iujie on 19/04/2023.
//

import UIKit
import AVFoundation
import PushKit
import FirebaseCore
import FirebaseMessaging

var window:UIWindow?

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    private let voipRegistry = PKPushRegistry(queue: nil)
    var vgclient = VonageClient.shared
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        UIApplication.shared.delegate = self
        
        // Configure Firebase
        FirebaseApp.configure()
        
        self.initialisePushTokens()
        // Application onboarding
        let mediaType = AVMediaType.audio
        let authorizationStatus = AVCaptureDevice.authorizationStatus(for: mediaType)
        switch authorizationStatus {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: mediaType) { granted in
                print("🎤 access \(granted ? "granted" : "denied")")
            }
        case .authorized, .denied, .restricted:
            print("auth")
        }

        // try? AVAudioSession.sharedInstance().setCategory(.playAndRecord)

        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
    // MARK: Notifications
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        PushToken.user = deviceToken
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        let alert = createAlert(message: "Register notification error: \(error.localizedDescription)", completion: nil)
        
        print("register notification error")
        // show the alert
        UIApplication.shared.delegate?.window??.rootViewController?.present(alert, animated: true, completion: nil)
    }
    
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any]) async
    -> UIBackgroundFetchResult {
        // Print message ID.

        print("receive silent notification")
        if let message = userInfo["message"] as? String{
            if (message == "updateUsersState") {
                NotificationCenter.default.post(name: .updateCallMembersStatus, object: nil)
            }
        }
        return UIBackgroundFetchResult.newData
    }
}

extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("Firebase registration token: \(String(describing: fcmToken))")
        PushToken.fcm = fcmToken
    }
}

extension AppDelegate: PKPushRegistryDelegate {
    func initialisePushTokens() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            if granted {
                DispatchQueue.main.async {[weak self] in
                    if (self == nil) {return}
                    
                    UIApplication.shared.registerForRemoteNotifications()
                    
                    Messaging.messaging().delegate = self
                    print("is granted!")
                    self!.voipRegistry.delegate = self
                    self!.voipRegistry.desiredPushTypes = [PKPushType.voIP]
                }
            }
        }
    }
    
    func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        if (type == PKPushType.voIP) {
            PushToken.voip = pushCredentials.token
        }
    }
    
    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
        switch (type){
        case .voIP:
            processNotification(payload: payload)
        default:
            return
        }
        completion()
    }
    
    private func processNotification(payload: PKPushPayload) {
        if let data = UserDefaults.standard.data(forKey: Constants.userKey) {
            do {
                let decoder = JSONDecoder()
                let user = try decoder.decode(UserModel.self, from: data)
                
                vgclient.login(user: user)
                vgclient.voiceClient.processCallInvitePushData(payload.dictionaryPayload)
                
            }
            catch {
                // no notification
            }
        }
    }
}

extension Notification.Name {
    static let clientStatus = Notification.Name("ClientStatus")
    static let callStatus = Notification.Name("CallStatus")
    static let handledCallData = Notification.Name("CallData")
    static let updateCallMembersStatus = Notification.Name("UpdateCallMembers")
    static let micState = Notification.Name("micState")
}


