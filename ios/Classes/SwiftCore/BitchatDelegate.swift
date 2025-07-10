import Foundation

/// Delegate protocol for BitchatCore callbacks
public protocol BitchatDelegate: AnyObject {
    
    /// Called when a new message is received
    func didReceiveMessage(_ message: BitchatMessage)
    
    /// Called when peer list is updated
    func didUpdatePeerList(_ peers: [PeerInfo])
    
    /// Called when connection status changes
    func didUpdateConnectionStatus(_ status: ConnectionStatus)
}

/// Message model for bitchat
public struct BitchatMessage {
    public let id: String
    public let senderId: String
    public let recipientId: String?
    public let content: String
    public let type: MessageType
    public let timestamp: Date
    public let isBroadcast: Bool
    public let isRelay: Bool
    public let isPrivate: Bool
    public let originalSender: String
    public let recipientNickname: String
    public let senderPeerID: String
    public let mentions: [String]
    public let channel: String
    public let isEncrypted: Bool
    public let encryptedContent: Data?
    public let sender: String
    
    public init(id: String, senderId: String, recipientId: String?, content: String, type: MessageType, timestamp: Date, isBroadcast: Bool, isRelay: Bool = false, isPrivate: Bool = false, originalSender: String = "", recipientNickname: String = "", senderPeerID: String = "", mentions: [String] = [], channel: String = "", isEncrypted: Bool = false, encryptedContent: Data? = nil, sender: String = "") {
        self.id = id
        self.senderId = senderId
        self.recipientId = recipientId
        self.content = content
        self.type = type
        self.timestamp = timestamp
        self.isBroadcast = isBroadcast
        self.isRelay = isRelay
        self.isPrivate = isPrivate
        self.originalSender = originalSender
        self.recipientNickname = recipientNickname
        self.senderPeerID = senderPeerID
        self.mentions = mentions
        self.channel = channel
        self.isEncrypted = isEncrypted
        self.encryptedContent = encryptedContent
        self.sender = sender
    }
}

/// Peer information model
public struct PeerInfo {
    public let id: String
    public let nickname: String
    public let rssi: Int
    public let lastSeen: Date
    public let isConnected: Bool
    
    public init(id: String, nickname: String, rssi: Int, lastSeen: Date, isConnected: Bool) {
        self.id = id
        self.nickname = nickname
        self.rssi = rssi
        self.lastSeen = lastSeen
        self.isConnected = isConnected
    }
}

/// Connection status model
public struct ConnectionStatus {
    public let isConnected: Bool
    public let peerCount: Int
    public let error: String?
    
    public init(isConnected: Bool, peerCount: Int, error: String?) {
        self.isConnected = isConnected
        self.peerCount = peerCount
        self.error = error
    }
}

/// Message types
public enum MessageType: UInt8 {
    case announce = 0x01
    case keyExchange = 0x02
    case leave = 0x03
    case message = 0x04
    case fragmentStart = 0x05
    case fragmentContinue = 0x06
    case fragmentEnd = 0x07
    case channelAnnounce = 0x08
    case channelRetention = 0x09
    case deliveryAck = 0x0A
    case deliveryStatusRequest = 0x0B
    case readReceipt = 0x0C
} 