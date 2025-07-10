#import <Foundation/Foundation.h>
#import <Flutter/Flutter.h>

@interface BlePeripheralPlugin : NSObject <FlutterPlugin>

- (void)startPeripheralServiceWithPeerID:(NSString *)peerID nickname:(NSString *)nickname;
- (void)stopPeripheralService;
- (void)sendAnnounceMessage;
- (void)sendKeyExchangeMessage;
- (void)sendMessage:(NSData *)data;

@end 