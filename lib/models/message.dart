import 'chat_reply.dart';
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
      text: _clean(roleName, (json['text'] ?? '').toString()),
      emotion: json['emotion'] == null
          ? null
          : EmotionCodec.parse(json['emotion'].toString()),
      action: json['action']?.toString(),
      at: DateTime.tryParse(json['at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  /// v1.0 could store a raw/malformed JSON payload as the text; clean it up.
  static String _clean(String role, String text) {
    if (role != 'assistant') return text;
    if (!RegExp(r'[{}]|"\s*:').hasMatch(text)) return text;
    return ChatReply.parse(text).text;
  }
}
