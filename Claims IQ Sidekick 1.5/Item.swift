//
//  Item.swift
//  Claims IQ Sidekick 1.5
//
//  Created by John Shoust on 2025-11-07.
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
