#import "BleCentralService.h"

@interface BleCentralService () <CBCentralManagerDelegate, CBPeripheralDelegate>
@property (nonatomic, strong) CBCentralManager *centralManager;
@property (nonatomic, strong) NSMutableDictionary *discoveredPeripherals;
@property (nonatomic, assign) BOOL isScanning;
@end

@implementation BleCentralService

- (instancetype)init {
    self = [super init];
    if (self) {
        self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
        self.discoveredPeripherals = [NSMutableDictionary dictionary];
        self.isScanning = NO;
    }
    return self;
}

- (void)startScanningWithCallback:(PeerDiscoveredCallback)callback {
    self.onPeerDiscovered = callback;
    
    NSLog(@"[BLE Central] Starting to scan for peripherals");
    
    if (self.centralManager.state == CBManagerStatePoweredOn) {
        [self _startScanning];
    } else {
        NSLog(@"[BLE Central] Central manager not powered on, current state: %ld", (long)self.centralManager.state);
    }
}

- (void)_startScanning {
    if (self.isScanning) {
        NSLog(@"[BLE Central] Already scanning");
        return;
    }
    
    // Scan for devices with the specific service UUID used by our peripheral service
    CBUUID *serviceUUID = [CBUUID UUIDWithString:@"F47B5E2D-4A9E-4C5A-9B3F-8E1D2C3A4B5C"];
    
    NSDictionary *scanOptions = @{
        CBCentralManagerScanOptionAllowDuplicatesKey: @YES
    };
    
    [self.centralManager scanForPeripheralsWithServices:@[serviceUUID] options:scanOptions];
    self.isScanning = YES;
    
    NSLog(@"[BLE Central] Started scanning for peripherals with service UUID: %@", serviceUUID.UUIDString);
}

- (void)stopScanning {
    NSLog(@"[BLE Central] Stopping scan");
    [self.centralManager stopScan];
    self.isScanning = NO;
}

#pragma mark - CBCentralManagerDelegate

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    NSLog(@"[BLE Central] Central manager state updated: %ld", (long)central.state);
    
    switch (central.state) {
        case CBManagerStatePoweredOn:
            NSLog(@"[BLE Central] Bluetooth is powered on and ready");
            if (self.onPeerDiscovered) {
                [self _startScanning];
            }
            break;
        case CBManagerStatePoweredOff:
            NSLog(@"[BLE Central] Bluetooth is powered off");
            break;
        case CBManagerStateUnsupported:
            NSLog(@"[BLE Central] Bluetooth is not supported on this device");
            break;
        case CBManagerStateUnauthorized:
            NSLog(@"[BLE Central] Bluetooth access is not authorized");
            break;
        case CBManagerStateResetting:
            NSLog(@"[BLE Central] Bluetooth is resetting");
            break;
        case CBManagerStateUnknown:
            NSLog(@"[BLE Central] Bluetooth state is unknown");
            break;
    }
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *,id> *)advertisementData RSSI:(NSNumber *)RSSI {
    
    NSString *localName = advertisementData[CBAdvertisementDataLocalNameKey];
    NSString *peripheralName = peripheral.name;
    NSString *peerId = localName ?: peripheralName;
    
    NSLog(@"[BLE Central] Discovered peripheral: %@", peripheral.identifier.UUIDString);
    NSLog(@"[BLE Central] Peripheral name: %@", peripheralName);
    NSLog(@"[BLE Central] Local name: %@", localName);
    NSLog(@"[BLE Central] RSSI: %@", RSSI);
    NSLog(@"[BLE Central] Advertisement data: %@", advertisementData);
    
    // Extract manufacturer data if available
    NSData *manufacturerData = nil;
    NSDictionary *manufacturerDataDict = advertisementData[CBAdvertisementDataManufacturerDataKey];
    if (manufacturerDataDict && [manufacturerDataDict isKindOfClass:[NSData class]]) {
        manufacturerData = (NSData *)manufacturerDataDict;
        NSLog(@"[BLE Central] Found manufacturer data: %ld bytes", (long)manufacturerData.length);
    }
    
    // Filter based on peerId requirements (should be 8 characters)
    if (peerId && peerId.length == 8) {
        NSLog(@"[BLE Central] Valid peerId found: %@", peerId);
        
        // Store discovered peripheral
        self.discoveredPeripherals[peripheral.identifier.UUIDString] = peripheral;
        
        // Call the discovery callback
        if (self.onPeerDiscovered) {
            self.onPeerDiscovered(peerId, manufacturerData);
        }
        
        // Optionally connect to the peripheral for more detailed communication
        // [self.centralManager connectPeripheral:peripheral options:nil];
        
    } else {
        NSLog(@"[BLE Central] Skipping peripheral with invalid peerId: %@ (length: %ld)", peerId, (long)peerId.length);
    }
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    NSLog(@"[BLE Central] Connected to peripheral: %@", peripheral.identifier.UUIDString);
    peripheral.delegate = self;
    [peripheral discoverServices:nil];
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSLog(@"[BLE Central] Failed to connect to peripheral: %@, error: %@", peripheral.identifier.UUIDString, error);
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSLog(@"[BLE Central] Disconnected from peripheral: %@, error: %@", peripheral.identifier.UUIDString, error);
}

#pragma mark - CBPeripheralDelegate

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    if (error) {
        NSLog(@"[BLE Central] Error discovering services: %@", error);
        return;
    }
    
    NSLog(@"[BLE Central] Discovered services for peripheral: %@", peripheral.identifier.UUIDString);
    for (CBService *service in peripheral.services) {
        NSLog(@"[BLE Central] Service: %@", service.UUID);
        [peripheral discoverCharacteristics:nil forService:service];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    if (error) {
        NSLog(@"[BLE Central] Error discovering characteristics: %@", error);
        return;
    }
    
    NSLog(@"[BLE Central] Discovered characteristics for service: %@", service.UUID);
    for (CBCharacteristic *characteristic in service.characteristics) {
        NSLog(@"[BLE Central] Characteristic: %@, properties: %lu", characteristic.UUID, (unsigned long)characteristic.properties);
    }
}

@end 
