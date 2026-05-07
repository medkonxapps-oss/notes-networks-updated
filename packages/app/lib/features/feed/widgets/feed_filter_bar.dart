import 'package:flutter/material.dart';
import 'package:design_system/design_system.dart';
import '../../../core/constants/app_constants.dart';

class FeedFilterBar extends StatelessWidget {
  final String? selectedSubject;
  final ValueChanged<String?> onSubjectChanged;

  const FeedFilterBar({super.key, this.selectedSubject, required this.onSubjectChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: theme.appBarTheme.backgroundColor,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            TagChip(
              label: 'All',
              isSelected: selectedSubject == null,
              onTap: () => onSubjectChanged(null),
            ),
            const SizedBox(width: 8),
            ...AppConstants.subjects.take(12).map((s) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TagChip(
                label: s,
                isSelected: selectedSubject == s,
                onTap: () => onSubjectChanged(selectedSubject == s ? null : s),
              ),
            )),
          ],
        ),
      ),
    );
  }
}
