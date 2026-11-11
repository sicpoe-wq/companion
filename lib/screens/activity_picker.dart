import 'package:flutter/material.dart';

import '../data/scenarios.dart';
import '../models/scenario.dart';
import '../theme.dart';

Future<Scenario?> showActivityPicker(BuildContext context, {required String currentId}) {
  return showModalBottomSheet<Scenario>(
    context: context,
    backgroundColor: AppColors.bgLift,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.creamMuted.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Do something together',
                style: TextStyle(color: AppColors.cream, fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              const Text(
                'The scene changes, and they play along.',
                style: TextStyle(color: AppColors.creamMuted),
              ),
              const SizedBox(height: 12),
              for (final s in allScenarios)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: CircleAvatar(
                    backgroundColor: s.colors.accent.withValues(alpha: 0.25),
                    foregroundColor: s.colors.accent,
                    child: Icon(s.icon),
                  ),
                  title: Text(s.name, style: const TextStyle(color: AppColors.cream, fontWeight: FontWeight.w600)),
                  subtitle: Text(s.blurb, style: const TextStyle(color: AppColors.creamMuted)),
                  trailing: s.id == currentId
                      ? const Text('Now', style: TextStyle(color: AppColors.creamMuted, fontSize: 12))
                      : const Icon(Icons.chevron_right_rounded, color: AppColors.creamMuted),
                  onTap: () => Navigator.pop(ctx, s),
                ),
            ],
          ),
        ),
      );
    },
  );
}
