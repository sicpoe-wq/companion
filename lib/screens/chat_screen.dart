import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/emotion.dart';
import '../screens/activity_picker.dart';
import '../screens/settings_screen.dart';
import '../screens/setup_screen.dart';
import '../services/chat_controller.dart';
import '../theme.dart';
import '../widgets/avatar_stage.dart';
import '../widgets/chat_widgets.dart';
import '../widgets/scene_background.dart';

class ChatScreen extends StatefulWidget {
  final ChatController controller;
  const ChatScreen({super.key, required this.controller});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _text = TextEditingController();
  final _scroll = ScrollController();

  ChatController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    c.addListener(_onCtrl);
  }

  @override
  void dispose() {
    c.removeListener(_onCtrl);
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onCtrl() {
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 48,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final t = _text.text;
    if (t.trim().isEmpty || c.busy) return;
    _text.clear();
    await c.send(t);
  }

  Future<void> _activities() async {
    final s = await showActivityPicker(context, currentId: c.scenario.id);
    if (s != null && s.id != c.scenario.id) {
      await c.setScenario(s);
    }
  }

  @override
  Widget build(BuildContext context) {
    final character = c.character;
    final inset = MediaQuery.of(context).viewInsets.bottom;
    final compact = inset > 80;
    final ring = emotionRing(c.displayEmotion, character.accent);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            Positioned.fill(child: SceneBackground(scenario: c.scenario)),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.15),
                      AppColors.bg.withValues(alpha: 0.72),
                      AppColors.bg,
                    ],
                    stops: const [0, 0.42, 0.62],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  _topBar(character.name),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    height: compact ? 140 : 230,
                    padding: const EdgeInsets.only(bottom: 4),
                    child: AvatarStage(
                      character: character,
                      style: c.style,
                      emotion: c.displayEmotion,
                      talking: c.talking,
                      ring: ring,
                    ),
                  ),
                  _emotionChip(c.displayEmotion, c.scenario.name, ring),
                  if (c.error != null) _errorBar(),
                  if (c.pendingSuggestion != null) _suggestionBar(),
                  Expanded(
                    child: ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.only(top: 8, bottom: 8),
                      itemCount: c.messages.length + (c.busy ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (i == c.messages.length) {
                          return TypingBubble(accent: character.accent, preview: c.typingBuffer);
                        }
                        return ChatBubble(message: c.messages[i], accent: character.accent);
                      },
                    ),
                  ),
                  Composer(
                    controller: _text,
                    onSend: _send,
                    enabled: !c.busy,
                    accent: character.accent,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar(String name) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Switch companion',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SetupScreen(controller: c, switching: true),
                ),
              );
            },
            icon: const Icon(Icons.people_alt_rounded, color: AppColors.cream),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: AppColors.cream,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  c.scenario.name,
                  style: const TextStyle(color: AppColors.creamMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: c.state.ttsEnabled ? 'Voice on' : 'Voice off',
            onPressed: () => c.setTts(!c.state.ttsEnabled),
            icon: Icon(
              c.state.ttsEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
              color: c.state.ttsEnabled ? c.character.accent : AppColors.cream,
            ),
          ),
          IconButton(
            tooltip: 'Do something',
            onPressed: _activities,
            icon: const Icon(Icons.explore_rounded, color: AppColors.cream),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => SettingsScreen(controller: c)),
              );
            },
            icon: const Icon(Icons.settings_rounded, color: AppColors.cream),
          ),
        ],
      ),
    );
  }

  Widget _emotionChip(Emotion e, String scene, Color ring) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: ring.withValues(alpha: 0.5)),
        ),
        child: Text(
          '${e.label}  ·  $scene',
          style: const TextStyle(color: AppColors.cream, fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  Widget _errorBar() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: AppColors.cream, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              c.error!,
              style: const TextStyle(color: AppColors.cream, fontSize: 13.5, height: 1.3),
            ),
          ),
          TextButton(
            onPressed: c.retry,
            child: const Text('Retry', style: TextStyle(color: AppColors.cream, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _suggestionBar() {
    final id = c.pendingSuggestion!;
    final label = switch (id) {
      'walk' => 'go for a walk',
      'cafe' => 'grab a table at the cafe',
      'twenty_questions' => 'play 20 Questions',
      'trivia' => 'play trivia',
      'story' => 'start a story adventure',
      _ => 'hang out',
    };
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: c.character.accent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${c.character.name} suggested you $label.',
              style: const TextStyle(color: AppColors.cream, fontSize: 13.5),
            ),
          ),
          TextButton(onPressed: c.dismissSuggestion, child: const Text('Not now')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: c.character.accent,
              foregroundColor: const Color(0xFF2A120C),
              visualDensity: VisualDensity.compact,
            ),
            onPressed: c.acceptSuggestion,
            child: const Text('Let’s go'),
          ),
        ],
      ),
    );
  }
}
