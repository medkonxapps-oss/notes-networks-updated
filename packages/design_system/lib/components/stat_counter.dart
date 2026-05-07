import 'package:flutter/material.dart';
import '../tokens/colors.dart';

class StatCounter extends StatelessWidget {
  final String value;
  final String label;
  final VoidCallback? onTap;

  const StatCounter({super.key, required this.value, required this.label, this.onTap});    

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(value, style: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : AppColors.textPrimary,
          )),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w500,
            color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
          )),
        ],
      ),
    );
  }
}
