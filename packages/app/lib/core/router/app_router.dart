import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/shared.dart';
import 'package:app/shared/providers/providers.dart';
import 'package:app/features/auth/screens/forgot_password_screen.dart';
import 'package:app/features/auth/screens/reset_password_screen.dart';
import 'package:app/features/auth/screens/login_screen.dart';
import 'package:app/features/auth/screens/signup_screen.dart';
import 'package:app/features/auth/screens/otp_screen.dart';
import 'package:app/features/auth/screens/splash_screen.dart';
import 'package:app/features/auth/screens/teacher_approval_pending_screen.dart';
import 'package:app/features/onboarding/screens/profile_setup_screen.dart';
import 'package:app/features/onboarding/screens/education_setup_screen.dart';
import 'package:app/features/onboarding/screens/photo_setup_screen.dart';
import 'package:app/features/feed/screens/home_feed_screen.dart';
import 'package:app/features/explore/screens/explore_screen.dart';
import 'package:app/features/upload/screens/upload_select_screen.dart';
import 'package:app/features/upload/screens/upload_details_screen.dart';
import 'package:app/features/upload/screens/upload_success_screen.dart';
import 'package:app/features/profile/screens/my_profile_screen.dart';
import 'package:app/features/profile/screens/edit_profile_screen.dart';
import 'package:app/features/folders/screens/folder_view_screen.dart';
import 'package:app/features/note_detail/screens/note_detail_screen.dart';
import 'package:app/features/note_detail/screens/edit_note_screen.dart';
import 'package:app/features/note_detail/screens/offline_note_viewer.dart';
import 'package:app/features/leaderboard/screens/leaderboard_screen.dart';
import 'package:app/features/rewards/screens/rewards_screen.dart';
import 'package:app/features/notifications/screens/notifications_screen.dart';
import 'package:app/features/settings/screens/settings_screen.dart';
import 'package:app/features/settings/screens/change_password_screen.dart';
import 'package:app/features/settings/screens/help_screen.dart';
import 'package:app/features/settings/screens/report_problem_screen.dart';
import 'package:app/features/settings/screens/about_screen.dart';
import 'package:app/features/settings/screens/notification_prefs_screen.dart';
import 'package:app/features/settings/screens/privacy_settings_screen.dart';
import 'package:app/features/settings/screens/downloaded_notes_screen.dart';
import 'package:app/features/saved/screens/saved_notes_screen.dart';
import 'package:app/features/follow/followers_screen.dart';
import 'package:app/features/forum/screens/forum_screen.dart';
import 'package:app/features/forum/screens/create_question_screen.dart';
import 'package:app/features/forum/screens/question_detail_screen.dart';
import 'package:app/features/chat/screens/chat_list_screen.dart';
import 'package:app/features/chat/screens/chat_detail_screen.dart';
import 'package:app/features/collections/screens/collection_view_screen.dart';
import 'package:app/shared/widgets/main_shell.dart';
import 'package:app/core/services/local_db_service.dart';

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((dynamic _) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _subscription;
  @override
  void dispose() { _subscription.cancel(); super.dispose(); }
}

