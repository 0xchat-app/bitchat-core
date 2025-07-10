#import "BlePeripheralPlugin.h"
#import "BlePeripheralService.h"

@interface BlePeripheralPlugin ()
@property (nonatomic, strong) BlePeripheralService *bleService;
@property (nonatomic, strong) FlutterMethodChannel *methodChannel;
@end

@implementation BlePeripheralPlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FlutterMethodChannel* channel = [FlutterMethodChannel
                                   methodChannelWithName:@"com.bitchat.core/ble_peripheral"
                                   binaryMessenger:[registrar messenger]];
    BlePeripheralPlugin* instance = [[BlePeripheralPlugin alloc] init];
    instance.methodChannel = channel;
    [registrar addMethodCallDelegate:instance channel:channel];
    
    NSLog(@"[BLE] BlePeripheralPlugin registered with channel: com.bitchat.core/ble_peripheral");
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSLog(@"[BLE] Received method call: %@", call.method);
    
    if ([@"startPeripheralService" isEqualToString:call.method]) {
        NSDictionary *args = call.arguments;
        NSString *peerID = args[@"peerID"];
        NSString *nickname = args[@"nickname"];
        
        if (!peerID || !nickname) {
            result([FlutterError errorWithCode:@"INVALID_ARGUMENTS"
                                     message:@"peerID and nickname are required"
                                     details:nil]);
            return;
        }
        
        [self startPeripheralServiceWithPeerID:peerID nickname:nickname];
        result(@YES);
        
    } else if ([@"stopPeripheralService" isEqualToString:call.method]) {
        [self stopPeripheralService];
        result(@YES);
        
    } else if ([@"sendAnnounceMessage" isEqualToString:call.method]) {
        [self sendAnnounceMessage];
        result(@YES);
        
    } else if ([@"sendKeyExchangeMessage" isEqualToString:call.method]) {
        [self sendKeyExchangeMessage];
        result(@YES);
        
    } else if ([@"sendMessage" isEqualToString:call.method]) {
        NSDictionary *args = call.arguments;
        FlutterStandardTypedData *data = args[@"data"];
        
        if (!data) {
            result([FlutterError errorWithCode:@"INVALID_ARGUMENTS"
                                     message:@"data is required"
                                     details:nil]);
            return;
        }
        
        [self sendMessage:data.data];
        result(@YES);
        
    } else {
        NSLog(@"[BLE] Unknown method: %@", call.method);
        result(FlutterMethodNotImplemented);
    }
}

- (void)startPeripheralServiceWithPeerID:(NSString *)peerID nickname:(NSString *)nickname {
    NSLog(@"[BLE] Starting peripheral service with peerID: %@, nickname: %@", peerID, nickname);
    
    if (!self.bleService) {
        self.bleService = [[BlePeripheralService alloc] init];
        
        // Set up message received callback
        __weak typeof(self) weakSelf = self;
        self.bleService.onMessageReceived = ^(NSString *senderId, NSData *payload) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf.methodChannel invokeMethod:@"onMessageReceived" arguments:@{
                    @"senderId": senderId,
                    @"payload": [FlutterStandardTypedData typedDataWithBytes:payload]
                }];
            });
        };
    }
    
    [self.bleService startServiceWithPeerID:peerID nickname:nickname];
}

- (void)stopPeripheralService {
    NSLog(@"[BLE] Stopping peripheral service");
    [self.bleService stopService];
}

- (void)sendAnnounceMessage {
    NSLog(@"[BLE] Sending announce message");
    [self.bleService sendAnnounceMessage];
}

- (void)sendKeyExchangeMessage {
    NSLog(@"[BLE] Sending key exchange message");
    [self.bleService sendKeyExchangeMessage];
}

- (void)sendMessage:(NSData *)data {
    NSLog(@"[BLE] Sending message: %lu bytes", (unsigned long)data.length);
    [self.bleService sendMessage:data];
}

@end 