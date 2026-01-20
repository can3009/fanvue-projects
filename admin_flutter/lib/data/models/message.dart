class ChatMessage {
  ChatMessage({
    required this.id,
    required this.direction,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String direction;
  final String content;
  final DateTime? createdAt;

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    final content = map['content'] ??
        map['text'] ??
        map['message'] ??
        map['body'] ??
        '';
    return ChatMessage(
      id: map['id']?.toString() ?? '',
      direction: map['direction']?.toString() ?? 'inbound',
      content: content.toString(),
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? ''),
    );
  }
}
