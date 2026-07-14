//
//  UserProfile.swift
//  Horology Vault
//
//  Created by Angel Burgos on 7/10/26.
//

import Foundation
import SwiftData

@Model
final class UserProfile {
    var wristTopWidthCM: Double
    var wristSideDepthCM: Double

    init(wristTopWidthCM: Double, wristSideDepthCM: Double) {
        self.wristTopWidthCM = wristTopWidthCM
        self.wristSideDepthCM = wristSideDepthCM
    }
}
