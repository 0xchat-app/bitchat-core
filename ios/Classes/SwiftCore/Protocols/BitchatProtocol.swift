//
// BitchatProtocol.swift
// bitchat
//
// This is free and unencumbered software released into the public domain.
// For more information, see <https://unlicense.org>
//

import Foundation
import CryptoKit

// Privacy-preserving padding utilities
struct MessagePadding {
    // Standard block sizes for padding
    static let blockSizes = [256, 512, 1024, 2048]
    
    // Add PKCS#7-style padding to reach target size
    static func pad(_ data: Data, toSize targetSize: Int) -> Data {
        guard data.count < targetSize else { return data }
        
        let paddingNeeded = targetSize - data.count
        
        // PKCS#7 only supports padding up to 255 bytes
        // If we need more padding than that, don't pad - return original data
        guard paddingNeeded <= 255 else { return data }
        
        var padded = data
        
        // Standard PKCS#7 padding
        var randomBytes = [UInt8](repeating: 0, count: paddingNeeded - 1)
        _ = SecRandomCopyBytes(kSecRandomDefault, paddingNeeded - 1, &randomBytes)
        padded.append(contentsOf: randomBytes)
        padded.append(UInt8(paddingNeeded))
        
        return padded
    }
    
    // Remove padding from data
    static func unpad(_ data: Data) -> Data {
        guard !data.isEmpty else { return data }
        
        // Last byte tells us how much padding to remove
        let paddingLength = Int(data[data.count - 1])
        guard paddingLength > 0 && paddingLength <= data.count else { return data }
        
        return data.prefix(data.count - paddingLength)
    }
    
    // Find optimal block size for data
    static func optimalBlockSize(for dataSize: Int) -> Int {
        // Account for encryption overhead (~16 bytes for AES-GCM tag)
        let totalSize = dataSize + 16
        
        // Find smallest block that fits
        for blockSize in blockSizes {
            if totalSize <= blockSize {
                return blockSize
            }
        }
        
        // For very large messages, just use the original size
        // (will be fragmented anyway)
        return dataSize
    }
}

// Special recipient ID for broadcast messages
struct SpecialRecipients {
    static let broadcast = Data(repeating: 0xFF, count: 8)  // All 0xFF = broadcast
}

public struct BitchatPacket: Codable {
    let version: UInt8
    let type: UInt8
    let senderID: Data
    let recipientID: Data?
    let timestamp: UInt64
    let payload: Data
    let signature: Data?
    var ttl: UInt8
    
    init(type: UInt8, senderID: Data, recipientID: Data?, timestamp: UInt64, payload: Data, signature: Data?, ttl: UInt8) {
        self.version = 1
        self.type = type
        self.senderID = senderID
        self.recipientID = recipientID
        self.timestamp = timestamp
        self.payload = payload
        self.signature = signature
        self.ttl = ttl
    }
    
    // Convenience initializer for new binary format
    init(type: UInt8, ttl: UInt8, senderID: String, payload: Data) {
        self.version = 1
        self.type = type
        self.senderID = senderID.data(using: .utf8)!
        self.recipientID = nil
        self.timestamp = UInt64(Date().timeIntervalSince1970 * 1000) // milliseconds
        self.payload = payload
        self.signature = nil
        self.ttl = ttl
    }
    
    var data: Data? {
        BinaryProtocol.encode(self)
    }
    
    func toBinaryData() -> Data? {
        BinaryProtocol.encode(self)
    }
    
    static func from(_ data: Data) -> BitchatPacket? {
        BinaryProtocol.decode(data)
    }
}

// Delivery acknowledgment structure
public struct DeliveryAck: Codable {
    let originalMessageID: String
    let ackID: String
    let recipientID: String  // Who received it
    let recipientNickname: String
    let timestamp: Date
    let hopCount: UInt8  // How many hops to reach recipient
    
    init(originalMessageID: String, recipientID: String, recipientNickname: String, hopCount: UInt8) {
        self.originalMessageID = originalMessageID
        self.ackID = UUID().uuidString
        self.recipientID = recipientID
        self.recipientNickname = recipientNickname
        self.timestamp = Date()
        self.hopCount = hopCount
    }
    
    func encode() -> Data? {
        try? JSONEncoder().encode(self)
    }
    
    static func decode(from data: Data) -> DeliveryAck? {
        try? JSONDecoder().decode(DeliveryAck.self, from: data)
    }
}

// Read receipt structure
public struct ReadReceipt: Codable {
    let originalMessageID: String
    let receiptID: String
    let readerID: String  // Who read it
    let readerNickname: String
    let timestamp: Date
    
    init(originalMessageID: String, readerID: String, readerNickname: String) {
        self.originalMessageID = originalMessageID
        self.receiptID = UUID().uuidString
        self.readerID = readerID
        self.readerNickname = readerNickname
        self.timestamp = Date()
    }
    
    func encode() -> Data? {
        try? JSONEncoder().encode(self)
    }
    
    static func decode(from data: Data) -> ReadReceipt? {
        try? JSONDecoder().decode(ReadReceipt.self, from: data)
    }
}

// Delivery status for messages
public enum DeliveryStatus: Codable, Equatable {
    case sending
    case sent  // Left our device
    case delivered(to: String, at: Date)  // Confirmed by recipient
    case read(by: String, at: Date)  // Seen by recipient
    case failed(reason: String)
    case partiallyDelivered(reached: Int, total: Int)  // For rooms
    
    var displayText: String {
        switch self {
        case .sending:
            return "Sending..."
        case .sent:
            return "Sent"
        case .delivered(let nickname, _):
            return "Delivered to \(nickname)"
        case .read(let nickname, _):
            return "Read by \(nickname)"
        case .failed(let reason):
            return "Failed: \(reason)"
        case .partiallyDelivered(let reached, let total):
            return "Delivered to \(reached)/\(total)"
        }
    }
}