final routerProvider = Provider<GoRouter>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return GoRouter(
    initialLocation: '/',
    refreshListenable: GoRouterRefreshStream(supabase.auth.onAuthStateChange),
    redirect: (context, state) {
      final user = supabase.auth.currentUser;
      final isLoggedIn = user != null;
      final isSplash = state.matchedLocation == '/';
      final isAuthRoute = state.matchedLocation.startsWith('/auth');
      
      if (isSplash) return null;
      if (!isLoggedIn && !isAuthRoute) return '/auth/login';
      if (isLoggedIn && isAuthRoute) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/auth/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/auth/signup', builder: (_, __) => const SignupScreen()),
      GoRoute(path: '/auth/forgot-password', builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(
        path: '/auth/reset-password',
        builder: (_, s) => ResetPasswordScreen(email: s.uri.queryParameters['email'] ?? ''),
      ),
      GoRoute(path: '/auth/teacher-pending', builder: (_, __) => const TeacherApprovalPendingScreen()),
      GoRoute(path: '/auth/verify', builder: (_, s) => OtpScreen(email: s.uri.queryParameters['email'] ?? '')),
      GoRoute(path: '/onboarding/profile', builder: (_, __) => const ProfileSetupScreen()),
      GoRoute(path: '/onboarding/education', builder: (_, __) => const EducationSetupScreen()),
      GoRoute(path: '/onboarding/photo', builder: (_, __) => const PhotoSetupScreen()),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const HomeFeedScreen()),
          GoRoute(path: '/explore', builder: (_, __) => const ExploreScreen()),
          GoRoute(
            path: '/upload',
            builder: (_, __) => const UploadSelectScreen(),
            routes: [
              GoRoute(path: 'details', builder: (_, s) => UploadDetailsScreen(uploadData: (s.extra as Map<String, dynamic>?) ?? {})),
              GoRoute(path: 'success', builder: (_, s) => UploadSuccessScreen(noteId: s.uri.queryParameters['noteId'] ?? '')),
            ],
          ),
          GoRoute(path: '/profile/me', builder: (_, __) => const MyProfileScreen()),
          GoRoute(path: '/profile/edit', builder: (_, __) => const EditProfileScreen()),
          GoRoute(path: '/profile/:userId', builder: (_, s) {
            final uid = s.pathParameters['userId']!;
            return uid == 'me' ? const MyProfileScreen() : CreatorProfileScreen(userId: uid);
          }),
          GoRoute(path: '/profile/:userId/folder/:folderId', builder: (_, s) => FolderViewScreen(userId: s.pathParameters['userId']!, folderId: s.pathParameters['folderId']!)),
          // ── NEW: Followers / Following screens ──────────────────────
          GoRoute(
            path: '/profile/:userId/followers',
            builder: (_, s) => FollowListScreen(
              userId: s.pathParameters['userId']!,
              showFollowers: true,
            ),
          ),
          GoRoute(
            path: '/profile/:userId/following',
            builder: (_, s) => FollowListScreen(
              userId: s.pathParameters['userId']!,
              showFollowers: false,
            ),
          ),
          GoRoute(path: '/leaderboard', builder: (_, __) => const LeaderboardScreen()),
          GoRoute(path: '/rewards', builder: (_, __) => const RewardsScreen()),
          GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
          GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
          GoRoute(path: '/settings/password', builder: (_, __) => const ChangePasswordScreen()),
          GoRoute(path: '/settings/help', builder: (_, __) => const HelpScreen()),
          GoRoute(path: '/settings/report', builder: (_, __) => const ReportProblemScreen()),
          GoRoute(path: '/settings/about', builder: (_, __) => const AboutScreen()),
          GoRoute(path: '/settings/notifications', builder: (_, __) => const NotificationPrefsScreen()),
          GoRoute(path: '/settings/privacy', builder: (_, __) => const PrivacySettingsScreen()),
          GoRoute(path: '/settings/downloads', builder: (_, __) => const DownloadedNotesScreen()),
          GoRoute(path: '/forums', builder: (_, __) => const ForumScreen()),
          GoRoute(path: '/forums/create', builder: (_, s) => CreateQuestionScreen(question: s.extra as ForumQuestion?)),
          GoRoute(path: '/forums/:questionId', builder: (_, s) => QuestionDetailScreen(questionId: s.pathParameters['questionId']!)),
          GoRoute(path: '/chat', builder: (_, __) => const ChatListScreen()),
          GoRoute(path: '/chat/:roomId', builder: (_, s) => ChatDetailScreen(roomId: s.pathParameters['roomId']!, otherUser: s.extra as UserProfile)),
        ],
      ),
      GoRoute(path: '/notes/offline', builder: (_, s) => OfflineNoteViewer(note: s.extra as LocalNote)),
      GoRoute(path: '/notes/:noteId', builder: (_, s) => NoteDetailScreen(noteId: s.pathParameters['noteId']!)),
      GoRoute(path: '/notes/:noteId/edit', builder: (_, s) => EditNoteScreen(noteId: s.pathParameters['noteId']!)),
      GoRoute(path: '/collections/:collectionId', builder: (_, s) => CollectionViewScreen(collectionId: s.pathParameters['collectionId']!)),
      GoRoute(path: '/library', builder: (_, s) => SavedNotesScreen(initialTab: s.uri.queryParameters['tab'] == 'liked' ? 1 : 0)),
    ],
  );
});
