import 'dart:async';
import 'package:flutter/material.dart';
import 'package:md_ui_kit/md_ui_kit.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wave/models/chat_message.dart';
import 'package:wave/src/core/keys.dart';
import 'package:wave/src/core/webrtc_manager.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  StreamSubscription<ChatMessage>? _sub;
  final _messages = <ChatMessage>[];
  final ScrollController _scrollController = ScrollController();
  SharedPreferences? _prefs;
  Timer? _saveTimer;
  bool _isAtBottom = true;

  static const double _bottomInset = 140.0; // совпадает с вашим bottom padding

  @override
  void initState() {
    super.initState();

    // инициализация после первого фрейма
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final manager = context.read<WebRTCManager>();
      // добавляем историю и подписываемся на новые сообщения
      setState(() {
        _messages.addAll(manager.history);
      });

      // подписка на входящие
      _sub = manager.incomingMessages.listen((msg) {
        if (!mounted) return;
        setState(() => _messages.add(msg));
        // прокрутка после следующего layout pass
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      });

      manager.markChatRead();

      // подготовим prefs, listener и восстановим позицию
      await _initPrefsAndRestore();
    });
  }

  Future<void> _initPrefsAndRestore() async {
    _prefs = await SharedPreferences.getInstance();

    // добавляем слушатель скролла (после создания prefs)
    _scrollController.addListener(_onScroll);

    // восстанавливаем позицию (если есть)
    final saved = _prefs?.getDouble(chatScrollOffsetKey);
    if (saved != null && saved >= 0) {
      // ждем следующий фрейм, чтобы ListView уже имел размеры
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        final max = _scrollController.position.maxScrollExtent;
        final target = saved.clamp(0.0, max);
        _scrollController.jumpTo(target);
        _updateIsAtBottom();
      });
    } else {
      // если нет сохранённой позиции, прокрутим в низ (если есть сообщения)
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    // обновляем флаг видимости кнопки
    _updateIsAtBottom();

    // debounce сохранения: ждем 500ms после последнего скролла
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), () {
      try {
        final pixels = _scrollController.position.pixels;
        _prefs?.setDouble(chatScrollOffsetKey, pixels);
      } catch (_) {}
    });
  }

  void _updateIsAtBottom() {
    if (!_scrollController.hasClients) {
      if (!_isAtBottom) setState(() => _isAtBottom = true);
      return;
    }
    final pos = _scrollController.position;
    // считаем что внизу если расстояние до max <= 20 px
    final atBottom = (pos.maxScrollExtent - pos.pixels) <= 20.0;
    if (atBottom != _isAtBottom) {
      setState(() => _isAtBottom = atBottom);
    }
  }

  void _scrollToBottom({bool animated = true}) {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final target = pos.maxScrollExtent;
    if (animated) {
      _scrollController
          .animateTo(
        target,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      )
          .then((_) {
        // сразу сохраняем после анимации
        try {
          _prefs?.setDouble(chatScrollOffsetKey, target);
        } catch (_) {}
        _updateIsAtBottom();
      });
    } else {
      _scrollController.jumpTo(target);
      try {
        _prefs?.setDouble(chatScrollOffsetKey, target);
      } catch (_) {}
      _updateIsAtBottom();
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _sub?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<WebRTCManager>();
    WidgetsBinding.instance.addPostFrameCallback((_) => manager.markChatRead());

    return Column(
      children: [
        Expanded(
          // Wrap ListView in Expanded
          child: Stack(
            children: [
              ListView.builder(
                padding: const EdgeInsets.only(
                  bottom: _bottomInset,
                  top: 12,
                ),
                itemCount: _messages.length,
                controller: _scrollController,
                itemBuilder: (_, i) {
                  final m = _messages[i];
                  final isMe = m.author == 'You';
                  // Рендер системных сообщений: автор == 'System'
                  if (m.author == 'System') {
                    // формат текста: [Event:positive] или [Info] ...
                    final txt = m.text;

                    if (txt.startsWith('[Event:')) {
                      final severity =
                          txt.split(']').first.replaceFirst('[Event:', '');
                      final messageText =
                          txt.replaceFirst(RegExp(r'^\[Event:.*?\]\s*'), '');
                      if (severity.contains('positive')) {
                        return WaveChatBubble(
                          label: messageText,
                          type: WaveChatBubbleType.bubbleMessageEvent,
                          dividerType: WaveDividerType.positive,
                        );
                      } else if (severity.contains('negative')) {
                        return WaveChatBubble(
                          label: messageText,
                          type: WaveChatBubbleType.bubbleMessageEvent,
                          dividerType: WaveDividerType.negative,
                        );
                      } else {
                        return WaveChatBubble(
                          label: messageText,
                          type: WaveChatBubbleType.bubbleMessageEvent,
                          dividerType: WaveDividerType.disabled,
                        );
                      }
                    } else {
                      // Info
                      final messageText =
                          txt.replaceFirst(RegExp(r'^\[Info\]\s*'), '');
                      return Padding(
                        padding: const EdgeInsets.only(
                          left: 20.0,
                          right: 20,
                          bottom: 8,
                        ),
                        child: WaveChatBubble(
                          label: messageText,
                          type: WaveChatBubbleType.bubbleMessageInfo,
                          dividerType: WaveDividerType.subtitle,
                        ),
                      );
                    }
                  }

                  // Обычное сообщение - используем ваш WaveChatBubble
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: WaveChatBubble(
                      type: isMe
                          ? WaveChatBubbleType.bubbleMessageMe
                          : WaveChatBubbleType.bubbleMessageOther,
                      label: m.text,
                    ),
                  );
                },
              ),
              if (!_isAtBottom)
                Positioned(
                  right: 16,
                  // размещаем над полем ввода (оставляем небольшой запас)
                  bottom: _bottomInset + 40,
                  child: FloatingActionButton.small(
                    heroTag: 'scroll_down_btn',
                    onPressed: () => _scrollToBottom(animated: true),
                    child: const Icon(Icons.arrow_downward),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
