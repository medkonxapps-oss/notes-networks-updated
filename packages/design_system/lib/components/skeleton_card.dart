import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../tokens/colors.dart';
import '../tokens/border_radius.dart';

class SkeletonCard extends StatelessWidget {
  final double height;
  const SkeletonCard({super.key, this.height = 280});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF1E293B) : AppColors.border,
      highlightColor: isDark ? const Color(0xFF334155) : Colors.white,
      child: Container(
        height: height,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: isDark ? Colors.black : Colors.white,
          borderRadius: AppRadius.lg,
        ),
      ),
    );
  }
}
