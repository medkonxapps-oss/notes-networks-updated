import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:design_system/design_system.dart';
import 'shared/layout/admin_shell.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/users/users_screen.dart';
import 'features/notes/notes_screen.dart';
import 'features/moderation/moderation_screen.dart';
import 'features/analytics/analytics_screen.dart';
import 'features/rewards_mgr/rewards_mgr_screen.dart';
import 'features/notifications_mgr/notifications_mgr_screen.dart';
import 'features/support/support_screen.dart';
import 'features/config/config_screen.dart';
import 'features/auth/admin_auth_provider.dart';
import 'features/auth/admin_login_screen.dart';
import 'features/audit_log/audit_log_screen.dart';

class AdminApp extends ConsumerStatefulWidget {
  const AdminApp({super.key});

  @override
  ConsumerState<AdminApp> createState() => _AdminAppState();
}

class _AdminAppState extends ConsumerState<AdminApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = GoRouter(
      initialLocation: '/admin',
      redirect: (context, state) {
        final authState = ref.read(adminAuthProvider);
        final user = authState.value;
        final isLoggingIn = state.matchedLocation == '/login';

        if (user == null && !isLoggingIn) return '/login';
        if (user != null && isLoggingIn) return '/admin';
        return null;
      },
      routes: [
        GoRoute(path: '/login', builder: (_, __) => const AdminLoginScreen()),
        ShellRoute(
          builder: (context, state, child) => AdminShell(child: child),
          routes: [
            GoRoute(path: '/admin', builder: (_, __) => const DashboardScreen()),      
            GoRoute(path: '/admin/users', builder: (_, __) => const UsersScreen()),    
            GoRoute(path: '/admin/notes', builder: (_, __) => const AdminNotesScreen()),
            GoRoute(path: '/admin/moderation', builder: (_, __) => const ModerationScreen()),
            GoRoute(path: '/admin/analytics', builder: (_, __) => const AnalyticsScreen()),
            GoRoute(path: '/admin/rewards', builder: (_, __) => const RewardsMgrScreen()),
            GoRoute(path: '/admin/notifications', builder: (_, __) => const NotificationsMgrScreen()),
            GoRoute(path: '/admin/support', builder: (_, __) => const SupportScreen()),
            GoRoute(path: '/admin/config', builder: (_, __) => const ConfigScreen()),
            GoRoute(path: '/admin/audit', builder: (_, __) => const AuditLogScreen()),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listen to auth changes to trigger router redirects
    ref.listen(adminAuthProvider, (_, next) {
      _router.refresh();
    });

    final authState = ref.watch(adminAuthProvider);

    return MaterialApp.router(
      title: 'NotesNet Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
        ),
      ),
      themeMode: ThemeMode.light,
      routerConfig: _router,
      builder: (context, child) {
        if (child == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        return authState.when(
          loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (e, _) => Scaffold(body: Center(child: Text('Initialization Error: $e'))),
          data: (_) => child,
        );
      },
    );
  }
}
