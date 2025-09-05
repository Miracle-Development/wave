import '../../models/chat_message.dart';

class LocalStorage {
  final List<ChatMessage> _messages = [];

  Future<void> appendMessage(ChatMessage m) async {
    _messages.add(m);
  }

  Future<List<ChatMessage>> loadMessages() async {
    return List.of(_messages);
  }

  Future<List<ChatMessage>> clearMessages() async {
    List<ChatMessage> _messages = [];
    return _messages;
  }
}
