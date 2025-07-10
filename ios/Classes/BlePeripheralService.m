#import "BlePeripheralService.h"

@interface BlePeripheralService () <CBPeripheralManagerDelegate>
@property (nonatomic, strong) CBPeripheralManager *peripheralManager;
@property (nonatomic, strong) CBMutableCharacteristic *messageCharacteristic;
@property (nonatomic, strong) CBMutableService *messageService;
@property (nonatomic, strong) NSString *peerID;
@property (nonatomic, strong) NSString *nickname;
@property (nonatomic, strong) NSMutableSet *connectedCentrals;
@property (nonatomic, strong) NSTimer *announceTimer;
@end

@implementation BlePeripheralService

- (instancetype)init {
    self = [super init];
    if (self) {
        self.peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:nil];
        self.connectedCentrals = [NSMutableSet set];
    }
    return self;
}

- (void)startServiceWithPeerID:(NSString *)peerID nickname:(NSString *)nickname {
    self.peerID = peerID;
    self.nickname = nickname;
    
    NSLog(@"[BLE] Starting peripheral service with peerID: %@, nickname: %@", peerID, nickname);
    
    if (self.peripheralManager.state == CBPeripheralManagerStatePoweredOn) {
        [self setupService];
    }
}

- (void)stopService {
    NSLog(@"[BLE] Stopping peripheral service");
    [self.announceTimer invalidate];
    self.announceTimer = nil;
    [self.peripheralManager stopAdvertising];
    [self.peripheralManager removeAllServices];
}

- (void)setupService {
    // Create service UUID matching bitchat implementation
    CBUUID *serviceUUID = [CBUUID UUIDWithString:@"F47B5E2D-4A9E-4C5A-9B3F-8E1D2C3A4B5C"];
    
    // Create characteristic for message exchange - use same UUID as bitchat
    CBUUID *characteristicUUID = [CBUUID UUIDWithString:@"A1B2C3D4-E5F6-4A5B-8C9D-0E1F2A3B4C5D"];
    
    self.messageCharacteristic = [[CBMutableCharacteristic alloc] 
                                 initWithType:characteristicUUID
                                 properties:CBCharacteristicPropertyRead | CBCharacteristicPropertyWrite | CBCharacteristicPropertyNotify
                                 value:nil
                                 permissions:CBAttributePermissionsReadable | CBAttributePermissionsWriteable];
    
    self.messageService = [[CBMutableService alloc] initWithType:serviceUUID primary:YES];
    self.messageService.characteristics = @[self.messageCharacteristic];
    
    [self.peripheralManager addService:self.messageService];
}

- (void)sendAnnounceMessage {
    NSLog(@"[BLE] Sending announce message");
    // Create announce message packet
    NSData *announceData = [self createAnnouncePacket];
    
    NSLog(@"[BLE] Announce packet created: %lu bytes", (unsigned long)announceData.length);
    
    // Send to all connected centrals via characteristic
    if (self.connectedCentrals.count > 0) {
        [self sendMessage:announceData];
        NSLog(@"[BLE] Sent announce message to %lu centrals", (unsigned long)self.connectedCentrals.count);
    } else {
        NSLog(@"[BLE] No connected centrals to send announce message to");
    }
}

- (void)sendKeyExchangeMessage {
    NSLog(@"[BLE] Sending key exchange message");
    // Create key exchange message packet
    NSData *keyExchangeData = [self createKeyExchangePacket];
    [self sendMessage:keyExchangeData];
}

- (void)sendMessage:(NSData *)data {
    NSLog(@"[BLE] Sending message: %lu bytes", (unsigned long)data.length);
    
    // Send to all connected centrals
    for (CBCentral *central in self.connectedCentrals) {
        BOOL success = [self.peripheralManager updateValue:data
                         forCharacteristic:self.messageCharacteristic
                      onSubscribedCentrals:@[central]];
        NSLog(@"[BLE] Sent message to central %@: %@", central.identifier.UUIDString, success ? @"SUCCESS" : @"FAILED");
    }
}

- (NSData *)createAnnouncePacket {
    // Create announce packet: type=1, senderID, nickname
    NSMutableData *packet = [NSMutableData data];
    
    // Message type (1 byte) - announce = 1
    uint8_t messageType = 1;
    [packet appendBytes:&messageType length:1];
    
    // Sender ID (8 bytes) - convert hex string to bytes
    NSData *senderIdData = [self hexStringToData:self.peerID];
    [packet appendData:senderIdData];
    
    // Nickname (variable length)
    NSData *nicknameData = [self.nickname dataUsingEncoding:NSUTF8StringEncoding];
    uint8_t nicknameLength = (uint8_t)nicknameData.length;
    [packet appendBytes:&nicknameLength length:1];
    [packet appendData:nicknameData];
    
    NSLog(@"[BLE] Created announce packet: %lu bytes", (unsigned long)packet.length);
    return packet;
}

