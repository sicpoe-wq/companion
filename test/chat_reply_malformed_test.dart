import 'package:companion/models/chat_reply.dart';
import 'package:companion/models/emotion.dart';
import 'package:flutter_test/flutter_test.dart';

void noJson(ChatReply r) {
  expect(r.text, isNot(matches(RegExp(r'[{}\[\]]'))), reason: r.text);
  expect(r.text.toLowerCase(), isNot(contains('"emotion"')), reason: r.text);
  expect(r.text.toLowerCase(), isNot(contains('emotion":')), reason: r.text);
  expect(r.text, isNot(startsWith('"')), reason: r.text);
  expect(r.text.trim(), isNotEmpty);
}

void main() {
  const line = "Sounds great! Let's just relax and chat.";

  test('the exact v1.0 bug string', () {
    final r = ChatReply.parse(
      '{"{"emotion":"happy","text":"Sounds great! Let\'s just relax and chat.","action":null}',
    );
    noJson(r);
    expect(r.text, line);
    expect(r.emotion, Emotion.happy);
    expect(r.action, isNull);
  });

  final variants = <String, String>{
    'double encoded':
        r'"{\"emotion\":\"happy\",\"text\":\"Sounds great! Let\u0027s just relax and chat.\",\"action\":null}"',
    'escaped quotes without outer string':
        r'{\"emotion\":\"happy\",\"text\":\"Sounds great! Let'
        's just relax and chat.\"}',
    'leading junk': 'xx}{"{"{"emotion":"happy","text":"$line"}',
    'truncated': '{"emotion":"happy","text":"$line',
    'truncated after text': '{"emotion":"happy","text":"$line","act',
    'missing closing brace':
        '{"emotion": "happy", "text": "$line", "action": null',
    'fenced no lang': '```\n{"emotion":"happy","text":"$line"}\n```',
    'fence unterminated': '```json\n{"emotion":"happy","text":"$line"',
    'text holds json':
        '{"emotion":"neutral","text":"{\\"emotion\\":\\"happy\\",\\"text\\":\\"$line\\"}"}',
    'wrapper key': '{"reply":{"emotion":"happy","text":"$line"}}',
    'single quotes': "{'emotion': 'happy', 'text': 'Sounds great!'}",
    'trailing comma': '{"emotion":"happy","text":"$line",}',
    'chatter around':
        'Here is my reply: {"emotion":"happy","text":"$line"} hope that helps',
    'unquoted emotion': '{emotion: happy, "text": "$line"}',
  };
  variants.forEach((name, raw) {
    test('malformed: $name', () {
      final r = ChatReply.parse(raw);
      noJson(r);
      expect(r.text, contains('Sounds great'));
      expect(r.emotion, Emotion.happy, reason: name);
    });
  });

  test('pure garbage becomes clean neutral text', () {
    for (final raw in [
      '{"',
      '{}',
      '{"emotion":',
      '"}',
      '```json\n```',
      '',
      '   ',
    ]) {
      final r = ChatReply.parse(raw);
      noJson(r);
      expect(r.emotion, Emotion.neutral, reason: raw);
    }
  });

  test('plain text passes through with neutral emotion', () {
    final r = ChatReply.parse('Honestly? I love rainy days.');
    expect(r.text, 'Honestly? I love rainy days.');
    expect(r.emotion, Emotion.neutral);
    noJson(r);
  });

  test('plain text with stray braces is cleaned', () {
    final r = ChatReply.parse('{ Sure, let us go for a walk! }');
    noJson(r);
    expect(r.text, 'Sure, let us go for a walk!');
  });
}
