import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:design_system/design_system.dart';
import 'package:shared/shared.dart';
import '../../../shared/providers/providers.dart';
import '../../../core/constants/app_constants.dart';

class ForumScreen extends ConsumerStatefulWidget {
  const ForumScreen({super.key});
  @override
  ConsumerState<ForumScreen> createState() => _ForumScreenState();
}

class _ForumScreenState extends ConsumerState<ForumScreen> with SingleTickerProviderStateMixin {
  String? _selectedSubject = 'All';
  final _searchCtrl = TextEditingController();
  String _query = '';
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final myId = ref.watch(supabaseClientProvider).auth.currentUser?.id;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Forum', style: TextStyle(fontWeight: FontWeight.w800)),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: isDark ? Colors.white70 : AppColors.textSecondary,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'Public'),
            Tab(text: 'My Questions'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildQuestionList(null),
          _buildQuestionList(myId),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/forums/create'),
        label: const Text('Ask Question', style: TextStyle(fontWeight: FontWeight.w700)),
        icon: const Icon(Icons.add_comment_rounded),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildQuestionList(String? userIdFilter) {
    final questionsAsync = ref.watch(forumQuestionsProvider((
      subject: _selectedSubject == 'All' ? null : _selectedSubject,
      query: _query,
      userId: userIdFilter,
    )));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search questions...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: isDark ? AppColors.surfaceDark : Colors.grey[100],
                  border: OutlineInputBorder(borderRadius: AppRadius.md, borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: ['All', ...AppConstants.subjects].map((s) {
                  final isSelected = _selectedSubject == s;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(s, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                      selected: isSelected,
                      onSelected: (v) {
                        if (v) setState(() => _selectedSubject = s);
                      },
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(color: isSelected ? Colors.white : (isDark ? Colors.white70 : AppColors.textPrimary)),
                      backgroundColor: isDark ? AppColors.surfaceDark : Colors.grey[200],
                      showCheckmark: false,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.full),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: questionsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                error: (e, _) => EmptyState(icon: Icons.error_outline_rounded, title: 'Error', subtitle: e.toString()),
                data: (questions) {
                  if (questions.isEmpty) {
                    return EmptyState(
                      icon: Icons.quiz_rounded,
                      title: userIdFilter != null ? 'You haven\'t asked anything yet' : 'No questions found',
                      subtitle: userIdFilter != null ? 'Ask your first question now!' : 'Be the first to ask something!',
                      buttonLabel: 'Ask a Question',
                      onButtonPressed: () => context.push('/forums/create'),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async => ref.invalidate(forumQuestionsProvider),
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                      itemCount: questions.length,
                      itemBuilder: (ctx, i) => _QuestionCard(question: questions[i]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final ForumQuestion question;
  const _QuestionCard({required this.question});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => context.push('/forums/${question.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: AppRadius.lg,
          border: Border.all(color: isDark ? AppColors.borderDark : AppColors.border),
          boxShadow: question.isClosed ? [] : [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Opacity(
          opacity: question.isClosed ? 0.7 : 1.0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: AppRadius.full,
                    ),
                    child: Text(question.subject, style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  if (question.isClosed)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: AppRadius.full,
                      ),
                      child: const Text('SOLVED', style: TextStyle(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.w900)),
                    ),
                  const Spacer(),
                  Text(_timeAgo(question.createdAt), style: TextStyle(color: isDark ? AppColors.textMutedDark : AppColors.textMuted, fontSize: 11)),
                ],
              ),
              const SizedBox(height: 10),
              Text(question.title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppColors.textPrimary)),
              const SizedBox(height: 6),
              Text(question.content, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary)),
              const SizedBox(height: 14),
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      context.push('/profile/${question.userId}');
                    },
                    child: AppAvatar(imageUrl: question.authorAvatarUrl, name: question.authorName ?? '?', size: 24, isVerified: question.authorIsVerified),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      context.push('/profile/${question.userId}');
                    },
                    child: Text(question.authorName ?? 'Unknown', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary)),
                  ),
                  const Spacer(),
                  Icon(Icons.chat_bubble_outline_rounded, size: 16, color: isDark ? AppColors.textMutedDark : AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text('${question.answersCount}', style: TextStyle(fontSize: 12, color: isDark ? AppColors.textMutedDark : AppColors.textMuted)),
                  const SizedBox(width: 12),
                  Icon(Icons.visibility_outlined, size: 16, color: isDark ? AppColors.textMutedDark : AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text('${question.viewsCount}', style: TextStyle(fontSize: 12, color: isDark ? AppColors.textMutedDark : AppColors.textMuted)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}
