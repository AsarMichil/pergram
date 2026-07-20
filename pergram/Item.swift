//
//  Item.swift
//  pergram
//
//  Created by Asar on 2026-07-20.
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
