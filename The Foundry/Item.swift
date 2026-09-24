//
//  Item.swift
//  The Foundry
//
//  Created by Nicholas Coppola on 9/24/26.
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
