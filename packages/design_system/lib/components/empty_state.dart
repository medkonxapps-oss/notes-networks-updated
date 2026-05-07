import 'package:flutter/material.dart';
import '../tokens/colors.dart';
import 'primary_button.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? buttonLabel;
  final VoidCallback? onButtonPressed;
  final Color? backgroundColor;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.buttonLabel,
    this.onButtonPressed,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96, height: 96,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2D2D4D) : AppColors.primarySurface,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            Text(title, style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(subtitle, style: TextStyle(
              fontSize: 14, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary, height: 1.5,
            ), textAlign: TextAlign.center),
            if (buttonLabel != null && onButtonPressed != null) ...[
              const SizedBox(height: 24),
              PrimaryButton(
                label: buttonLabel!,
                onPressed: onButtonPressed,
                width: 200,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
