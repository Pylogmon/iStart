//
//  Item.swift
//  iStart
//
//  Created by 胡国洋 on 2026/5/16.
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
