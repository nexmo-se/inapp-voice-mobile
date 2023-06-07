//
//  VonageClientStatusModel.swift
//  inapp-voice
//
//  Created by iujie on 27/04/2023.
//

import Foundation

enum VonageClientState {
    case connected
    case disconnected
}


struct VonageClientStatusModel {
    let state: VonageClientState
    let message: String?
}
