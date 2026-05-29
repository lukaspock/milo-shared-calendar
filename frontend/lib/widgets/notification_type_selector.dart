import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/user.dart';
import '../theme/app_theme.dart';

/// Two-option chooser for how the user wants to be notified about new events:
/// on-device (local push) or email. Used in onboarding and in Settings.
class NotificationTypeSelector extends StatelessWidget {
  const NotificationTypeSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final NotificationType value;
  final ValueChanged<NotificationType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Option(
            icon: Icons.notifications_active_rounded,
            title: 'On my phone',
            subtitle: 'Pop-up alerts on this device',
            selected: value == NotificationType.push,
            onTap: () => onChanged(NotificationType.push),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _Option(
            icon: Icons.mail_outline_rounded,
            title: 'Email',
            subtitle: 'Get an email each time',
            selected: value == NotificationType.email,
            onTap: () => onChanged(NotificationType.email),
          ),
        ),
      ],
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.accent.withValues(alpha: 0.10)
              : AppTheme.surfaceSoft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppTheme.accent : AppTheme.line,
            width: selected ? 2 : 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon,
                    size: 20,
                    color: selected ? AppTheme.accent : AppTheme.inkMuted),
                const Spacer(),
                if (selected)
                  const Icon(Icons.check_circle_rounded,
                      size: 18, color: AppTheme.accent),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: AppTheme.inkMuted,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
