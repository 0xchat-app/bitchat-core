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
    
    if (self.centralManager.state == CBManagerStatePoweredOn) {
        [self _startScanning];
    }
}

- (void)_startScanning {
    if (self.isScanning) {
        return;
    }
    
    // Scan for devices with the specific service UUID used by our peripheral service
    CBUUID *serviceUUID = [CBUUID UUIDWithString:@"F47B5E2D-4A9E-4C5A-9B3F-8E1D2C3A4B5C"];
    
    NSDictionary *scanOptions = @{
        CBCentralManagerScanOptionAllowDuplicatesKey: @YES
    };
    
    [self.centralManager scanForPeripheralsWithServices:@[serviceUUID] options:scanOptions];
    self.isScanning = YES;
}

- (void)stopScanning {
    [self.centralManager stopScan];
    self.isScanning = NO;
}

#pragma mark - CBCentralManagerDelegate

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    switch (central.state) {
        case CBManagerStatePoweredOn:
            if (self.onPeerDiscovered) {
                [self _startScanning];
            }
            break;
        default:
            break;
    }
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *,id> *)advertisementData RSSI:(NSNumber *)RSSI {
    
    NSString *localName = advertisementData[CBAdvertisementDataLocalNameKey];
    NSString *peripheralName = peripheral.name;
    NSString *peerId = localName ?: peripheralName;
    
    // Extract manufacturer data if available
    NSData *manufacturerData = nil;
    NSDictionary *manufacturerDataDict = advertisementData[CBAdvertisementDataManufacturerDataKey];
    if (manufacturerDataDict && [manufacturerDataDict isKindOfClass:[NSData class]]) {
        manufacturerData = (NSData *)manufacturerDataDict;
    }
    
    // Filter based on peerId requirements (should be 8 characters)
    if (peerId && peerId.length == 8) {
        // Store discovered peripheral
        self.discoveredPeripherals[peripheral.identifier.UUIDString] = peripheral;
        
        // Call the discovery callback
        if (self.onPeerDiscovered) {
            self.onPeerDiscovered(peerId, manufacturerData);
        }
    }
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    peripheral.delegate = self;
    [peripheral discoverServices:nil];
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    // Connection failed silently
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    // Disconnection handled silently
}

#pragma mark - CBPeripheralDelegate

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    if (error) {
        return;
    }
    
    for (CBService *service in peripheral.services) {
        [peripheral discoverCharacteristics:nil forService:service];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    if (error) {
        return;
    }
    
    // Handle characteristics silently
}

@end 
