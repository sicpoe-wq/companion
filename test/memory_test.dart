import 'package:companion/models/emotion.dart';
import 'package:companion/models/message.dart';
import 'package:companion/services/app_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ChatMessage u(String t, int i) =>
      ChatMessage(role: ChatRole.user, text: t, at: DateTime(2026, 1, 1, 0, i));
  ChatMessage a(String t, int i) => ChatMessage(
    role: ChatRole.assistant,
    text: t,
    emotion: Emotion.happy,
    at: DateTime(2026, 1, 1, 0, i),
  );

  test('keeps short histories intact', () {
    final msgs = [u('hi', 1), a('hey', 2)];
    final (sum, kept) = compactMemory('', msgs, keep: 16);
    expect(sum, isEmpty);
    expect(kept, same(msgs));
  });

  test('folds overflow into a running summary', () {
    final msgs = <ChatMessage>[
      for (var i = 0; i < 12; i++) ...[
        u('user turn $i talking about topic $i', i * 2),
        a('reply $i with a thought', i * 2 + 1),
      ],
    ];
    final (sum, kept) = compactMemory('', msgs, keep: 6);
    expect(kept.length, 6);
    expect(kept.first.text, contains('user turn 9'));
    expect(sum, contains('User: user turn 0'));
    expect(sum, contains('Them: reply 8'));
    expect(sum.contains('user turn 9'), isFalse);
  });

  test('trims a long existing summary', () {
    final long = 'Earlier notes. ' * 400;
    final msgs = [for (var i = 0; i < 10; i++) u('x$i', i)];
    final (sum, kept) = compactMemory(long, msgs, keep: 4);
    expect(kept.length, 4);
    expect(sum.length, lessThanOrEqualTo(AppStore.maxSummaryChars));
    expect(sum, contains('User: x'));
  });
}
