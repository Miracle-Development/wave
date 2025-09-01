# wave

Wave - Peer-to-peer calls and chat application

## Getting Started

This project is a starting point for a Flutter application that follows the
[simple app state management
tutorial](https://flutter.dev/to/state-management-sample).

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Assets

The `assets` directory houses images, fonts, and any other files you want to
include with your application.

The `assets/images` directory contains [resolution-aware
images](https://flutter.dev/to/resolution-aware-images).

## Store providing (Redux)

First variation: ` final store = StoreProvider.of<AppState>(context); `
Second variation: ` StoreConnector<AppState, Store<AppState>>(builder: () {}, converter: () {}), `

## Localization

Tthis project generates localized messages based on arb files found in
the `lib/src/localization` directory

To re-generate intl files, use `flutter gen-l10n --arb-dir=lib/src/localization --template-arb-file=app_en.arb --output-dir=lib/src/localization/generated` command 

To support additional languages, please visit the tutorial on
[Internationalizing Flutter apps](https://flutter.dev/to/internationalization).

## build_runner

Run `flutter pub run build_runner build --delete-conflicting-outputs`

## XCode build

#### Step-by-step code (run one after one from `lib` folder):
* `fvm flutter clean                                       
rm -rf ios/Pods
rm -rf ios/.symlinks
rm -rf ios/Flutter/Flutter.framework
rm -rf ios/Flutter/Flutter.podspec
rm -rf ios/Flutter/App.framework
rm -rf ios/Flutter/Generated.xcconfig
rm -rf ios/Flutter/app.flx
rm -rf ios/Flutter/app.zip
rm -rf ios/Flutter/flutter_assets
rm -rf ios/Flutter/flutter_export_environment.sh`
* `rm -rf Podfile.lock Pods`
* `fvm flutter pub get`
* `cd ios`
* `pod install --repo-update`

#### Global code (run from `lib` folder):
`
fvm flutter clean                                       
rm -rf ios/Pods
rm -rf ios/.symlinks
rm -rf ios/Flutter/Flutter.framework
rm -rf ios/Flutter/Flutter.podspec
rm -rf ios/Flutter/App.framework
rm -rf ios/Flutter/Generated.xcconfig
rm -rf ios/Flutter/app.flx
rm -rf ios/Flutter/app.zip
rm -rf ios/Flutter/flutter_assets
rm -rf ios/Flutter/flutter_export_environment.sh
rm -rf Podfile.lock Pods
fvm flutter pub get
cd ios
pod install --repo-update
cd ../
`

#### To update package:
* `pod update <Firebase/Messaging>`

#### To update gems/pods:
* `gem install cocoapods`