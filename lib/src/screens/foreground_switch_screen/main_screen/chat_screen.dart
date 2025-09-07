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
  final List<ChatMessage> _messages = <ChatMessage>[];
  final ScrollController _scrollController = ScrollController();
  SharedPreferences? _prefs;
  Timer? _saveTimer;
  bool _isAtBottom = true;

  static const double _bottomInset = 140.0;
  static const double _bottomThreshold = 20.0;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final manager = context.read<WebRTCManager>();

      // загружаем историю единожды
      final hist = manager.history;
      if (hist.isNotEmpty) {
        _messages.addAll(hist);
        if (mounted) setState(() {});
      }

      // подписываемся на новые сообщения
      _sub = manager.incomingMessages.listen((msg) {
        if (!mounted) return;
        _messages.add(msg);
        // обновляем список однократно
        setState(() {});
        // автоскроллим только если пользователь уже был внизу
        if (_isAtBottom) {
          // scheduleMicrotask — быстрее и безопаснее, чем addPostFrameCallback здесь
          scheduleMicrotask(() {
            _scrollToBottom(animated: false);
            try {
              manager.markChatRead();
            } catch (_) {}
          });
        }
      });

      // mark read при входе на экран
      manager.markChatRead();

      // prefs + listener + восстановление позиции
      await _initPrefsAndRestore();
    });
  }

  Future<void> _initPrefsAndRestore() async {
    _prefs = await SharedPreferences.getInstance();
    _scrollController.addListener(_onScroll);

    // читаем сохранённое расстояние от низа (distanceFromBottom)
    final savedDistance = _prefs?.getDouble(chatScrollOffsetKey);
    if (savedDistance != null && savedDistance >= 0) {
      await _restoreScrollDistance(savedDistance);
    } else {
      // если нет сохранённой позиции — прокручиваем в низ
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom(animated: false));
    }
  }

  /// Восстанавливам позицию, где сохранена дистанция от низа.
  /// Ждём пока `maxScrollExtent` стабилизируется.
  Future<void> _restoreScrollDistance(double savedDistance) async {
    // ждём пока ListView построится и появится maxScrollExtent
    for (int i = 0; i < 20; i++) {
      await Future.delayed(const Duration(milliseconds: 50));
      if (!mounted) return;
      if (!_scrollController.hasClients) continue;
      try {
        final max = _scrollController.position.maxScrollExtent;
        // target = max - savedDistance
        double target = (max - savedDistance);
        if (target.isNaN) target = 0.0;
        target = target.clamp(0.0, max);
        _scrollController.jumpTo(target);
        _updateIsAtBottom(forceNotify: true);
        return;
      } catch (_) {
        // пробуем ещё раз
      }
    }

    // fallback — прокрутить в низ
    if (mounted) _scrollToBottom(animated: false);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    // обновляем флаг видимости кнопки
    _updateIsAtBottom();

    // debounce сохранения — сохраняем distanceFromBottom
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final pos = _scrollController.position;
        final distanceFromBottom = (pos.maxScrollExtent - pos.pixels).clamp(0.0, double.infinity);
        final prev = _prefs?.getDouble(chatScrollOffsetKey) ?? double.nan;
        if (prev.isNaN || (prev - distanceFromBottom).abs() > 1.0) {
          await _prefs?.setDouble(chatScrollOffsetKey, distanceFromBottom);
        }
      } catch (_) {
        // ignore
      }
    });
  }

  void _updateIsAtBottom({bool forceNotify = false}) {
    if (!_scrollController.hasClients) {
      if (!_isAtBottom) setState(() => _isAtBottom = true);
      return;
    }
    final pos = _scrollController.position;
    final atBottom = (pos.maxScrollExtent - pos.pixels) <= _bottomThreshold;
    if (atBottom != _isAtBottom || forceNotify) {
      setState(() => _isAtBottom = atBottom);
    }
  }

  void _scrollToBottom({bool animated = true}) {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final target = pos.maxScrollExtent;
    final distance = (target - pos.pixels).abs();

    if (!animated || distance < 100) {
      try {
        _scrollController.jumpTo(target);
      } catch (_) {}
      // обновим сохранённую дистанцию (равна 0 когда внизу)
      try {
        _prefs?.setDouble(chatScrollOffsetKey, 0.0);
      } catch (_) {}
      _updateIsAtBottom(forceNotify: true);
      return;
    }

    _scrollController.animateTo(target, duration: const Duration(milliseconds: 200), curve: Curves.easeOut)
        .then((_) {
      try {
        _prefs?.setDouble(chatScrollOffsetKey, 0.0);
      } catch (_) {}
      _updateIsAtBottom(forceNotify: true);
    }).catchError((_) {});
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
    // НЕ вызываем manager.markChatRead() здесь!
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              ListView.builder(
                padding: const EdgeInsets.only(bottom: _bottomInset, top: 12),
                itemCount: _messages.length,
                controller: _scrollController,
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                itemBuilder: (ctx, i) {
                  final m = _messages[i];
                  return MessageItem(
                    key: ValueKey<String>(m.id),
                    message: m,
                  );
                },
              ),
              // кнопка показывается/скрывается немедленно через _updateIsAtBottom
              if (!_isAtBottom)
                Positioned(
                  right: 16,
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

class MessageItem extends StatefulWidget {
  const MessageItem({super.key, required this.message});
  final ChatMessage message;

  @override
  State<MessageItem> createState() => _MessageItemState();
}

class _MessageItemState extends State<MessageItem> with AutomaticKeepAliveClientMixin<MessageItem> {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final m = widget.message;
    final isSystem = m.author == 'System';
    final isMe = m.author == 'You';

    if (isSystem) {
      final txt = m.text;
      if (txt.startsWith('[Event:')) {
        final severity = txt.split(']').first.replaceFirst('[Event:', '').toLowerCase();
        final messageText = txt.replaceFirst(RegExp(r'^\[Event:.*?\]\s*'), '');
        final WaveDividerType divType = severity.contains('positive')
            ? WaveDividerType.positive
            : severity.contains('negative')
                ? WaveDividerType.negative
                : WaveDividerType.disabled;
        return Padding(
          padding: const EdgeInsets.only(left: 16.0, right: 16, bottom: 12),
          child: WaveChatBubble(
            type: WaveChatBubbleType.bubbleMessageEvent,
            label: messageText,
            dividerType: divType,
          ),
        );
      } else {
        final messageText = txt.replaceFirst(RegExp(r'^\[Info\]\s*'), '');
        return Padding(
          padding: const EdgeInsets.only(left: 20.0, right: 20, bottom: 8),
          child: WaveChatBubble(
            type: WaveChatBubbleType.bubbleMessageInfo,
            label: messageText,
            dividerType: WaveDividerType.subtitle,
          ),
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: WaveChatBubble(
        type: isMe ? WaveChatBubbleType.bubbleMessageMe : WaveChatBubbleType.bubbleMessageOther,
        label: m.text,
      ),
    );
  }
}
