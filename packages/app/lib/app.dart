import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'shared/providers/providers.dart';
import 'shared/providers/notification_provider.dart';

class NotesNetApp extends ConsumerStatefulWidget {
  const NotesNetApp({super.key});

  @override
  ConsumerState<NotesNetApp> createState() => _NotesNetAppState();
}

class _NotesNetAppState extends ConsumerState<NotesNetApp> {
  @override
  void initState() {
    super.initState();
    // Re-check notifications on app start if session exists
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = ref.read(supabaseClientProvider).auth.currentSession;
      if (session != null) {
        ref.read(pushNotificationProvider.notifier).init();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeProvider);
    final messengerKey = ref.watch(messengerKeyProvider);
    
    // Activate real-time listeners at the root
    ref.watch(noteStatsSyncProvider);

    // Listen for login to trigger notification permission
    ref.listen(authStateProvider, (previous, next) {
      final prevSession = previous?.value?.session;
      final nextSession = next.value?.session;

      // User just logged in → init notifications
      if (nextSession != null && prevSession == null) {
        ref.read(pushNotificationProvider.notifier).init();
      }

      // Session signed out or expired → redirect to login
      if (nextSession == null && prevSession != null) {
        // Clear sensitive cached state
        ref.invalidate(feedProvider);
        ref.invalidate(savedNotesProvider);
        ref.invalidate(likedNotesProvider);
        // Router's redirect will handle navigation to /auth/login
      }
    });

    return MaterialApp.router(
      title: 'NotesNet',
      scaffoldMessengerKey: messengerKey,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
