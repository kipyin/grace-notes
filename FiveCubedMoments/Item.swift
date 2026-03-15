//
//  Item.swift
//  FiveCubedMoments
//
//  Created by Kip on 2026/3/15.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
