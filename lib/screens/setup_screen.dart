import 'package:flutter/material.dart';

import '../data/characters.dart';
import '../models/character.dart';
import '../models/emotion.dart';
import '../services/chat_controller.dart';
import '../theme.dart';
import '../widgets/avatar_stage.dart';

class SetupScreen extends StatefulWidget {
  final ChatController controller;
  final bool switching;
  const SetupScreen({super.key, required this.controller, this.switching = false});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  late AvatarStyle _style = widget.controller.state.style;
  late String _characterId = widget.controller.state.characterId;

  @override
  Widget build(BuildContext context) {
    final character = characterById(_characterId);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2A1C16), AppColors.bg],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
                child: Row(
                  children: [
                    if (widget.switching)
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_rounded, color: AppColors.cream),
                      )
                    else
                      const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Meet your companion',
                        style: TextStyle(
                          color: AppColors.cream,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Text(
                  'Pick a person and how they look. You can change the look later in Settings.',
                  style: TextStyle(color: AppColors.creamMuted, height: 1.35),
                ),
              ),
              _styleToggle(),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  child: Column(
                    key: ValueKey('${character.id}-${_style.name}'),
                    children: [
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 240,
                        child: AvatarStage(
                          character: character,
                          style: _style,
                          emotion: Emotion.happy,
                          talking: false,
                          ring: character.accent,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        character.name,
                        style: const TextStyle(
                          color: AppColors.cream,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${character.age}  ·  ${character.tagline}',
                        style: const TextStyle(color: AppColors.creamMuted),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(28, 12, 28, 0),
                        child: Text(
                          character.bio,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.cream, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    for (final c in allCharacters)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: _charChip(c),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Material(
                  color: character.accent,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () async {
                      if (widget.switching) {
                        await widget.controller.switchCharacter(character, style: _style);
                        if (context.mounted) Navigator.pop(context);
                      } else {
                        await widget.controller.completeSetup(character: character, style: _style);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                      child: Text(
                        widget.switching ? 'Switch to ${character.name}' : 'Start talking',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF2A120C),
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _styleToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            for (final s in AvatarStyle.values)
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _style = s),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _style == s ? AppColors.surfaceLift : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          s.label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _style == s ? AppColors.cream : AppColors.creamMuted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          s == AvatarStyle.cartoon ? 'Animated' : 'Painted',
                          style: const TextStyle(color: AppColors.creamMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _charChip(Character c) {
    final on = c.id == _characterId;
    return GestureDetector(
      onTap: () => setState(() => _characterId = c.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: on ? c.accent.withValues(alpha: 0.25) : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: on ? c.accent : AppColors.line, width: on ? 2 : 1),
        ),
        child: Column(
          children: [
            Text(
              c.name,
              style: TextStyle(
                color: on ? AppColors.cream : AppColors.creamMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              c.feminineVoice ? 'She / her' : 'He / him',
              style: const TextStyle(color: AppColors.creamMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