- (NSData *)createKeyExchangePacket {
    // Create key exchange packet: type=2, senderID, public key
    NSMutableData *packet = [NSMutableData data];
    
    // Message type (1 byte) - key exchange = 2
    uint8_t messageType = 2;
    [packet appendBytes:&messageType length:1];
    
    // Sender ID (8 bytes)
    NSData *senderIdData = [self hexStringToData:self.peerID];
    [packet appendData:senderIdData];
    
    // Public key (32 bytes) - dummy data for now
    uint8_t publicKey[32] = {0};
    [packet appendBytes:publicKey length:32];
    
    NSLog(@"[BLE] Created key exchange packet: %lu bytes", (unsigned long)packet.length);
    return packet;
}

- (NSData *)hexStringToData:(NSString *)hexString {
    NSMutableData *data = [NSMutableData data];
    for (int i = 0; i < hexString.length; i += 2) {
        NSString *hexByte = [hexString substringWithRange:NSMakeRange(i, 2)];
        unsigned int value;
        [[NSScanner scannerWithString:hexByte] scanHexInt:&value];
        uint8_t byte = (uint8_t)value;
        [data appendBytes:&byte length:1];
    }
    return data;
}

- (void)startAnnounceTimer {
    // Stop existing timer
    [self.announceTimer invalidate];
    
    // Start periodic announce timer
    self.announceTimer = [NSTimer scheduledTimerWithTimeInterval:5.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
        [self sendAnnounceMessage];
    }];
    
    // Send initial announce immediately
    [self sendAnnounceMessage];
}

#pragma mark - CBPeripheralManagerDelegate

- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral {
    NSLog(@"[BLE] Peripheral manager state: %ld", (long)peripheral.state);
    
    if (peripheral.state == CBPeripheralManagerStatePoweredOn) {
        [self setupService];
        
        // Start advertising
        NSDictionary *advertisingData = @{
            CBAdvertisementDataServiceUUIDsKey: @[self.messageService.UUID],
            CBAdvertisementDataLocalNameKey: self.peerID
        };
        
        [self.peripheralManager startAdvertising:advertisingData];
        NSLog(@"[BLE] Started advertising with peerID: %@", self.peerID);
    }
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didAddService:(CBService *)service error:(NSError *)error {
    if (error) {
        NSLog(@"[BLE] Failed to add service: %@", error);
    } else {
        NSLog(@"[BLE] Service added successfully");
    }
}

- (void)peripheralManagerDidStartAdvertising:(CBPeripheralManager *)peripheral error:(NSError *)error {
    if (error) {
        NSLog(@"[BLE] Failed to start advertising: %@", error);
    } else {
        NSLog(@"[BLE] Started advertising successfully");
        // Start announce timer when advertising starts
        [self startAnnounceTimer];
    }
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didSubscribeToCharacteristic:(CBCharacteristic *)characteristic {
    NSLog(@"[BLE] Central subscribed: %@", central.identifier.UUIDString);
    [self.connectedCentrals addObject:central];
    
    NSLog(@"[BLE] Connected centrals count: %lu", (unsigned long)self.connectedCentrals.count);
    
    // Send key exchange immediately when central subscribes
    [self sendKeyExchangeMessage];
    
    // Send announce message after a short delay
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"[BLE] Sending announce message to newly connected central");
        [self sendAnnounceMessage];
    });
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didUnsubscribeFromCharacteristic:(CBCharacteristic *)characteristic {
    NSLog(@"[BLE] Central unsubscribed: %@", central.identifier.UUIDString);
    [self.connectedCentrals removeObject:central];
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveWriteRequests:(NSArray<CBATTRequest *> *)requests {
    for (CBATTRequest *request in requests) {
        NSLog(@"[BLE] Received write request: %lu bytes", (unsigned long)request.value.length);
        
        // Process received message
        if (self.onMessageReceived) {
            NSString *senderId = request.central.identifier.UUIDString;
            self.onMessageReceived(senderId, request.value);
        }
        
        [peripheral respondToRequest:request withResult:CBATTErrorSuccess];
    }
}

@end 