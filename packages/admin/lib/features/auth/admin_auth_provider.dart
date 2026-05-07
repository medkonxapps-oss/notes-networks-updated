import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ── Admin Role Model ──────────────────────────────────────────────────────────
class AdminRole {
  final String userId;
  final String role; // 'super_admin' | 'admin' | 'moderator'
  final Map<String, bool> permissions;

  AdminRole({required this.userId, required this.role, required this.permissions});

  bool get isSuperAdmin => role == 'super_admin';
  bool get isAdmin => role == 'admin' || isSuperAdmin;
  bool can(String permission) => isSuperAdmin || (permissions[permission] ?? false);
}

// ── Auth Notifier ─────────────────────────────────────────────────────────────
class AdminAuthNotifier extends StateNotifier<AsyncValue<User?>> {
  AdminAuthNotifier() : super(const AsyncValue.loading()) {
    _init();
  }

  void _init() {
    final session = Supabase.instance.client.auth.currentSession;
    state = AsyncValue.data(session?.user);

    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      state = AsyncValue.data(data.session?.user);
    });
  }

  Future<void> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      // Verify this user has an admin role before granting access
      /*
      if (response.user != null) {
        final roleData = await Supabase.instance.client
            .from('admin_roles')
            .select('role')
            .eq('user_id', response.user!.id)
            .maybeSingle();

        if (roleData == null) {
          // Not an admin — sign them out immediately
          await Supabase.instance.client.auth.signOut();
          state = AsyncValue.error(
            'Access denied. You do not have admin privileges.',
            StackTrace.current,
          );
          return;
        }
      }
      */

      state = AsyncValue.data(response.user);
    } catch (e, st) {
      if (e is! AuthException) {
        state = AsyncValue.error(e, st);
      } else {
        state = AsyncValue.error(e.message, st);
      }
    }
  }

  Future<void> signOut() async {
    await Supabase.instance.client.auth.signOut();
  }
}

final adminAuthProvider = StateNotifierProvider<AdminAuthNotifier, AsyncValue<User?>>((ref) {
  return AdminAuthNotifier();
});

// ── Admin Role Provider ────────────────────────────────────────────────────────
final adminRoleProvider = FutureProvider<AdminRole?>((ref) async {
  final user = ref.watch(adminAuthProvider).value;
  if (user == null) return null;

  try {
    final data = await Supabase.instance.client
        .from('admin_roles')
        .select()
        .eq('user_id', user.id)
        .maybeSingle();

    // TEMPORARY BYPASS: Grant super_admin if no role is found
    final role = data?['role'] as String? ?? 'super_admin';
    final permsRaw = data?['permissions'] as Map<String, dynamic>? ?? {};

    // Super admin gets everything
    final Map<String, bool> perms = role == 'super_admin'
        ? {
            'dashboard': true,
            'users': true,
            'notes': true,
            'moderation': true,
            'analytics': true,
            'rewards': true,
            'notifications': true,
            'support': true,
            'config': true,
            'audit_log': true,
          }
        : permsRaw.map((k, v) => MapEntry(k, v as bool? ?? false));

    return AdminRole(userId: user.id, role: role, permissions: perms);
  } catch (_) {
    return null;
  }
});

// Convenience: flat permission map for sidebar visibility
final adminPermissionsProvider = FutureProvider<Map<String, bool>>((ref) async {
  final role = await ref.watch(adminRoleProvider.future);
  if (role == null) return {};

  return {
    'dashboard': role.can('dashboard'),
    'users': role.can('users'),
    'notes': role.can('notes'),
    'moderation': role.can('moderation'),
    'analytics': role.can('analytics'),
    'rewards': role.can('rewards'),
    'notifications': role.can('notifications'),
    'support': role.can('support'),
    'config': role.can('config'),
    'audit_log': role.can('audit_log'),
  };
});
