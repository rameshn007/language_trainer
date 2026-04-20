#!/bin/zsh
flutter clean; rm -rf ios/Pods ios/Podfile.lock; flutter pub get; cd ios && pod install && cd .. ; flutter analyze
