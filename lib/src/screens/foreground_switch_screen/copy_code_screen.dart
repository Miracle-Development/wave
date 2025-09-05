import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:md_ui_kit/_core/colors.dart';
import 'package:provider/provider.dart';
import 'package:md_ui_kit/md_ui_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wave/src/core/keys.dart';
import 'package:wave/src/core/webrtc_manager.dart';

class CopyCodeScreen extends StatefulWidget {
  const CopyCodeScreen({super.key, required this.onCheckPairPressed});

  final VoidCallback onCheckPairPressed;

  @override
  State<CopyCodeScreen> createState() => _CopyCodeScreenState();
}

class _CopyCodeScreenState extends State<CopyCodeScreen> {
  String? _offerId;
  bool _creating = true;

  @override
  void initState() {
    super.initState();
    _createOffer();
  }

  @override
  Widget build(BuildContext context) {
    // следим за наличием ответа в менеджере — при изменении UI перестроится автоматически
    final manager = context.watch<WebRTCManager>();
    final answerReady = manager.isAnswerAvailable;

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        SizedBox(height: 280),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 57.0),
          child: WaveText(
            'This is your two-word pair code. Copy and send it to your friend',
            type: WaveTextType.caption,
            maxLines: 3,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 27),
        if (_creating) ...[
          // TODO change
          const CircularProgressIndicator(),
        ] else if (_offerId != null) ...[
          WaveTextButton(
            label: _offerId!,
            onPressed: _onCopyCodePressed,
          ),
        ] else ...[
          // TODO change
          const Text('Failed to create code'),
        ],
        const SizedBox(height: 135),
        // Check pair: enabled когда пришёл answer
        WaveSimpleButton(
          label: 'Check pair',
          onPressed: answerReady ? _onButtonPressed : null,
        ),
        const SizedBox(height: 20),
        if (!answerReady)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 57.0),
            child: WaveText(
              'Wait your friend to paste the code for button enabling',
              type: WaveTextType.caption,
              maxLines: 3,
              textAlign: TextAlign.center,
              color: MdColors.disabledColor,
            ),
          ),
      ],
    );
  }

  Future<void> _createOffer() async {
    try {
      final manager = context.read<WebRTCManager>();
      final id = await manager.createOfferLink();

// сохраняем в памяти localId two-word code
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(currentPeerLocalIdKey, id);

      if (!mounted) return;
      setState(() {
        _offerId = id;
        _creating = false;
      });
    } catch (e, st) {
      // обработка ошибок - покажем SnackBar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при создании кода: $e')),
        );
        setState(() {
          _creating = false;
        });
      }
    }
  }

  Future<void> _onCopyCodePressed() async {
    if (_offerId == null) return;
    await Clipboard.setData(ClipboardData(text: _offerId!));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Код скопирован')),
    );
  }

  void _onButtonPressed() {
    widget.onCheckPairPressed();
  }
}
