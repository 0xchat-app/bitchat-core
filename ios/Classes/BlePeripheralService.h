#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

typedef void (^MessageReceivedCallback)(NSString *senderId, NSData *payload);

@interface BlePeripheralService : NSObject

@property (nonatomic, copy) MessageReceivedCallback onMessageReceived;

- (void)startServiceWithPeerID:(NSString *)peerID nickname:(NSString *)nickname;
- (void)stopService;
- (void)sendAnnounceMessage;
- (void)sendKeyExchangeMessage;
- (void)sendMessage:(NSData *)data;

@end 