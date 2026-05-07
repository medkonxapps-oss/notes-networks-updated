import 'package:flutter/material.dart';
import '../tokens/colors.dart';

class BadgeWidget extends StatelessWidget {
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final bool earned;
  final double size;

  const BadgeWidget({
    super.key,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    this.earned = false,
    this.size = 60,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: earned ? 1.0 : 0.4,
      child: Column(
        children: [
          Container(
            width: size, height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.15),
              border: Border.all(color: color, width: 2),
              boxShadow: earned ? [BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 12, spreadRadius: 2,
              )] : null,
            ),
            child: Icon(icon, color: color, size: size * 0.45),
          ),
          const SizedBox(height: 6),
          Text(name, style: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700,
            color: AppColors.textPrimary),
            textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
