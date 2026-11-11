enum Emotion {
  neutral,
  happy,
  laughing,
  sad,
  angry,
  surprised,
  thoughtful,
  embarrassed,
  excited,
  worried,
}

extension EmotionLabel on Emotion {
  String get label => switch (this) {
        Emotion.neutral => 'Neutral',
        Emotion.happy => 'Happy',
        Emotion.laughing => 'Laughing',
        Emotion.sad => 'Sad',
        Emotion.angry => 'Annoyed',
        Emotion.surprised => 'Surprised',
        Emotion.thoughtful => 'Thoughtful',
        Emotion.embarrassed => 'Embarrassed',
        Emotion.excited => 'Excited',
        Emotion.worried => 'Worried',
      };
}

class EmotionCodec {
  static const aliases = <String, Emotion>{
    'neutral': Emotion.neutral,
    'calm': Emotion.neutral,
    'default': Emotion.neutral,
    'ok': Emotion.neutral,
    'okay': Emotion.neutral,
    'relaxed': Emotion.neutral,
    'happy': Emotion.happy,
    'smile': Emotion.happy,
    'smiling': Emotion.happy,
    'joy': Emotion.happy,
    'joyful': Emotion.happy,
    'pleased': Emotion.happy,
    'content': Emotion.happy,
    'grin': Emotion.happy,
    'laughing': Emotion.laughing,
    'laugh': Emotion.laughing,
    'lol': Emotion.laughing,
    'haha': Emotion.laughing,
    'hilarious': Emotion.laughing,
    'amused': Emotion.laughing,
    'sad': Emotion.sad,
    'unhappy': Emotion.sad,
    'down': Emotion.sad,
    'cry': Emotion.sad,
    'crying': Emotion.sad,
    'upset': Emotion.sad,
    'disappointed': Emotion.sad,
    'hurt': Emotion.sad,
    'angry': Emotion.angry,
    'annoyed': Emotion.angry,
    'mad': Emotion.angry,
    'irritated': Emotion.angry,
    'frustrated': Emotion.angry,
    'grumpy': Emotion.angry,
    'surprised': Emotion.surprised,
    'surprise': Emotion.surprised,
    'shocked': Emotion.surprised,
    'shock': Emotion.surprised,
    'wow': Emotion.surprised,
    'startled': Emotion.surprised,
    'amazed': Emotion.surprised,
    'thoughtful': Emotion.thoughtful,
    'thinking': Emotion.thoughtful,
    'pensive': Emotion.thoughtful,
    'curious': Emotion.thoughtful,
    'considering': Emotion.thoughtful,
    'confused': Emotion.thoughtful,
    'embarrassed': Emotion.embarrassed,
    'embarassed': Emotion.embarrassed,
    'blushing': Emotion.embarrassed,
    'blush': Emotion.embarrassed,
    'shy': Emotion.embarrassed,
    'sheepish': Emotion.embarrassed,
    'awkward': Emotion.embarrassed,
    'flustered': Emotion.embarrassed,
    'excited': Emotion.excited,
    'enthusiastic': Emotion.excited,
    'thrilled': Emotion.excited,
    'eager': Emotion.excited,
    'pumped': Emotion.excited,
    'energetic': Emotion.excited,
    'worried': Emotion.worried,
    'anxious': Emotion.worried,
    'nervous': Emotion.worried,
    'concerned': Emotion.worried,
    'scared': Emotion.worried,
    'uneasy': Emotion.worried,
    'afraid': Emotion.worried,
  };

  static Emotion parse(String? raw, {Emotion fallback = Emotion.neutral}) {
    if (raw == null) return fallback;
    final key = raw
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z]+'), '')
        .replaceAll(' ', '');
    if (key.isEmpty) return fallback;
    final direct = aliases[key];
    if (direct != null) return direct;
    for (final entry in aliases.entries) {
      if (key.contains(entry.key) || entry.key.contains(key)) {
        return entry.value;
      }
    }
    return fallback;
  }

  /// Best-effort guess when the model forgets to tag an emotion.
  static Emotion infer(String text) {
    final t = text.toLowerCase();
    final scores = <Emotion, int>{};
    void hit(Emotion e, List<String> words, [int w = 1]) {
      for (final word in words) {
        if (t.contains(word)) {
          scores[e] = (scores[e] ?? 0) + w;
        }
      }
    }

    hit(Emotion.laughing, ['hahaha', 'haha', 'lol', "i'm laughing", 'cracking up'], 3);
    hit(Emotion.excited, ['yes!', 'let’s go', "let's go", 'so excited', 'amazing!', 'yay'], 2);
    hit(Emotion.happy, ['glad', 'happy', 'love that', 'wonderful', 'nice!', 'awesome', '😊', '😄']);
    hit(Emotion.sad, ['sorry', 'sad', "that's hard", 'unfortunate', 'miss ', '😢']);
    hit(Emotion.angry, ['annoyed', 'frustrating', 'not okay', 'seriously?']);
    hit(Emotion.surprised, ['whoa', 'what?!', 'no way', 'wait, what', 'really?!', 'wow']);
    hit(Emotion.embarrassed, ['oops', 'awkward', 'did i say', 'blushing']);
    hit(Emotion.worried, ['careful', 'worried', 'are you okay', "i'm concerned", 'be safe']);
    hit(Emotion.thoughtful, ['maybe', 'i wonder', 'let me think', 'hmm', 'on the other hand']);
    if (scores.isEmpty) return Emotion.neutral;
    final best = scores.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return best.value > 0 ? best.key : Emotion.neutral;
  }
}
