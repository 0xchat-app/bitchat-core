/// Message types for bitchat protocol
/// 
/// These define the different types of messages that can be sent
/// over the bitchat network.
class MessageTypes {
  // System messages (0-9)
  static const int ping = 0;
  static const int pong = 1;
  static const int peerDiscovery = 2;
  static const int keyExchange = 3;
  static const int channelAnnouncement = 4;
  
  // Chat messages (10-19)
  static const int channelMessage = 10;
  static const int privateMessage = 11;
  static const int channelJoin = 12;
  static const int channelLeave = 13;
  static const int channelPassword = 14;
  static const int channelTransfer = 15;
  
  // User management (20-29)
  static const int userNickname = 20;
  static const int userBlock = 21;
  static const int userUnblock = 22;
  static const int userStatus = 23;
  
  // Store and forward (30-39)
  static const int messageRequest = 30;
  static const int messageResponse = 31;
  static const int messageAck = 32;
  static const int messageRetry = 33;
  
  // Fragment handling (40-49)
  static const int messageFragment = 40;
  static const int fragmentRequest = 41;
  static const int fragmentResponse = 42;
  
  // Cover traffic (50-59)
  static const int dummyMessage = 50;
  static const int heartbeat = 51;
  
  // Error messages (90-99)
  static const int error = 90;
  static const int invalidMessage = 91;
  static const int rateLimit = 92;
  
  /// Check if message type is a system message
  static bool isSystemMessage(int type) {
    return type >= 0 && type <= 9;
  }
  
  /// Check if message type is a chat message
  static bool isChatMessage(int type) {
    return type >= 10 && type <= 19;
  }
  
  /// Check if message type is a user management message
  static bool isUserMessage(int type) {
    return type >= 20 && type <= 29;
  }
  
  /// Check if message type is a store and forward message
  static bool isStoreForwardMessage(int type) {
    return type >= 30 && type <= 39;
  }
  
  /// Check if message type is a fragment message
  static bool isFragmentMessage(int type) {
    return type >= 40 && type <= 49;
  }
  
  /// Check if message type is a cover traffic message
  static bool isCoverTraffic(int type) {
    return type >= 50 && type <= 59;
  }
  
  /// Check if message type is an error message
  static bool isErrorMessage(int type) {
    return type >= 90 && type <= 99;
  }
  
  /// Get human readable name for message type
  static String getName(int type) {
    switch (type) {
      case ping: return 'Ping';
      case pong: return 'Pong';
      case peerDiscovery: return 'Peer Discovery';
      case keyExchange: return 'Key Exchange';
      case channelAnnouncement: return 'Channel Announcement';
      case channelMessage: return 'Channel Message';
      case privateMessage: return 'Private Message';
      case channelJoin: return 'Channel Join';
      case channelLeave: return 'Channel Leave';
      case channelPassword: return 'Channel Password';
      case channelTransfer: return 'Channel Transfer';
      case userNickname: return 'User Nickname';
      case userBlock: return 'User Block';
      case userUnblock: return 'User Unblock';
      case userStatus: return 'User Status';
      case messageRequest: return 'Message Request';
      case messageResponse: return 'Message Response';
      case messageAck: return 'Message Ack';
      case messageRetry: return 'Message Retry';
      case messageFragment: return 'Message Fragment';
      case fragmentRequest: return 'Fragment Request';
      case fragmentResponse: return 'Fragment Response';
      case dummyMessage: return 'Dummy Message';
      case heartbeat: return 'Heartbeat';
      case error: return 'Error';
      case invalidMessage: return 'Invalid Message';
      case rateLimit: return 'Rate Limit';
      default: return 'Unknown ($type)';
    }
  }
} 