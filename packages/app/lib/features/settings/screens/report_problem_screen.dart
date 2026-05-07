import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:design_system/design_system.dart';
import '../../../shared/providers/providers.dart';

class ReportProblemScreen extends ConsumerStatefulWidget {
  const ReportProblemScreen({super.key});
  @override
  ConsumerState<ReportProblemScreen> createState() => _ReportProblemScreenState();
}

class _ReportProblemScreenState extends ConsumerState<ReportProblemScreen> {
  final _subjectCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  String _category = 'bug';
  bool _loading = false;

  final _categories = const {
    'bug': 'Bug / App Crash',
    'content': 'Inappropriate Content',
    'account': 'Account Issue',
    'payment': 'Rewards / Points Issue',
    'other': 'Other',
  };

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_subjectCtrl.text.trim().isEmpty || _bodyCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please fill in all fields'),
        backgroundColor: AppColors.warning,
      ));
      return;
    }
    setState(() => _loading = true);
    try {
      final uid = ref.read(supabaseClientProvider).auth.currentUser?.id;
      if (uid == null) throw Exception('Not logged in');

      await ref.read(supabaseClientProvider).from('support_tickets').insert({
        'user_id': uid,
        'subject': '[${_categories[_category]}] ${_subjectCtrl.text.trim()}',
        'body': _bodyCtrl.text.trim(),
        'status': 'open',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Report submitted! We\'ll get back to you soon.'),
          backgroundColor: AppColors.success,
        ));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.danger,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        title: Text('Report a Problem',
            style: TextStyle(
              fontWeight: FontWeight.w700, 
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary
            )),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Category', style: theme.textTheme.titleMedium),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _categories.entries.map((e) {
                final selected = _category == e.key;
                return GestureDetector(
                  onTap: () => setState(() => _category = e.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary : (isDark ? AppColors.surfaceDark : Colors.white),
                      borderRadius: AppRadius.full,
                      border: Border.all(
                        color: selected ? AppColors.primary : (isDark ? AppColors.borderDark : AppColors.border),
                      ),
                    ),
                    child: Text(e.value,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimary),
                        )),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _subjectCtrl,
              maxLength: 150,
              style: TextStyle(color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Subject',
                prefixIcon: Icon(Icons.title_rounded),
                hintText: 'Brief description of the issue',
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _bodyCtrl,
              maxLines: 6,
              maxLength: 1000,
              style: TextStyle(color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Details',
                prefixIcon: Icon(Icons.description_rounded),
                hintText: 'Describe the problem in detail. Include steps to reproduce if it\'s a bug.',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Submit Report',
              icon: Icons.send_rounded,
              onPressed: _submit,
              isLoading: _loading,
            ),
          ],
        ),
      ),
    );
  }
}
