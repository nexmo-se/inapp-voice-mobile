//
//  MembersManager.swift
//  inapp-voice
//
//  Created by iujie on 21/04/2023.
//

import Foundation

protocol MembersManagerDelegate {
    func didUpdateMembers(memberList: MemberModel)
    func handleMembersManagerError(message: String)
}

struct MembersManager {
    var delegate: MembersManagerDelegate?
    
    func fetchMembers(user: UserModel) {
              
        let parameters: [String: String] = [
            "username": user.username,
            "dc": user.dc,
            "token": user.token
        ]
        
        if let url = URL(string: "\(Constants.backendURL)/getMembers") {
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"

            request.addValue("application/json", forHTTPHeaderField: "Content-Type") // change as per server requirements
            request.addValue("application/json", forHTTPHeaderField: "Accept")
            
  
            do {
              // convert parameters to Data and assign dictionary to httpBody of request
              request.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: .prettyPrinted)
            } catch let error {
                self.delegate?.handleMembersManagerError(message: "Fetch Member JsonSerialization Error: \(error.localizedDescription)")
                return
            }
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if error != nil {
                    self.delegate?.handleMembersManagerError(message: "Fetch Member API Error: \(error!.localizedDescription)")
                    return
                }
                if let httpResponse = response as? HTTPURLResponse {
                    if (httpResponse.statusCode != 200) {
                        self.delegate?.handleMembersManagerError(message: "Failed to get members, status code: \(httpResponse.statusCode)")
                        return
                    }
                }
                if let safeData = data {
                    if let members = self.parseJSON(membersData: safeData) {
                        self.delegate?.didUpdateMembers(memberList: members)
                    }
                    else {
                        self.delegate?.handleMembersManagerError(message: "Failed to parse members data \(safeData)")
                    }
                }
            }.resume()
        }
    }

    
    func parseJSON(membersData: Data) -> MemberModel?{
        let decoder = JSONDecoder()
        do {
            let decodedData = try decoder.decode(MemberModel.self, from: membersData)
            return decodedData
        } catch {
            print("parse json error: ", error)
            return nil
        }
    }
}
