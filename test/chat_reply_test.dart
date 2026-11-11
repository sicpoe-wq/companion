import 'package:companion/models/chat_reply.dart';
import 'package:companion/models/emotion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChatReply.parse', () {
    test('clean JSON', () {
      const raw =
          '{"emotion":"happy","text":"Lucky you! Found a twenty in that jacket.","action":"smiles"}';
      final r = ChatReply.parse(raw);
      expect(r.parsedJson, isTrue);
      expect(r.emotion, Emotion.happy);
      expect(r.text, contains('Lucky you'));
      expect(r.action, 'smiles');
    });

    test('fenced JSON with preamble', () {
      const raw = '''
Sure, here you go:
```json
{
  "emotion": "laughing",
  "text": "That joke actually got me.",
  "action": null
}
```
''';
      final r = ChatReply.parse(raw);
      expect(r.parsedJson, isTrue);
      expect(r.emotion, Emotion.laughing);
      expect(r.text, 'That joke actually got me.');
      expect(r.action, isNull);
    });

    test('trailing comma and aliases', () {
      const messy =
          '{"feeling":"blushing","message":"Did I say that out loud?","action":"looks away",}';
      final r = ChatReply.parse(messy);
      expect(r.parsedJson, isTrue);
      expect(r.emotion, Emotion.embarrassed);
      expect(r.text, 'Did I say that out loud?');
    });

    test('emotion aliases', () {
      expect(EmotionCodec.parse('annoyed'), Emotion.angry);
      expect(EmotionCodec.parse('thinking'), Emotion.thoughtful);
      expect(EmotionCodec.parse('wow'), Emotion.surprised);
      expect(EmotionCodec.parse('anxious'), Emotion.worried);
      expect(EmotionCodec.parse('Thrilled!!'), Emotion.excited);
    });

    test('plain prose falls back to neutral', () {
      final r = ChatReply.parse('Whoa, no way — you actually did that?');
      expect(r.parsedJson, isFalse);
      expect(r.emotion, Emotion.neutral);
      expect(r.text, contains('you actually did that'));
    });

    test('embedded JSON among reasoning chatter', () {
      const raw =
          'The user is excited so I should be happy too. {"emotion":"excited","text":"Yes! Let\'s go right now.","action":"walk"} Done.';
      final r = ChatReply.parse(raw);
      expect(r.parsedJson, isTrue);
      expect(r.emotion, Emotion.excited);
      expect(r.text, startsWith('Yes!'));
      expect(r.action, 'walk');
    });
  });
}
