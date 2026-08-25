import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:md_ui_kit/_core/colors.dart';
import 'package:md_ui_kit/md_ui_kit.dart';
import 'package:md_ui_kit/widgets/wave_flower_loader.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wave_p2p/src/core/keys.dart';
import 'package:wave_p2p/src/core/webrtc_manager.dart';

class CopyCodeScreen extends StatefulWidget {
  const CopyCodeScreen({super.key, required this.onBackPressed});

  final VoidCallback onBackPressed;

  @override
  State<CopyCodeScreen> createState() => _CopyCodeScreenState();
}

class _CopyCodeScreenState extends State<CopyCodeScreen> {
  String? _offerId;
  bool _creating = true;
  bool _isProcessing = false; // блокировка кнопки
  bool _autoAccepted = false; // чтобы не повторять автопринятие

  late final WebRTCManager _manager;

  @override
  void initState() {
    _manager = context.read<WebRTCManager>();
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _manager.addListener(_onManagerChanged);
      _createOffer();
    });
  }

  @override
  void dispose() {
    _manager.removeListener(_onManagerChanged);
    super.dispose();
  }

  void _onManagerChanged() {
    if (!mounted) return;
    // Если ответ уже пришёл и мы ещё не приняли его автоматически
    if (_manager.isAnswerAvailable && !_autoAccepted && !_isProcessing) {
      _autoAcceptAnswer();
    }
  }

  Future<void> _autoAcceptAnswer() async {
    if (_isProcessing || !mounted) return;
    setState(() => _isProcessing = true);
    try {
      final offerId = await _getLocalOfferId();
      await _manager.acceptAnswer(offerId);
      _autoAccepted = true;
      // Переход на главный экран происходит через изменение состояния в ForegroundSwitchScreen
      // но мы можем и сами вызвать колбэк, если нужно
      // Пока просто уведомим
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully connected')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Autoconnection failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _createOffer() async {
    try {
      final id = await _manager.createOfferLink();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(currentPeerLocalIdKey, id);
      if (!mounted) return;
      setState(() {
        _offerId = id;
        _creating = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create code: $e')),
        );
        setState(() => _creating = false);
      }
    }
  }

  Future<String> _getLocalOfferId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(currentPeerLocalIdKey) ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final answerReady = _manager.isAnswerAvailable;

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
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
                        MdColors.buttonAltPressedBg, BlendMode.srcIn),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 280 - 32),
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
        if (_creating)
          CircularProgressIndicator()
        else if (_offerId != null)
          WaveTextButton(
            label: _offerId!,
            onPressed: _onCopyCodePressed,
          )
        else
          const Text('Failed to create pair code'),
        const SizedBox(height: 135),
        WaveSimpleButton(
          label: 'Check Pair',
          onPressed:
              (answerReady && !_isProcessing) ? _onCheckPairPressed : null,
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
        if (_isProcessing)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: CircularProgressIndicator(),
          ),
      ],
    );
  }

  Future<void> _onCopyCodePressed() async {
    if (_offerId == null) return;
    await Clipboard.setData(ClipboardData(text: _offerId!));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Successfully copied!')),
      );
    }
  }

  Future<void> _onCheckPairPressed() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      final offerId = await _getLocalOfferId();
      await _manager.acceptAnswer(offerId);
      // переход на main будет выполнен в ForegroundSwitchScreen через изменение состояния
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed apply peer answer: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
}
