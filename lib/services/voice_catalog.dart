/// Curated on-device neural voices (Piper VITS, int8) run with sherpa-onnx.
/// Downloaded once on demand (~20 MB each) from the sherpa-onnx model release,
/// then everything runs offline on the phone.
class NaturalVoice {
  final String id; // e.g. en_US-hfc_female-medium
  final String label;
  final String description;
  final bool female;
  final int approxMb;
  final String license;

  const NaturalVoice(
    this.id,
    this.label,
    this.description, {
    required this.female,
    this.approxMb = 20,
    required this.license,
  });

  String get archiveName => 'vits-piper-$id-int8';
  Uri get url => Uri.parse(
    'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/$archiveName.tar.bz2',
  );
  String get modelFile => '$id.onnx';
}

const naturalVoices = <NaturalVoice>[
  // Female
  NaturalVoice(
    'en_US-hfc_female-medium',
    'Hazel',
    'Warm, conversational (US)',
    female: true,
    license: 'CC BY-NC-SA 4.0',
  ),
  NaturalVoice(
    'en_US-amy-medium',
    'Amy',
    'Bright and lively (US)',
    female: true,
    license: 'see MODEL_CARD',
  ),
  NaturalVoice(
    'en_US-kristin-medium',
    'Kristin',
    'Soft and calm (US)',
    female: true,
    license: 'Public domain',
  ),
  NaturalVoice(
    'en_US-lessac-medium',
    'Linda',
    'Clear and expressive (US)',
    female: true,
    license: 'Blizzard 2013 (non-commercial)',
  ),
  NaturalVoice(
    'en_GB-jenny_dioco-medium',
    'Jenny',
    'Gentle (British)',
    female: true,
    license: 'see MODEL_CARD',
  ),
  // Male
  NaturalVoice(
    'en_US-hfc_male-medium',
    'Hal',
    'Easygoing, conversational (US)',
    female: false,
    license: 'CC BY-NC-SA 4.0',
  ),
  NaturalVoice(
    'en_US-ryan-medium',
    'Ryan',
    'Deeper, confident (US)',
    female: false,
    license: 'CC BY-NC-SA 4.0',
  ),
  NaturalVoice(
    'en_US-joe-medium',
    'Joe',
    'Casual (US)',
    female: false,
    license: 'CC0',
  ),
  NaturalVoice(
    'en_US-john-medium',
    'John',
    'Mellow (US)',
    female: false,
    license: 'Public domain',
  ),
  NaturalVoice(
    'en_GB-alan-medium',
    'Alan',
    'Relaxed (British)',
    female: false,
    license: 'see MODEL_CARD',
  ),
];

NaturalVoice voiceById(String id) => naturalVoices.firstWhere(
  (v) => v.id == id,
  orElse: () => naturalVoices.first,
);

List<NaturalVoice> voicesFor({required bool female}) =>
    naturalVoices.where((v) => v.female == female).toList();

/// Distinct defaults per character.
String defaultVoiceFor(String characterId) => switch (characterId) {
  'julian' => 'en_US-hfc_male-medium',
  _ => 'en_US-hfc_female-medium',
};

/// Split a reply into sentence-sized chunks so playback can start while the
/// rest is still being synthesized.
List<String> splitSentences(String text) {
  final t = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (t.isEmpty) return const [];
  final parts = <String>[];
  final re = RegExp(r'[^.!?…]+[.!?…]+["”’)]*\s*|[^.!?…]+$');
  for (final m in re.allMatches(t)) {
    final s = m.group(0)!.trim();
    if (s.isEmpty) continue;
    // Merge very short fragments ("Oh." "Hm!") into the next chunk.
    if (parts.isNotEmpty && parts.last.length < 12) {
      parts[parts.length - 1] = '${parts.last} $s';
    } else {
      parts.add(s);
    }
  }
  return parts.isEmpty ? [t] : parts;
}
