import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:design_system/design_system.dart';
import '../../features/auth/admin_auth_provider.dart';

class AdminShell extends ConsumerWidget {
  final Widget child;
  const AdminShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWide = MediaQuery.of(context).size.width > 1024;
    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            const _AdminSidebar(),
            Container(width: 1, color: AppColors.border),
            Expanded(child: child),
          ],
        ),
      );
    }
    // Mobile: drawer
    return Scaffold(
      appBar: AppBar(
        title: const Text('NotesNet Admin'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      drawer: const Drawer(child: _AdminSidebar()),
      body: child,
    );
  }
}

class _AdminSidebar extends ConsumerWidget {
  const _AdminSidebar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final permissionsAsync = ref.watch(adminPermissionsProvider);
    
    const allItems = [
      _SidebarItem(icon: Icons.dashboard_rounded, label: 'Dashboard', route: '/admin', permission: 'dashboard'),
      _SidebarItem(icon: Icons.people_rounded, label: 'Users', route: '/admin/users', permission: 'users'),
      _SidebarItem(icon: Icons.sticky_note_2_rounded, label: 'Notes', route: '/admin/notes', permission: 'notes'),
      _SidebarItem(icon: Icons.gavel_rounded, label: 'Moderation', route: '/admin/moderation', permission: 'moderation'),
      _SidebarItem(icon: Icons.analytics_rounded, label: 'Analytics', route: '/admin/analytics', permission: 'analytics'),
      _SidebarItem(icon: Icons.card_giftcard_rounded, label: 'Rewards', route: '/admin/rewards', permission: 'rewards'),
      _SidebarItem(icon: Icons.campaign_rounded, label: 'Push Notifs', route: '/admin/notifications', permission: 'notifications'),
      _SidebarItem(icon: Icons.support_agent_rounded, label: 'Support', route: '/admin/support', permission: 'support'),
      _SidebarItem(icon: Icons.settings_rounded, label: 'Config', route: '/admin/config', permission: 'config'),
      _SidebarItem(icon: Icons.history_edu_rounded, label: 'Audit Log', route: '/admin/audit', permission: 'audit_log'),
    ];

    return Container(
      width: 240,
      color: AppColors.primary,
      child: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(20),
              child: Row(children: [
                Icon(Icons.sticky_note_2_rounded, color: Colors.white, size: 28),
                SizedBox(width: 10),
                Text('Admin Panel', style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
              ]),
            ),
            const Divider(color: Colors.white24),
            Expanded(
              child: permissionsAsync.when(
                data: (perms) {
                  final items = allItems.where((item) => perms[item.permission] == true).toList();
                  return ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: items.map((item) {
                      final isSelected = location == item.route ||
                          (location.startsWith(item.route) && item.route != '/admin');
                      return ListTile(
                        leading: Icon(item.icon,
                          color: isSelected ? Colors.white : Colors.white60),
                        title: Text(item.label, style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                          fontSize: 14,
                        )),
                        selected: isSelected,
                        selectedTileColor: Colors.white.withValues(alpha: 0.15),
                        shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                        onTap: () => context.go(item.route),
                      );
                    }).toList(),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
                error: (_, __) => const Center(child: Text('Error loading perms', style: TextStyle(color: Colors.white))),
              ),
            ),
            const Divider(color: Colors.white24),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: Colors.white60),
              title: const Text('Logout', style: TextStyle(color: Colors.white70, fontSize: 14)),
              onTap: () => ref.read(adminAuthProvider.notifier).signOut(),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _SidebarItem {
  final IconData icon;
  final String label;
  final String route;
  final String permission;
  const _SidebarItem({required this.icon, required this.label, required this.route, required this.permission});
}
