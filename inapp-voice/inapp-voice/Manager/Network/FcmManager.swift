//
//  FcmManager.swift
//  inapp-voice
//
//  Created by iujie on 07/06/2023.
//

import Foundation


struct FcmManager {
    func registerFcm(user: UserModel, fcmToken: String) {
              
        let parameters: [String: String] = [
            "dc": user.dc,
            "token": user.token,
            "fcmToken": fcmToken
        ]
        
        if let url = URL(string: "\(Constants.backendURL)/registerFcm") {
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"

            request.addValue("application/json", forHTTPHeaderField: "Content-Type") // change as per server requirements
            request.addValue("application/json", forHTTPHeaderField: "Accept")
            
  
            do {
              // convert parameters to Data and assign dictionary to httpBody of request
              request.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: .prettyPrinted)
            } catch let error {
                print("registerToken error \(error)")
                return
            }
            
            URLSession.shared.dataTask(with: request).resume()
        }
    }
    
    func unregisterFcm(user: UserModel) {
              
        let parameters: [String: String] = [
            "dc": user.dc,
            "token": user.token
        ]
        
        if let url = URL(string: "\(Constants.backendURL)/unregisterFcm") {
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"

            request.addValue("application/json", forHTTPHeaderField: "Content-Type") // change as per server requirements
            request.addValue("application/json", forHTTPHeaderField: "Accept")
            
  
            do {
              // convert parameters to Data and assign dictionary to httpBody of request
              request.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: .prettyPrinted)
            } catch let error {
                print("registerToken error \(error)")
                return
            }
            
            URLSession.shared.dataTask(with: request).resume()
        }
    }
}
