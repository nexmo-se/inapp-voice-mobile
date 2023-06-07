//
//  CallStatusModel.swift
//  inapp-voice
//
//  Created by iujie on 27/04/2023.
//

import Foundation
import CallKit

enum CallState {
    case ringing
    case answered
    case completed(remote:Bool, reason:CXCallEndedReason?)
}
extension CallState: Equatable {}


enum CallType {
    case inbound
    case outbound
}

struct CallStatusModel {
    let uuid: UUID?
    let state: CallState
    let type: CallType
    let member: String?
    let message: String?
}
