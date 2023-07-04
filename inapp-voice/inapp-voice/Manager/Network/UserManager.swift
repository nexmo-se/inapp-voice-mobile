//
//  NetworkManager.swift
//  inapp-voice
//
//  Created by iujie on 19/04/2023.
//

import Foundation

protocol UserManagerDelegate {
    func didUpdateUser(user: UserModel)
    func handleUserManagerError(message: String)
}

struct UserManager {
    var delegate: UserManagerDelegate?
    
    func fetchCredential(username:String, region: String, pin: String?, token: String?, attempt:Int = 3) {
        
        var parameters: [String: String] = [
            "username": username,
            "region": region
        ]
        
        if (pin != nil) {
            parameters["pin"] = pin!
        }
        else if (token != nil) {
            parameters["token"] = token!
        }
        
        if let url = URL(string: "\(Constants.backendURL)/getCredential") {
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"

            request.addValue("application/json", forHTTPHeaderField: "Content-Type") // change as per server requirements
            request.addValue("application/json", forHTTPHeaderField: "Accept")
            
  
            do {
              // convert parameters to Data and assign dictionary to httpBody of request
              request.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: .prettyPrinted)
            } catch let error {
                self.delegate?.handleUserManagerError(message: "Fetch Credential JsonSerialization Error: \(error.localizedDescription)")
                return
            }
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if error != nil {
                    if (attempt > 0) {
                        self.fetchCredential(username:username, region: region, pin: pin, token: token, attempt: attempt - 1)
                    }
                    else {
                        self.delegate?.handleUserManagerError(message: "Fetch Credential API Error: \(error!.localizedDescription)")
                    }
                    return
                }
                if let httpResponse = response as? HTTPURLResponse {
                    if (httpResponse.statusCode != 200) {
                        if (attempt > 0) {
                            self.fetchCredential(username:username, region: region, pin: pin, token: token, attempt: attempt - 1)
                        }
                        else {
                            self.delegate?.handleUserManagerError(message: "Failed to get credential, status code \(httpResponse.statusCode)")
                        }
                        return
                    }
                }
                if let safeData = data {
                    if let user = self.parseJSON(credentialData: safeData) {
                        self.delegate?.didUpdateUser(user: user)
                    }
                    else {
                        self.delegate?.handleUserManagerError(message: "Failed to parse credential data, \(safeData)")
                    }
                }
            }.resume()
        }
    }

    func deleteUser(user: UserModel) {
        let parameters: [String: String] = [
            "userId": user.userId,
            "dc": user.dc,
            "token": user.token
        ]
        
        if let url = URL(string: "\(Constants.backendURL)/deleteUser") {
            
            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"

            request.addValue("application/json", forHTTPHeaderField: "Content-Type") // change as per server requirements
            request.addValue("application/json", forHTTPHeaderField: "Accept")
            
  
            do {
              // convert parameters to Data and assign dictionary to httpBody of request
              request.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: .prettyPrinted)
            } catch let error {
                self.delegate?.handleUserManagerError(message: "Delete User JsonSerialization Error: \(error.localizedDescription)")
                return
            }
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if error != nil {
                    self.delegate?.handleUserManagerError(message: "Delete User API Error: \(error!.localizedDescription)")
                    return
                }
                if let httpResponse = response as? HTTPURLResponse {
                    if (httpResponse.statusCode != 200) {
                        self.delegate?.handleUserManagerError(message: "Fail to delete user, status code \(httpResponse.statusCode)")
                        return
                    }
                }
            }.resume()
        }
    }
    
    func parseJSON(credentialData: Data) -> UserModel?{
        let decoder = JSONDecoder()
        do {
            let decodedData = try decoder.decode(UserModel.self, from: credentialData)
            return decodedData
        } catch {
            print("parse json error: ", error)
            return nil
        }
    }
}
