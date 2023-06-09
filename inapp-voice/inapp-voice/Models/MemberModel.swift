//
//  Member.swift
//  inapp-voice
//
//  Created by iujie on 21/04/2023.
//

import Foundation

struct MemberModel: Decodable {
    let members: memberStateModel
}

struct memberStateModel: Decodable {
    let available: [String]
    let busy: [String]
}
