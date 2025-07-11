import 'dart:async';
import 'package:bitchat_flutter_plugin/bitchat_flutter_plugin.dart';

/// Simple API Test Script
/// This script tests the basic functionality of BitchatService
void main() async {
  print('🧪 Bitchat API Test');
  print('==================');
  
  final test = BitchatApiTest();
  await test.runAllTests();
}

class BitchatApiTest {
  final BitchatService _service = BitchatService();
  int _testCount = 0;
  int _passedTests = 0;
  
  /// Run all tests
  Future<void> runAllTests() async {
    print('\n🚀 Starting API tests...\n');
    
    // Test 1: Service creation
    await _testServiceCreation();
    
    // Test 2: Service initialization
    await _testServiceInitialization();
    
    // Test 3: Service start
    await _testServiceStart();
    
    // Test 4: Message sending
    await _testMessageSending();
    
    // Test 5: Service stop
    await _testServiceStop();
    
    // Test 6: Status monitoring
    await _testStatusMonitoring();
    
    // Show test results
    _showTestResults();
  }
  
  /// Test 1: Service creation
  Future<void> _testServiceCreation() async {
    _testCount++;
    print('📋 Test $_testCount: Service Creation');
    
    try {
      // Verify service instance creation
      final service = BitchatService();
      if (service != null) {
        _passedTests++;
        print('✅ Service creation successful');
      } else {
        print('❌ Service creation failed');
      }
    } catch (e) {
      print('❌ Service creation exception: $e');
    }
    
    print('');
  }
  
  /// Test 2: Service initialization
  Future<void> _testServiceInitialization() async {
    _testCount++;
    print('📋 Test $_testCount: Service Initialization');
    
    try {
      final success = await _service.initialize();
      if (success) {
        _passedTests++;
        print('✅ Service initialization successful');
      } else {
        print('❌ Service initialization failed');
      }
    } catch (e) {
      print('❌ Service initialization exception: $e');
    }
    
    print('');
  }
  
  /// Test 3: Service start
  Future<void> _testServiceStart() async {
    _testCount++;
    print('📋 Test $_testCount: Service Start');
    
    try {
      final success = await _service.start(
        peerID: 'test-peer-${DateTime.now().millisecondsSinceEpoch}',
        nickname: 'Test User',
      );
      
      if (success) {
        _passedTests++;
        print('✅ Service start successful');
        print('   Peer ID: ${_service.myPeerID}');
        print('   Nickname: ${_service.myNickname}');
        print('   Status: ${_service.status.name}');
      } else {
        print('❌ Service start failed');
      }
    } catch (e) {
      print('❌ Service start exception: $e');
    }
    
    print('');
  }
  
  /// Test 4: Message sending
  Future<void> _testMessageSending() async {
    _testCount++;
    print('📋 Test $_testCount: Message Sending');
    
    try {
      // Test broadcast message
      final broadcastSuccess = await _service.sendBroadcastMessage('Test broadcast message');
      if (broadcastSuccess) {
        print('✅ Broadcast message sent successfully');
        _passedTests++;
      } else {
        print('❌ Broadcast message sending failed');
      }
      
      // Test private message
      final privateSuccess = await _service.sendPrivateMessage(
        'test-recipient-id',
        'Test private message'
      );
      if (privateSuccess) {
        print('✅ Private message sent successfully');
        _passedTests++;
      } else {
        print('❌ Private message sending failed');
      }
      
      // Test channel message
      final channelSuccess = await _service.sendChannelMessage(
        'test-channel',
        'Test channel message'
      );
      if (channelSuccess) {
        print('✅ Channel message sent successfully');
        _passedTests++;
      } else {
        print('❌ Channel message sending failed');
      }
      
    } catch (e) {
      print('❌ Message sending exception: $e');
    }
    
    print('');
  }
  
  /// Test 5: Service stop
  Future<void> _testServiceStop() async {
    _testCount++;
    print('📋 Test $_testCount: Service Stop');
    
    try {
      await _service.stop();
      print('✅ Service stop successful');
      _passedTests++;
    } catch (e) {
      print('❌ Service stop exception: $e');
    }
    
    print('');
  }
  
  /// Test 6: Status monitoring
  Future<void> _testStatusMonitoring() async {
    _testCount++;
    print('📋 Test $_testCount: Status Monitoring');
    
    try {
      // Check status stream
      final statusStream = _service.statusStream;
      if (statusStream != null) {
        print('✅ Status stream available');
        _passedTests++;
      } else {
        print('❌ Status stream not available');
      }
      
      // Check message stream
      final messageStream = _service.messageStream;
      if (messageStream != null) {
        print('✅ Message stream available');
        _passedTests++;
      } else {
        print('❌ Message stream not available');
      }
      
      // Check peer stream
      final peerStream = _service.peerStream;
      if (peerStream != null) {
        print('✅ Peer stream available');
        _passedTests++;
      } else {
        print('❌ Peer stream not available');
      }
      
      // Check log stream
      final logStream = _service.logStream;
      if (logStream != null) {
        print('✅ Log stream available');
        _passedTests++;
      } else {
        print('❌ Log stream not available');
      }
      
    } catch (e) {
      print('❌ Status monitoring exception: $e');
    }
    
    print('');
  }
  
  /// Show test results
  void _showTestResults() {
    print('📊 Test Results');
    print('==========');
    print('Total tests: $_testCount');
    print('Passed tests: $_passedTests');
    print('Failed tests: ${_testCount - _passedTests}');
    print('Success rate: ${(_passedTests / _testCount * 100).toStringAsFixed(1)}%');
    
    if (_passedTests == _testCount) {
      print('\n🎉 All tests passed!');
    } else {
      print('\n⚠️  Some tests failed, please check configuration and permissions.');
    }
  }
}

/// Simplified functionality test
class QuickTest {
  final BitchatService _service = BitchatService();
  
  /// Quick functionality test
  Future<void> quickTest() async {
    print('⚡ Quick Functionality Test');
    print('==============');
    
    try {
      // 1. Initialize
      print('1. Initializing service...');
      final initSuccess = await _service.initialize();
      print(initSuccess ? '✅ Initialization successful' : '❌ Initialization failed');
      
      if (initSuccess) {
        // 2. Start
        print('2. Starting service...');
        final startSuccess = await _service.start(
          peerID: 'quick-test-${DateTime.now().millisecondsSinceEpoch}',
          nickname: 'Quick Test',
        );
        print(startSuccess ? '✅ Start successful' : '❌ Start failed');
        
        if (startSuccess) {
          // 3. Send message
          print('3. Sending test message...');
          final messageSuccess = await _service.sendBroadcastMessage('Quick test message');
          print(messageSuccess ? '✅ Message sent successfully' : '❌ Message sending failed');
          
          // 4. Stop
          print('4. Stopping service...');
          await _service.stop();
          print('✅ Stop successful');
        }
      }
      
    } catch (e) {
      print('❌ Test exception: $e');
    }
    
    print('\n🏁 Quick test completed');
  }
} 