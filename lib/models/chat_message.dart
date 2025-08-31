class ChatMessage {
  final String id;
  final String author; // 'Вы' | 'Собеседник' | 'Система'
  final String text;
  final DateTime ts;

  ChatMessage({
    required this.id,
    required this.author,
    required this.text,
    required this.ts,
  });
}
