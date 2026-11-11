import 'package:flutter/material.dart';

import '../data/characters.dart';
import '../models/character.dart';
import '../services/app_store.dart';
import '../services/voice_catalog.dart';
import '../screens/setup_screen.dart';
import '../services/chat_controller.dart';
import '../theme.dart';

class SettingsScreen extends StatelessWidget {
  final ChatController controller;
  const SettingsScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([controller, controller.tts]),
      builder: (context, _) {
        final c = controller;
        return Scaffold(
          backgroundColor: AppColors.bg,
          appBar: AppBar(title: const Text('Settings')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              const _Label('Look'),
              _card(
                children: [
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    title: const Text(
                      'Semi-realistic portraits',
                      style: TextStyle(color: AppColors.cream),
                    ),
                    subtitle: Text(
                      c.style == AvatarStyle.realistic
                          ? 'Painted portraits of ${c.character.name}, with gentle idle motion.'
                          : 'Using the cartoon face. Turn this on for painted portraits.',
                      style: const TextStyle(color: AppColors.creamMuted),
                    ),
                    value: c.style == AvatarStyle.realistic,
                    activeThumbColor: c.character.accent,
                    onChanged: (on) => c.setStyle(
                      on ? AvatarStyle.realistic : AvatarStyle.cartoon,
                    ),
                  ),
                  ListTile(
                    title: Text(
                      'Current style: ${c.style.label}',
                      style: const TextStyle(
                        color: AppColors.creamMuted,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const _Label('Voice'),
              _card(
                children: [
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    title: const Text(
                      'Speak replies out loud',
                      style: TextStyle(color: AppColors.cream),
                    ),
                    value: c.state.ttsEnabled,
                    activeThumbColor: c.character.accent,
                    onChanged: c.setTts,
                  ),
                  const Divider(color: AppColors.line, height: 1),
                  RadioGroup<VoiceEngine>(
                    groupValue: c.state.voiceEngine,
                    onChanged: (v) {
                      if (v != null) c.setVoiceEngine(v);
                    },
                    child: Column(
                      children: [
                        RadioListTile<VoiceEngine>(
                          value: VoiceEngine.natural,
                          activeColor: c.character.accent,
                          title: const Text(
                            'Natural voice (on-device AI)',
                            style: TextStyle(color: AppColors.cream),
                          ),
                          subtitle: const Text(
                            'Neural voices that run on your phone. Free and offline after a one-time ~20 MB download per voice.',
                            style: TextStyle(
                              color: AppColors.creamMuted,
                              height: 1.3,
                            ),
                          ),
                        ),
                        RadioListTile<VoiceEngine>(
                          value: VoiceEngine.device,
                          activeColor: c.character.accent,
                          title: const Text(
                            'Phone voice',
                            style: TextStyle(color: AppColors.cream),
                          ),
                          subtitle: const Text(
                            "Your phone's built-in text-to-speech (best available voice is picked automatically).",
                            style: TextStyle(
                              color: AppColors.creamMuted,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (c.state.voiceEngine == VoiceEngine.natural) ...[
                    const Divider(color: AppColors.line, height: 1),
                    _VoicePicker(controller: c),
                  ],
                  const Divider(color: AppColors.line, height: 1),
                  ListTile(
                    leading: Icon(
                      c.tts.speaking
                          ? Icons.stop_circle_rounded
                          : Icons.play_circle_fill_rounded,
                      color: c.character.accent,
                      size: 32,
                    ),
                    title: Text(
                      c.tts.speaking
                          ? 'Stop'
                          : 'Test ${c.character.name}’s voice',
                      style: const TextStyle(color: AppColors.cream),
                    ),
                    subtitle: Text(
                      c.state.voiceEngine == VoiceEngine.natural &&
                              !c.tts.isInstalled(c.voiceIdFor(c.character.id))
                          ? 'Natural voice not downloaded yet — this will use the phone voice.'
                          : 'Plays a short sample line.',
                      style: const TextStyle(color: AppColors.creamMuted),
                    ),
                    onTap: () => c.tts.speaking ? c.tts.stop() : c.testVoice(),
                  ),
                ],
              ),
              const _Label('Chats'),
              _card(
                children: [
                  for (final ch in allCharacters) ...[
                    ListTile(
                      leading: Icon(
                        Icons.delete_outline_rounded,
                        color: ch.accent,
                      ),
                      title: Text(
                        'Erase chat with ${ch.name}',
                        style: const TextStyle(color: AppColors.cream),
                      ),
                      subtitle: Text(
                        c.state.hasHistory(ch.id)
                            ? 'Deletes ${ch.name}’s messages and memory. ${ch.name} will greet you fresh.'
                            : 'No saved chat yet.',
                        style: const TextStyle(color: AppColors.creamMuted),
                      ),
                      enabled: c.state.hasHistory(ch.id),
                      onTap: () async {
                        final ok = await _confirm(
                          context,
                          title: 'Erase chat with ${ch.name}?',
                          body:
                              'This permanently deletes your conversation and ${ch.name}’s memory of it. This can’t be undone.',
                          action: 'Erase',
                        );
                        if (ok) {
                          await c.eraseChat(ch.id);
                          if (context.mounted)
                            _toast(context, 'Chat with ${ch.name} erased');
                        }
                      },
                    ),
                    const Divider(color: AppColors.line, height: 1),
                  ],
                  ListTile(
                    leading: const Icon(
                      Icons.delete_forever_rounded,
                      color: AppColors.danger,
                    ),
                    title: const Text(
                      'Erase all chats',
                      style: TextStyle(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: const Text(
                      'Deletes every conversation and memory for all companions.',
                      style: TextStyle(color: AppColors.creamMuted),
                    ),
                    onTap: () async {
                      final ok = await _confirm(
                        context,
                        title: 'Erase all chats?',
                        body:
                            'This permanently deletes the conversations and memories of every companion. This can’t be undone.',
                        action: 'Erase all',
                      );
                      if (ok) {
                        await c.eraseAllChats();
                        if (context.mounted)
                          _toast(context, 'All chats erased');
                      }
                    },
                  ),
                ],
              ),
              const _Label('Companion'),
              _card(
                children: [
                  ListTile(
                    title: Text(
                      c.character.name,
                      style: const TextStyle(
                        color: AppColors.cream,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      'Switch companion — each one keeps their own chat.',
                      style: const TextStyle(color: AppColors.creamMuted),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.creamMuted,
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              SetupScreen(controller: c, switching: true),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const _Label('About'),
              _card(
                children: [
                  const ListTile(
                    title: Text(
                      'Companion 1.2',
                      style: TextStyle(color: AppColors.cream),
                    ),
                    subtitle: Text(
                      'Chat is powered by Pollinations’ free text API (GPT-OSS 20B), with no API key. '
                      'Replies are limited to about one every 30 seconds on the free tier. '
                      'Chats are saved on this phone, separately for each companion. '
                      'Natural voices: Piper models via sherpa-onnx, run fully on-device.',
                      style: TextStyle(
                        color: AppColors.creamMuted,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  static Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String body,
    required String action,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(title, style: const TextStyle(color: AppColors.cream)),
        content: Text(
          body,
          style: const TextStyle(color: AppColors.creamMuted, height: 1.35),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              action,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    return ok == true;
  }

  static void _toast(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Widget _card({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 18, 8, 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AppColors.creamMuted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _VoicePicker extends StatelessWidget {
  final ChatController controller;
  const _VoicePicker({required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final ch = c.character;
    final current = c.voiceIdFor(ch.id);
    final options = voicesFor(female: ch.feminineVoice);
    final progress = c.tts.downloads[current];
    final err = c.tts.downloadErrors[current];
    final installed = c.tts.isInstalled(current);
    final v = voiceById(current);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${ch.name}’s voice',
            style: const TextStyle(color: AppColors.creamMuted, fontSize: 12.5),
          ),
          const SizedBox(height: 4),
          DropdownButton<String>(
            value: current,
            isExpanded: true,
            dropdownColor: AppColors.surface,
            underline: Container(height: 1, color: AppColors.line),
            items: [
              for (final o in options)
                DropdownMenuItem(
                  value: o.id,
                  child: Text(
                    '${o.label} — ${o.description}${c.tts.isInstalled(o.id) ? '  ✓' : ''}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.cream),
                  ),
                ),
            ],
            onChanged: (id) {
              if (id != null) c.setVoice(ch.id, id);
            },
          ),
          const SizedBox(height: 8),
          if (progress != null) ...[
            LinearProgressIndicator(
              value: progress,
              color: ch.accent,
              backgroundColor: AppColors.line,
            ),
            const SizedBox(height: 6),
            Text(
              progress < 0.86
                  ? 'Downloading ${v.label}… ${(progress * 100).round()}%'
                  : 'Unpacking…',
              style: const TextStyle(
                color: AppColors.creamMuted,
                fontSize: 12.5,
              ),
            ),
          ] else if (installed)
            Row(
              children: [
                Icon(Icons.check_circle_rounded, size: 18, color: ch.accent),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Downloaded — works offline',
                    style: TextStyle(
                      color: AppColors.creamMuted,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: Text(
                    err ?? 'Not downloaded yet (~${v.approxMb} MB, one time).',
                    style: TextStyle(
                      color: err != null
                          ? AppColors.danger
                          : AppColors.creamMuted,
                      fontSize: 12.5,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => c.downloadVoice(current),
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Download'),
                  style: TextButton.styleFrom(foregroundColor: ch.accent),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
