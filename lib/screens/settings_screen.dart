import 'package:flutter/material.dart';

import '../models/character.dart';
import '../screens/setup_screen.dart';
import '../services/chat_controller.dart';
import '../theme.dart';

class SettingsScreen extends StatelessWidget {
  final ChatController controller;
  const SettingsScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
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
                    title: const Text('Semi-realistic portraits', style: TextStyle(color: AppColors.cream)),
                    subtitle: Text(
                      c.style == AvatarStyle.realistic
                          ? 'Painted portraits of ${c.character.name}, with a living blink and breath.'
                          : 'Using the cartoon face. Turn this on for painted portraits.',
                      style: const TextStyle(color: AppColors.creamMuted),
                    ),
                    value: c.style == AvatarStyle.realistic,
                    activeThumbColor: c.character.accent,
                    onChanged: (on) => c.setStyle(on ? AvatarStyle.realistic : AvatarStyle.cartoon),
                  ),
                  ListTile(
                    title: Text(
                      'Current style: ${c.style.label}',
                      style: const TextStyle(color: AppColors.creamMuted, fontSize: 13),
                    ),
                  ),
                ],
              ),
              const _Label('Voice'),
              _card(
                children: [
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    title: const Text('Speak replies out loud', style: TextStyle(color: AppColors.cream)),
                    subtitle: const Text(
                      'Uses your phone’s built-in text-to-speech. Free, no account.',
                      style: TextStyle(color: AppColors.creamMuted),
                    ),
                    value: c.state.ttsEnabled,
                    activeThumbColor: c.character.accent,
                    onChanged: c.setTts,
                  ),
                ],
              ),
              const _Label('Companion'),
              _card(
                children: [
                  ListTile(
                    title: Text(c.character.name, style: const TextStyle(color: AppColors.cream, fontWeight: FontWeight.w600)),
                    subtitle: Text(c.character.tagline, style: const TextStyle(color: AppColors.creamMuted)),
                    trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.creamMuted),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SetupScreen(controller: c, switching: true),
                        ),
                      );
                    },
                  ),
                  const Divider(color: AppColors.line, height: 1),
                  ListTile(
                    title: const Text('New conversation', style: TextStyle(color: AppColors.cream)),
                    subtitle: const Text(
                      'Keeps this companion, clears the chat and memory.',
                      style: TextStyle(color: AppColors.creamMuted),
                    ),
                    onTap: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: AppColors.surface,
                          title: const Text('Start over?', style: TextStyle(color: AppColors.cream)),
                          content: const Text(
                            'This clears the conversation and memory, but keeps your companion and look.',
                            style: TextStyle(color: AppColors.creamMuted),
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                            FilledButton(
                              style: FilledButton.styleFrom(backgroundColor: c.character.accent, foregroundColor: const Color(0xFF2A120C)),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('New conversation'),
                            ),
                          ],
                        ),
                      );
                      if (ok == true) {
                        await c.newConversation();
                        if (context.mounted) Navigator.pop(context);
                      }
                    },
                  ),
                ],
              ),
              const _Label('About'),
              _card(
                children: [
                  const ListTile(
                    title: Text('Companion 1.0', style: TextStyle(color: AppColors.cream)),
                    subtitle: Text(
                      'Chat is powered by Pollinations’ free text API (GPT-OSS 20B), with no API key. '
                      'Replies are limited to about one every 30 seconds on the free tier. '
                      'Chat history stays on this phone.',
                      style: TextStyle(color: AppColors.creamMuted, height: 1.35),
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
