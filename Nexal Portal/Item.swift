//
//  Item.swift
//  Nexal Portal
//
//  Created by John George on 8/25/26.
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
