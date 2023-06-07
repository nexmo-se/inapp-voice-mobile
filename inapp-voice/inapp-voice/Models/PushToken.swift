//
//  PushToken.swift
//  inapp-voice
//
//  Created by iujie on 24/04/2023.
//

import Foundation

struct PushToken: Codable {
    static var user:Data? = nil
    static var voip:Data? = nil
    static var fcm:String? = nil
}
