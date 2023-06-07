//
//  User.swift
//  inapp-voice
//
//  Created by iujie on 20/04/2023.
//

import Foundation

struct UserModel: Codable {
    let username: String
    let userId: String
    let token: String
    let region: String
    let dc: String
    let ws: String
}
