import Flutter
import UIKit
import Foundation
import CoreBluetooth
import CryptoKit
import Combine

/// Flutter plugin for BitchatCore
/// Provides simplified interface to Swift bitchat implementation
public class BitchatCorePlugin: NSObject, FlutterPlugin {
    
    private var methodChannel: FlutterMethodChannel?
    private var eventChannel: FlutterEventChannel?
    private var eventSink: FlutterEventSink?
    
    // Bitchat service instance
    private var bitchatService: BluetoothMeshService?
    private var myPeerId: String?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "bitchat_core", binaryMessenger: registrar.messenger())
        let instance = BitchatCorePlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        
        // Setup event channel for real-time updates
        let eventChannel = FlutterEventChannel(name: "bitchat_core_events", binaryMessenger: registrar.messenger())
        eventChannel.setStreamHandler(instance)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            handleInitialize(call.arguments as? [String: Any], result: result)
        case "start":
            handleStart(result: result)
        case "stop":
            handleStop(result: result)
        case "getPeerList":
            handleGetPeerList(result: result)
        case "sendMessage":
            handleSendMessage(call.arguments as? [String: Any], result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - Core Methods
    
    private func handleInitialize(_ arguments: [String: Any]?, result: @escaping FlutterResult) {
        guard let args = arguments,
              let myPeerId = args["myPeerId"] as? String else {
            result(false)
            return
        }
        
        let nickname = args["nickname"] as? String ?? myPeerId
        let enableBluetooth = args["enableBluetooth"] as? Bool ?? true
        let enableMesh = args["enableMesh"] as? Bool ?? true
        
        // Initialize bitchat service with full functionality
        bitchatService = BluetoothMeshService()
        bitchatService?.myPeerID = myPeerId
        self.myPeerId = myPeerId
        
        // Setup delegate for callbacks
        bitchatService?.delegate = self
        
        result(true)
    }
    
    private func handleStart(result: @escaping FlutterResult) {
        guard let service = bitchatService else {
            result(false)
            return
        }
        
        // Start the service
        service.startService()
        result(true)
    }
    
    private func handleStop(result: @escaping FlutterResult) {
        guard let service = bitchatService else {
            result(false)
            return
        }
        
        // Stop the service
        service.stopService()
        result(true)
    }
    
    private func handleGetPeerList(result: @escaping FlutterResult) {
        guard let service = bitchatService else {
            result([])
            return
        }
        
        // Get current peer list from service
        let peers = service.getActivePeers().map { peerId in
            return [
                "id": peerId,
                "nickname": service.getPeerNickname(for: peerId) ?? peerId,
                "rssi": service.getPeerRSSI(for: peerId) ?? 0,
                "lastSeen": service.getPeerLastSeen(for: peerId)?.timeIntervalSince1970 ?? 0,
                "isConnected": service.isPeerConnected(peerId)
            ]
        }
        
        result(peers)
    }
    
    private func handleSendMessage(_ arguments: [String: Any]?, result: @escaping FlutterResult) {
        guard let args = arguments,
              let message = args["message"] as? String,
              let service = bitchatService else {
            result(false)
            return
        }
        
        let recipientId = args["recipientId"] as? String
        let type = args["type"] as? Int ?? 4 // Default to message type
        let ttl = args["ttl"] as? Int ?? 5
        
        // Create bitchat packet
        let packet = BitchatPacket(
            type: UInt8(type),
            ttl: UInt8(ttl),
            senderID: myPeerId ?? "",
            payload: message.data(using: .utf8) ?? Data()
        )
        
        // Send message
        if let recipientId = recipientId {
            // Send to specific peer
            service.sendMessage(packet, to: recipientId)
        } else {
            // Broadcast message
            service.broadcastMessage(packet)
        }
        
        result(true)
    }
    
    // MARK: - Event Sink Management
    
    private func sendEvent(type: String, data: Any) {
        guard let sink = eventSink else { return }
        
        let event: [String: Any] = [
            "type": type,
            "data": data
        ]
        
        sink(event)
    }
}

// MARK: - BitchatDelegate Implementation

extension BitchatCorePlugin: BitchatDelegate {
    
    public func didReceiveMessage(_ message: BitchatMessage) {
        // Convert to Dart format and send via event sink
        let messageData: [String: Any] = [
            "id": message.id,
            "senderId": message.senderId,
            "recipientId": message.recipientId,
            "content": message.content,
            "type": message.type.rawValue,
            "timestamp": message.timestamp.timeIntervalSince1970 * 1000,
            "isBroadcast": message.isBroadcast
        ]
        
        sendEvent(type: "message", data: messageData)
    }
    
    public func didUpdatePeerList(_ peers: [PeerInfo]) {
        // Convert to Dart format and send via event sink
        let peerList = peers.map { peer in
            return [
                "id": peer.id,
                "nickname": peer.nickname,
                "rssi": peer.rssi,
                "lastSeen": peer.lastSeen.timeIntervalSince1970 * 1000,
                "isConnected": peer.isConnected
            ]
        }
        
        sendEvent(type: "peerList", data: peerList)
    }
    
    public func didUpdateConnectionStatus(_ status: ConnectionStatus) {
        // Convert to Dart format and send via event sink
        let statusData: [String: Any] = [
            "isConnected": status.isConnected,
            "peerCount": status.peerCount,
            "error": status.error
        ]
        
        sendEvent(type: "connection", data: statusData)
    }
}

// MARK: - FlutterStreamHandler Implementation

extension BitchatCorePlugin: FlutterStreamHandler {
    
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
}

// MARK: - Helper Extensions

extension BluetoothMeshService {
    
    func getActivePeers() -> [String] {
        // Return list of active peer IDs
        return Array(activePeers)
    }
    
    func getPeerNickname(for peerId: String) -> String? {
        return peerNicknames[peerId]
    }
    
    func getPeerRSSI(for peerId: String) -> Int? {
        return peerRSSI[peerId]?.intValue
    }
    
    func getPeerLastSeen(for peerId: String) -> Date? {
        return peerLastSeenTimestamps[peerId]
    }
    
    func isPeerConnected(_ peerId: String) -> Bool {
        return connectedPeripherals.values.contains { peripheral in
            peripheral.identifier.uuidString == peerId
        }
    }
} 