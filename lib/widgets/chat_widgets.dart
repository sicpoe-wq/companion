import 'package:flutter/material.dart';

import '../models/message.dart';
import '../theme.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final Color accent;
  const ChatBubble({super.key, required this.message, required this.accent});

  @override
  Widget build(BuildContext context) {
    if (message.role == ChatRole.event) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              message.text,
              style: const TextStyle(
                color: AppColors.creamMuted,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      );
    }
    final mine = message.role == ChatRole.user;
    final bg = mine ? accent : AppColors.surface;
    final fg = mine ? const Color(0xFF2A120C) : AppColors.cream;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(mine ? 18 : 5),
              bottomRight: Radius.circular(mine ? 5 : 18),
            ),
          ),
          child: Text(
            message.text,
            style: TextStyle(color: fg, fontSize: 15.5, height: 1.35),
          ),
        ),
      ),
    );
  }
}

class TypingBubble extends StatelessWidget {
  final Color accent;
  final String preview;
  const TypingBubble({super.key, required this.accent, this.preview = ''});

  @override
  Widget build(BuildContext context) {
    if (preview.isNotEmpty) {
      return ChatBubble(
        accent: accent,
        message: ChatMessage(
          role: ChatRole.assistant,
          text: preview,
          at: DateTime.now(),
        ),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const _Dots(),
      ),
    );
  }
}

class _Dots extends StatefulWidget {
  const _Dots();
  @override
  State<_Dots> createState() => _DotsState();
}

class _DotsState extends State<_Dots> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.5),
                child: Opacity(
                  opacity: 0.35 + 0.65 * (1 - (((_c.value + i / 3) % 1) - 0.5).abs() * 2).clamp(0, 1),
                  child: const CircleAvatar(radius: 3.5, backgroundColor: AppColors.cream),
                ),
              ),
          ],
        );
      },
    );
  }
}

class Composer extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool enabled;
  final Color accent;
  const Composer({
    super.key,
    required this.controller,
    required this.onSend,
    required this.enabled,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: true,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) {
                  if (enabled) onSend();
                },
                style: const TextStyle(color: AppColors.cream, fontSize: 16),
                decoration: const InputDecoration(
                  hintText: 'Say something…',
                  contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: enabled ? accent : AppColors.surfaceLift,
              shape: const CircleBorder(),
              child: IconButton(
                onPressed: enabled ? onSend : null,
                icon: const Icon(Icons.send_rounded),
                color: enabled ? const Color(0xFF2A120C) : AppColors.creamMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
