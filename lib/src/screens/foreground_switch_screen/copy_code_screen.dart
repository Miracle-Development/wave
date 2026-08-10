import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:md_ui_kit/_core/colors.dart';
import 'package:md_ui_kit/md_ui_kit.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wave_p2p/src/core/keys.dart';
import 'package:wave_p2p/src/core/webrtc_manager.dart';

class CopyCodeScreen extends StatefulWidget {
  const CopyCodeScreen({super.key});

  @override
  State<CopyCodeScreen> createState() => _CopyCodeScreenState();
}

class _CopyCodeScreenState extends State<CopyCodeScreen> {
  String? _offerId;
  bool _creating = true;
  bool _isProcessing = false; // блокировка кнопки
  bool _autoAccepted = false; // чтобы не повторять автопринятие

  @override
  void initState() {
    super.initState();
    _createOffer();
    // Подписываемся на изменения документа, чтобы автоматически принять ответ
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final manager = context.read<WebRTCManager>();
      manager.addListener(_onManagerChanged);
    });
  }

  @override
  void dispose() {
    final manager = context.read<WebRTCManager>();
    manager.removeListener(_onManagerChanged);
    super.dispose();
  }

  void _onManagerChanged() {
    final manager = context.read<WebRTCManager>();
    // Если ответ уже пришёл и мы ещё не приняли его автоматически
    if (manager.isAnswerAvailable && !_autoAccepted && !_isProcessing) {
      _autoAcceptAnswer();
    }
  }

  Future<void> _autoAcceptAnswer() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      final manager = context.read<WebRTCManager>();
      final offerId = await _getLocalOfferId();
      await manager.acceptAnswer(offerId);
      _autoAccepted = true;
      // Переход на главный экран происходит через изменение состояния в ForegroundSwitchScreen
      // но мы можем и сами вызвать колбэк, если нужно
      // Пока просто уведомим
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Соединение установлено автоматически!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка автоподключения: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _createOffer() async {
    try {
      final manager = context.read<WebRTCManager>();
      final id = await manager.createOfferLink();
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
          SnackBar(content: Text('Ошибка создания кода: $e')),
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
    final manager = context.watch<WebRTCManager>();
    final answerReady = manager.isAnswerAvailable;

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        const SizedBox(height: 280),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 57.0),
          child: WaveText(
            'Это ваш двухсловный код. Скопируйте и отправьте другу',
            type: WaveTextType.caption,
            maxLines: 3,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 27),
        if (_creating)
          const CircularProgressIndicator()
        else if (_offerId != null)
          WaveTextButton(
            label: _offerId!,
            onPressed: _onCopyCodePressed,
          )
        else
          const Text('Не удалось создать код'),
        const SizedBox(height: 135),
        WaveSimpleButton(
          label: 'Проверить пару',
          onPressed: (answerReady && !_isProcessing) ? _onCheckPairPressed : null,
        ),
        const SizedBox(height: 20),
        if (!answerReady)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 57.0),
            child: WaveText(
              'Дождитесь, пока друг вставит код для активации кнопки',
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
        const SnackBar(content: Text('Код скопирован')),
      );
    }
  }

  Future<void> _onCheckPairPressed() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      final manager = context.read<WebRTCManager>();
      final offerId = await _getLocalOfferId();
      await manager.acceptAnswer(offerId);
      // переход на main будет выполнен в ForegroundSwitchScreen через изменение состояния
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка применения ответа: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
}