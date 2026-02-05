//
//  Generated file. Do not edit.
//

// clang-format off

#import "GeneratedPluginRegistrant.h"

#if __has_include(<flutter_carplay/FlutterCarplayPlugin.h>)
#import <flutter_carplay/FlutterCarplayPlugin.h>
#else
@import flutter_carplay;
#endif

#if __has_include(<flutter_tts/FlutterTtsPlugin.h>)
#import <flutter_tts/FlutterTtsPlugin.h>
#else
@import flutter_tts;
#endif

#if __has_include(<speech_to_text/SpeechToTextPlugin.h>)
#import <speech_to_text/SpeechToTextPlugin.h>
#else
@import speech_to_text;
#endif

@implementation GeneratedPluginRegistrant

+ (void)registerWithRegistry:(NSObject<FlutterPluginRegistry>*)registry {
  [FlutterCarplayPlugin registerWithRegistrar:[registry registrarForPlugin:@"FlutterCarplayPlugin"]];
  [FlutterTtsPlugin registerWithRegistrar:[registry registrarForPlugin:@"FlutterTtsPlugin"]];
  [SpeechToTextPlugin registerWithRegistrar:[registry registrarForPlugin:@"SpeechToTextPlugin"]];
}

@end
