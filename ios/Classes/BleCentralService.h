#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

typedef void (^PeerDiscoveredCallback)(NSString *peerId, NSData *_Nullable publicKeyDigest);

@interface BleCentralService : NSObject

@property (nonatomic, copy) PeerDiscoveredCallback onPeerDiscovered;

- (void)startScanningWithCallback:(PeerDiscoveredCallback)callback;
- (void)stopScanning;
- (BOOL)isScanning;

@end 