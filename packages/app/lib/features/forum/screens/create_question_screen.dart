import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:design_system/design_system.dart';
import 'package:shared/shared.dart';
import '../../../shared/providers/providers.dart';
import '../../../core/constants/app_constants.dart';

class CreateQuestionScreen extends ConsumerStatefulWidget {
  final ForumQuestion? question;
  const CreateQuestionScreen({super.key, this.question});
  @override
  ConsumerState<CreateQuestionScreen> createState() => _CreateQuestionScreenState();
}

class _CreateQuestionScreenState extends ConsumerState<CreateQuestionScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _contentCtrl;
  late String _subject;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.question?.title);
    _contentCtrl = TextEditingController(text: widget.question?.content);
    _subject = widget.question?.subject ?? AppConstants.subjects.first;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      if (widget.question != null) {
        await ref.read(forumServiceProvider).updateQuestion(
          widget.question!.id,
          _titleCtrl.text.trim(),
          _contentCtrl.text.trim(),
          _subject,
        );
        ref.invalidate(forumQuestionDetailProvider(widget.question!.id));
      } else {
        await ref.read(forumServiceProvider).createQuestion(
          _titleCtrl.text.trim(),
          _contentCtrl.text.trim(),
          _subject,
        );
      }
      ref.invalidate(forumQuestionsProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger));
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
        title: Text(widget.question != null ? 'Edit Question' : 'Ask a Question'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Subject', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : AppColors.textSecondary)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _subject,
                items: AppConstants.subjects.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) => setState(() => _subject = v!),
                decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
                dropdownColor: isDark ? AppColors.surfaceDark : Colors.white,
              ),
              const SizedBox(height: 20),
              Text('Title', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : AppColors.textSecondary)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(hintText: 'e.g. How to solve quadratic equations?', contentPadding: EdgeInsets.all(16)),
                validator: (v) => v == null || v.isEmpty ? 'Title is required' : (v.length < 5 ? 'Title too short' : null),
              ),
              const SizedBox(height: 20),
              Text('Details', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : AppColors.textSecondary)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _contentCtrl,
                maxLines: 6,
                decoration: const InputDecoration(hintText: 'Explain your question in detail...', contentPadding: EdgeInsets.all(16)),
                validator: (v) => v == null || v.isEmpty ? 'Content is required' : (v.length < 10 ? 'Content too short' : null),
              ),
              const SizedBox(height: 32),
              PrimaryButton(
                label: widget.question != null ? 'Save Changes' : 'Post Question',
                isLoading: _loading,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
