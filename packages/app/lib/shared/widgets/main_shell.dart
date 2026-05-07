import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:design_system/design_system.dart';
import '../providers/providers.dart';

class MainShell extends ConsumerStatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  DateTime? _lastBackPress;
  final List<int> _history = [];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/explore')) return 1;
    if (location.startsWith('/upload')) return 2;
    if (location.startsWith('/notifications')) return 3;
    if (location.startsWith('/profile')) return 4;
    return 0;
  }

  void _onTap(int i, int currentIdx) {
    final location = GoRouterState.of(context).uri.path;
    final isBaseRoute = location == '/home' || location == '/explore' || 
                        location == '/upload' ||
                        location == '/notifications' || location == '/profile/me';

    if (i == currentIdx && isBaseRoute) return;
    
    // Add to history for back navigation
    _history.remove(i); 
    _history.add(currentIdx);
    
    switch (i) {
      case 0: context.go('/home'); break;
      case 1: context.go('/explore'); break;
      case 2: context.go('/upload'); break;
      case 3: context.go('/notifications'); break;
      case 4: context.go('/profile/me'); break;
    }
  }

  Future<bool> _onWillPop(BuildContext context, int currentIdx) async {
    final router = GoRouter.of(context);
    
    // 1. If internal router can pop (e.g. nested sub-routes), let it pop
    if (router.canPop()) {
      router.pop();
      return false;
    }

    // 2. If we are not on Home, go back to Home
    if (currentIdx != 0) {
      _onTap(0, currentIdx);
      return false;
    }

    // 3. If we ARE on Home - double-tap back to exit
    final now = DateTime.now();
    if (_lastBackPress == null ||
        now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
      _lastBackPress = now;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Press back again to exit'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }
    
    await SystemNavigator.pop();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentUserProfileProvider);

    // Treat loading the same as data(null) — show the shell immediately.
    // This prevents an infinite spinner when the Supabase realtime stream
    // is slow to emit its first event.
    final profile = profileAsync.valueOrNull;
    final isLoading = profileAsync.isLoading;

    if (profileAsync.hasError) {
      return Scaffold(body: Center(child: Text('Error: ${profileAsync.error}')));
    }

    // Redirect pending teachers once profile is available
    if (!isLoading && profile != null && profile.role == 'teacher' && profile.teacherStatus != 'approved') {
      Future.microtask(() {
        if (context.mounted) {
          context.go('/auth/teacher-pending');
        }
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final idx = _currentIndex(context);
    final unreadAsync = ref.watch(unreadNotifCountProvider);
    final unread = idx == 3 ? 0 : (unreadAsync.value ?? 0);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isDesktop = MediaQuery.of(context).size.width > 800;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _onWillPop(context, idx);
      },
      child: Scaffold(
        body: isDesktop
            ? Row(
                children: [
                  buildNavRail(idx, unread, isDark, theme),
                  VerticalDivider(thickness: 1, width: 1, color: isDark ? AppColors.borderDark : AppColors.border),
                  Expanded(child: widget.child),
                ],
              )
            : widget.child,
        bottomNavigationBar: isDesktop ? null : buildBottomNav(idx, unread, isDark, theme),
      ),
    );
  }

  Widget buildBottomNav(int idx, int unread, bool isDark, ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.bottomNavigationBarTheme.backgroundColor,
        border: Border(top: BorderSide(color: isDark ? Colors.grey.withValues(alpha: 0.2) : AppColors.border)),
      ),
      child: BottomNavigationBar(
        currentIndex: idx,
        onTap: (i) => _onTap(i, idx),
        selectedItemColor: AppColors.primary,
        unselectedItemColor: theme.bottomNavigationBarTheme.unselectedItemColor,
        backgroundColor: Colors.transparent,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.search_rounded),
            activeIcon: Icon(Icons.search_rounded),
            label: 'Explore',
          ),
          BottomNavigationBarItem(
            icon: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryLight]),
                borderRadius: AppRadius.md,
              ),
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
            ),
            label: 'Upload',
          ),
          BottomNavigationBarItem(
            icon: Stack(
              children: [
                const Icon(Icons.notifications_outlined),
                if (unread > 0)
                  Positioned(
                    right: 0, top: 0,
                    child: Container(
                      width: 16, height: 16,
                      decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
                      child: Center(
                        child: Text(
                          unread > 9 ? '9+' : '$unread',
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            activeIcon: const Icon(Icons.notifications_rounded),
            label: 'Notifs',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            activeIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget buildNavRail(int idx, int unread, bool isDark, ThemeData theme) {
    return NavigationRail(
      selectedIndex: idx,
      onDestinationSelected: (i) => _onTap(i, idx),
      labelType: NavigationRailLabelType.all,
      selectedLabelTextStyle: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary),
      unselectedLabelTextStyle: TextStyle(fontWeight: FontWeight.w500, color: isDark ? AppColors.textMutedDark : AppColors.textMuted),
      selectedIconTheme: const IconThemeData(color: AppColors.primary),
      unselectedIconTheme: IconThemeData(color: isDark ? AppColors.textMutedDark : AppColors.textMuted),
      backgroundColor: theme.scaffoldBackgroundColor,
      useIndicator: true,
      indicatorColor: AppColors.primary.withValues(alpha: 0.1),
      destinations: [
        const NavigationRailDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: Text('Home')),
        const NavigationRailDestination(icon: Icon(Icons.search_rounded), selectedIcon: Icon(Icons.search_rounded), label: Text('Explore')),
        NavigationRailDestination(
          icon: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryLight]), borderRadius: AppRadius.md),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
          ),
          label: const Text('Upload'),
        ),
        NavigationRailDestination(
          icon: Stack(
            children: [
              const Icon(Icons.notifications_outlined),
              if (unread > 0)
                Positioned(
                  right: -2, top: -2,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
                    child: Center(child: Text(unread > 9 ? '9+' : '$unread', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold))),
                  ),
                ),
            ],
          ),
          selectedIcon: const Icon(Icons.notifications_rounded),
          label: const Text('Notifs'),
        ),
        const NavigationRailDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: Text('Profile')),
      ],
    );
  }
}
