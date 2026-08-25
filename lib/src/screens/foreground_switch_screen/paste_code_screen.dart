import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:md_ui_kit/_core/colors.dart';
import 'package:md_ui_kit/md_ui_kit.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wave_p2p/src/core/keys.dart';
import 'package:wave_p2p/src/core/webrtc_manager.dart';

class PasteCodeScreen extends StatefulWidget {
  const PasteCodeScreen({super.key, required this.onBackPressed});

  final VoidCallback onBackPressed;

  @override
  State<PasteCodeScreen> createState() => _PasteCodeScreenState();
}

class _PasteCodeScreenState extends State<PasteCodeScreen> {
  final _codeController = TextEditingController();
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      // mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                widget.onBackPressed();
              },
              child: Padding(
                padding: const EdgeInsets.only(
                  left: 32.0,
                  top: 12,
                ),
                child: RotatedBox(
                  quarterTurns: 1,
                  child: SvgPicture.asset(
                    'assets/icons/menu/shevron_down.svg',
                    width: 32,
                    height: 32,
                    colorFilter: ColorFilter.mode(
                      MdColors.buttonAltPressedBg,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        Spacer(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 57.0),
          child: WaveText(
            'Copy your friend’s code and paste it to the text input below:',
            type: WaveTextType.caption,
            maxLines: 3,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 27),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40.0),
          child: TextField(
            controller: _codeController,
            enabled: !_isProcessing,
          ),
        ),
        const SizedBox(height: 135),
        WaveSimpleButton(
          label: 'Connect',
          onPressed: _isProcessing ? null : _onConnectPressed,
        ),
        if (_isProcessing)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: CircularProgressIndicator(),
          ),
        Spacer(),
      ],
    );
  }

  Future<void> _onConnectPressed() async {
    if (_codeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter code')),
      );
      return;
    }
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(currentPeerLocalIdKey, _codeController.text.trim());

      // Принимаем оффер
      final manager = context.read<WebRTCManager>();
      await manager.acceptOffer(_codeController.text.trim());

      // Переход на main будет выполнен автоматически в ForegroundSwitchScreen
      // Но можно вызвать колбэк, если нужно
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
}
