import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:design_system/design_system.dart';
import 'package:shared/shared.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/utils/error_utils.dart';

class QuestionDetailScreen extends ConsumerStatefulWidget {
  final String questionId;
  const QuestionDetailScreen({super.key, required this.questionId});
  @override
  ConsumerState<QuestionDetailScreen> createState() => _QuestionDetailScreenState();
}

class _QuestionDetailScreenState extends ConsumerState<QuestionDetailScreen> {
  final _answerCtrl = TextEditingController();
  bool _submitting = false;
  ForumAnswer? _replyingTo;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(forumServiceProvider).incrementViews(widget.questionId));
  }

  @override
  void dispose() {
    _answerCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitAnswer() async {
    final question = ref.read(forumQuestionDetailProvider(widget.questionId)).valueOrNull;
    if (question?.isClosed == true) return;
    
    if (_answerCtrl.text.trim().isEmpty) return;
    setState(() => _submitting = true);
    try {
      await ref.read(forumServiceProvider).createAnswer(
        widget.questionId, 
        _answerCtrl.text.trim(),
        parentId: _replyingTo?.id,
      );
      _answerCtrl.clear();
      setState(() => _replyingTo = null);
      ref.invalidate(forumAnswersProvider(widget.questionId));
      ref.invalidate(forumQuestionDetailProvider(widget.questionId));
      if (mounted) FocusScope.of(context).unfocus();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(getFriendlyErrorMessage(e)), backgroundColor: AppColors.danger));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _editQuestion(ForumQuestion question) {
    context.push('/forums/create', extra: question);
  }

  Future<void> _toggleClosed(ForumQuestion question) async {
    try {
      final newState = !question.isClosed;
      await ref.read(forumServiceProvider).toggleClosed(question.id, newState);
      ref.invalidate(forumQuestionDetailProvider(widget.questionId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(newState ? 'Question marked as solved' : 'Question reopened'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(getFriendlyErrorMessage(e)),
          backgroundColor: AppColors.danger,
        ));
      }
    }
  }

  Future<void> _deleteQuestion() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardTheme.color,
        title: const Text('Delete Question'),
        content: const Text('Are you sure you want to delete this question? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true), 
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(forumServiceProvider).deleteQuestion(widget.questionId);
        ref.invalidate(forumQuestionsProvider);
        if (mounted) {
          context.pop();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Question deleted'),
            backgroundColor: AppColors.success,
          ));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(getFriendlyErrorMessage(e)),
            backgroundColor: AppColors.danger,
          ));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final questionAsync = ref.watch(forumQuestionDetailProvider(widget.questionId));
    final answersAsync = ref.watch(forumAnswersProvider(widget.questionId));
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Question'),
        actions: [
          if (questionAsync.valueOrNull?.userId == ref.watch(supabaseClientProvider).auth.currentUser?.id)
            PopupMenuButton(
              icon: const Icon(Icons.more_vert_rounded),
              itemBuilder: (ctx) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(
                  value: 'toggle_closed', 
                  child: Text(questionAsync.valueOrNull?.isClosed == true ? 'Reopen Question' : 'Mark as Solved'),
                ),
                const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: AppColors.danger))),
              ],
              onSelected: (v) {
                if (v == 'edit') _editQuestion(questionAsync.valueOrNull!);
                if (v == 'toggle_closed') _toggleClosed(questionAsync.valueOrNull!);
                if (v == 'delete') _deleteQuestion();
              },
            ),
        ],
      ),
      body: questionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => EmptyState(icon: Icons.error_outline_rounded, title: 'Error', subtitle: e.toString()),
        data: (question) {
          if (question == null) return const EmptyState(icon: Icons.search_off_rounded, title: 'Not found', subtitle: 'This question may have been deleted');
          
          return Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(forumQuestionDetailProvider(widget.questionId));
                    ref.invalidate(forumAnswersProvider(widget.questionId));
                  },
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _QuestionHeader(question: question),
                        const Divider(height: 40),
                        Text('Answers (${question.answersCount})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 16),
                        answersAsync.when(
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (e, _) => Text('Error loading answers: $e'),
                          data: (answers) {
                            if (answers.isEmpty) return const Padding(padding: EdgeInsets.only(top: 20), child: Center(child: Text('No answers yet. Be the first!')));
                            
                            // Organize answers and replies
                            final topLevelAnswers = answers.where((a) => a.parentId == null).toList();
                            
                            return ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: topLevelAnswers.length,
                              itemBuilder: (ctx, i) {
                                final answer = topLevelAnswers[i];
                                final replies = answers.where((a) => a.parentId == answer.id).toList();
                                return Column(
                                  children: [
                                    _AnswerTile(
                                      answer: answer, 
                                      onReply: () => setState(() => _replyingTo = answer),
                                    ),
                                    if (replies.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 38),
                                        child: Column(
                                          children: replies.map((r) => _AnswerTile(
                                            answer: r, 
                                            isReply: true,
                                            onReply: () => setState(() => _replyingTo = r),
                                          )).toList(),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              _buildReplyBar(context),
            ],
          );
        },
      ),
    );
  }

  Widget _buildReplyBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final question = ref.watch(forumQuestionDetailProvider(widget.questionId)).valueOrNull;
    
    if (question?.isClosed == true) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.1),
          border: Border(top: BorderSide(color: isDark ? AppColors.borderDark : AppColors.border)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 32),
            const SizedBox(height: 8),
            const Text(
              'This question is solved',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.success),
            ),
            const Text(
              'Replies are closed as a solution has been found.',
              style: TextStyle(fontSize: 12, color: AppColors.success),
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_replyingTo != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: isDark ? Colors.blueGrey.withValues(alpha: 0.2) : Colors.blue.withValues(alpha: 0.05),
            child: Row(
              children: [
                const Icon(Icons.reply_rounded, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Replying to ${_replyingTo!.authorName}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _replyingTo = null),
                  icon: const Icon(Icons.close_rounded, size: 16),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        Container(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 8 + MediaQuery.of(context).viewInsets.bottom),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            border: Border(top: BorderSide(color: isDark ? AppColors.borderDark : AppColors.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _answerCtrl,
                  maxLines: null,
                  decoration: InputDecoration(
                    hintText: _replyingTo == null ? 'Write your answer...' : 'Write your reply...', 
                    border: InputBorder.none,
                  ),
                ),
              ),
              _submitting
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  : IconButton(onPressed: _submitAnswer, icon: const Icon(Icons.send_rounded, color: AppColors.primary)),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuestionHeader extends StatelessWidget {
  final ForumQuestion question;
  const _QuestionHeader({required this.question});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () {
                context.push('/profile/${question.userId}');
              },
              child: AppAvatar(imageUrl: question.authorAvatarUrl, name: question.authorName ?? '?', size: 40, isVerified: question.authorIsVerified),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () {
                      context.push('/profile/${question.userId}');
                    },
                    child: Text(question.authorName ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  ),
                  Text(question.subject, style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            _timeAgo(question.createdAt, isDark),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            if (question.isClosed)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success,
                  borderRadius: AppRadius.md,
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text('SOLVED', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            Expanded(child: Text(question.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, height: 1.2))),
          ],
        ),
        const SizedBox(height: 12),
        Text(question.content, style: TextStyle(fontSize: 15, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary, height: 1.5)),
      ],
    );
  }

  Widget _timeAgo(DateTime date, bool isDark) {
    return Text(date.toLocal().toString().split('.')[0], style: TextStyle(fontSize: 11, color: isDark ? AppColors.textMutedDark : AppColors.textMuted));
  }
}

class _AnswerTile extends StatelessWidget {
  final ForumAnswer answer;
  final bool isReply;
  final VoidCallback onReply;

  const _AnswerTile({
    required this.answer, 
    this.isReply = false,
    required this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  context.push('/profile/${answer.userId}');
                },
                child: AppAvatar(imageUrl: answer.authorAvatarUrl, name: answer.authorName ?? '?', size: isReply ? 24 : 28, isVerified: answer.authorIsVerified),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () {
                  context.push('/profile/${answer.userId}');
                },
                child: Text(answer.authorName ?? 'Unknown', style: TextStyle(fontWeight: FontWeight.w600, fontSize: isReply ? 12 : 13)),
              ),
              const Spacer(),
              Text('${answer.createdAt.day}/${answer.createdAt.month}', style: TextStyle(fontSize: 11, color: isDark ? AppColors.textMutedDark : AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.only(left: isReply ? 34 : 38),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(answer.content, style: TextStyle(fontSize: 14, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary, height: 1.4)),
                const SizedBox(height: 4),
                InkWell(
                  onTap: onReply,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    child: Text(
                      'Reply', 
                      style: TextStyle(
                        fontSize: 12, 
                        color: AppColors.primary, 
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
