//
//  Item.swift
//  Notifly-app
//
//  Created by Gary Yang on 29/4/2026.
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
