//
//  Reachability.swift
//  inapp-voice
//
//  Created by iujie on 07/07/2023.
//

import Network
import UserNotifications

class Reachability {
   static let shared = Reachability()

   let monitorForWifi = NWPathMonitor(requiredInterfaceType: .wifi)
   let monitorForCellular = NWPathMonitor(requiredInterfaceType: .cellular)
   private var wifiStatus: NWPath.Status = .requiresConnection
   private var cellularStatus: NWPath.Status = .requiresConnection
   var isReachable: Bool { wifiStatus == .satisfied || isReachableOnCellular }
   var isReachableOnCellular: Bool { cellularStatus == .satisfied }
   var isNetworkConnected = false

   func startMonitoring() {
       monitorForWifi.pathUpdateHandler = { [weak self] path in
           self?.wifiStatus = path.status

           if path.status == .satisfied {
               if (self?.isNetworkConnected == false) {
                   self?.isNetworkConnected = true
                   NotificationCenter.default.post(name: .networkConnectionStatusChanged, object: nil)
               }
           } else {
               if (self?.isNetworkConnected == true) {
                   self?.isNetworkConnected = false
                   NotificationCenter.default.post(name: .networkConnectionStatusChanged, object: nil)
               }
           }
       }
       monitorForCellular.pathUpdateHandler = { [weak self] path in
           self?.cellularStatus = path.status

           if path.status == .satisfied {
               if (self?.isNetworkConnected == false) {
                   self?.isNetworkConnected = true
                   NotificationCenter.default.post(name: .networkConnectionStatusChanged, object: nil)
               }
           } else {
               if (self?.isNetworkConnected == true) {
                   self?.isNetworkConnected = false
                   NotificationCenter.default.post(name: .networkConnectionStatusChanged, object: nil)
               }
           }
       }

       let queue = DispatchQueue(label: "NetworkMonitor")
       monitorForCellular.start(queue: queue)
       monitorForWifi.start(queue: queue)
   }

   func stopMonitoring() {
       monitorForWifi.cancel()
       monitorForCellular.cancel()
   }
   
   class func isConnectedToNetwork() -> Bool {
       return shared.isReachable
   }
}
