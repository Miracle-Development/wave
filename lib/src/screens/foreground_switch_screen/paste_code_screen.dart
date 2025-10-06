import 'package:flutter/material.dart';
import 'package:md_ui_kit/md_ui_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wave_p2p/src/core/keys.dart';

class PasteCodeScreen extends StatefulWidget {
  const PasteCodeScreen({
    super.key,
    required this.onConnectPressed,
  });

  final VoidCallback onConnectPressed;

  @override
  State<PasteCodeScreen> createState() => _PasteCodeScreenState();
}

class _PasteCodeScreenState extends State<PasteCodeScreen> {
  final _codeController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 57.0),
          child: WaveText(
            'Copy your friend’s code and paste it to the text input below:',
            type: WaveTextType.caption,
            maxLines: 3,
            textAlign: TextAlign.center,
          ),
        ),
        SizedBox(height: 27),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40.0),
          child: WaveInput(
            type: WaveInputType.code,
            controller: _codeController,
            // TODO: Set error flag properly
            hasError: false,
          ),
        ),
        SizedBox(height: 135),
        WaveSimpleButton(
          label: 'Connect',
          onPressed: _onAcceptOfferPressed,
        ),
      ],
    );
  }

  Future<void> _onAcceptOfferPressed() async {
    if (_codeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите ID')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(currentPeerLocalIdKey, _codeController.text.trim());

    widget.onConnectPressed();
  }
}
