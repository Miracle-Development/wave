import 'package:callkeep/callkeep.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:wave/firebase_options.dart';

import 'src/wave_app.dart';
import 'src/settings/settings_controller.dart';
import 'src/settings/settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

// CallKeep setup (minimal). If your callkeep version requires different options,
  // adjust accordingly. Wrap in try/catch so app still runs if CallKeep not available.
  try {
    final ck = FlutterCallkeep();
    // typical options map — adapt to your callkeep package version if signature differs.
    final Map<String, dynamic> options = {
      'ios': {
        'appName': 'Wave',
        'supportsVideo': false,
      },
      'android': {
        'alertTitle': 'Permissions required',
        'alertDescription': 'This app needs to access your phone accounts',
        'cancelButton': 'Cancel',
        'okButton': 'ok',
      },
    };
    // Some packages expose setup(options) or setup(). Use try/catch to allow variety.
    try {
      await ck.setup(options: options);
    } catch (_) {
        print('CallKeep.setup failed or uses different API: $_');
    }
  } catch (e) {
    print('CallKeep initialization skipped: $e');
  }


  // Set up the SettingsController, which will glue user settings to multiple
  // Flutter Widgets.
  final settingsController = SettingsController(SettingsService());

  // Load the user's preferred theme while the splash screen is displayed.
  // This prevents a sudden theme change when the app is first displayed.
  await settingsController.loadSettings();

  // Run the app and pass in the SettingsController. The app listens to the
  // SettingsController for changes, then passes it further down to the
  // SettingsView.
  runApp(WaveApp(settingsController: settingsController));
}
