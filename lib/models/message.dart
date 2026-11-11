import 'emotion.dart';

enum ChatRole { user, assistant, event }

class ChatMessage {
  final ChatRole role;
  final String text;
  final Emotion? emotion;
  final String? action;
  final DateTime at;

  const ChatMessage({
    required this.role,
    required this.text,
    this.emotion,
    this.action,
    required this.at,
  });

  Map<String, dynamic> toJson() => {
        'role': role.name,
        'text': text,
        'emotion': emotion?.name,
        'action': action,
        'at': at.toIso8601String(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final roleName = (json['role'] ?? 'assistant').toString();
    return ChatMessage(
      role: ChatRole.values.firstWhere(
        (r) => r.name == roleName,
        orElse: () => ChatRole.assistant,
      ),
      text: (json['text'] ?? '').toString(),
      emotion: json['emotion'] == null
          ? null
          : EmotionCodec.parse(json['emotion'].toString()),
      action: json['action']?.toString(),
      at: DateTime.tryParse(json['at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}
