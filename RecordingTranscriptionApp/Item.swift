//
//  Item.swift
//  RecordingTranscriptionApp
//
//  Created by kamakoma wu on 2025/5/11.
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
