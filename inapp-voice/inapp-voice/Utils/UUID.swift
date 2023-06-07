//
//  UUID.swift
//  inapp-voice
//
//  Created by iujie on 25/04/2023.
//

import Foundation

extension UUID {
    func toVGCallID() -> String {
        return self.uuidString.lowercased()
    }
}

