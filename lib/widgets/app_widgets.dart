import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/connectivity_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class TopBar extends StatelessWidget implements PreferredSizeWidget {
  const TopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.back = false,
  });
  final String title;
  final String? subtitle;
  final bool back;

  @override
  Widget build(BuildContext context) {
    final online = context.watch<ConnectivityService>().online;
    return AppBar(
      leading: back ? const BackButton() : null,
      titleSpacing: back ? 0 : 16,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTheme.display.copyWith(fontSize: 19)),
          if (subtitle != null)
            Text(
              subtitle!,
              style: const TextStyle(fontSize: 11, color: AppColors.muted),
            ),
        ],
      ),
      actions: [
        Icon(
          online ? Icons.wifi : Icons.wifi_off,
          color: online ? AppColors.success : AppColors.danger,
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(58);
}

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.text, {super.key, this.color = AppColors.muted});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .13),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
    ),
  );
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: onPressed,
    icon: icon == null ? const SizedBox.shrink() : Icon(icon),
    label: Text(label.toUpperCase()),
    style: FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(50),
      backgroundColor: AppColors.accent,
      foregroundColor: AppColors.text,
      textStyle: const TextStyle(
        fontWeight: FontWeight.w700,
        letterSpacing: .5,
      ),
    ),
  );
}
