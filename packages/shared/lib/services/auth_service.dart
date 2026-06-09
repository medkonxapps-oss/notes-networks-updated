import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user.dart';

class AuthService {
  final SupabaseClient _client;
  AuthService(this._client);

  User? get currentUser => _client.auth.currentUser;
  bool get isLoggedIn => currentUser != null;

  Stream<AuthState> get onAuthStateChange =>
      _client.auth.onAuthStateChange;

  // Sanitize username: only allow alphanumeric, underscore, hyphen
  static String _sanitizeUsername(String raw) {
    return raw
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_\-]'), '')
        .trim();
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String username,
    required String fullName,
    String? phone,
    String? institutionName,
    required String board,
    required String classLevel,
    String role = 'student',
    String? linkedinUrl,
    String? idCardUrl,
    List<String>? subjects,
  }) async {
    final sanitizedUsername = _sanitizeUsername(username);
    if (sanitizedUsername.length < 3) {
      throw const AuthException('Username must be at least 3 valid characters (letters, numbers, _, -)');
    }

    return await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'username': sanitizedUsername,
        'full_name': fullName,
        'phone': phone,
        'institution_name': institutionName,
        'board': board,
        'class_level': classLevel,
        'role': role,
        'linkedin_url': linkedinUrl,
        'id_card_url': idCardUrl,
        'subjects': subjects,
      },
      emailRedirectTo: 'io.notesnet.app://login-callback',
    );
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    
    // Check teacher status and account status
    if (response.user != null) {
      final userData = await _client
          .from('users')
          .select('role, teacher_status, is_active, deleted_at')
          .eq('id', response.user!.id)
          .single();
          
      if (userData['is_active'] == false || userData['deleted_at'] != null) {
        await _client.auth.signOut();
        throw const AuthException(
          'Your account has been deactivated or deleted. Please contact support.',
          statusCode: '403',
        );
      }

      if (userData['role'] == 'teacher' && userData['teacher_status'] != 'approved') {
        await _client.auth.signOut();
        throw const AuthException(
          'Your teacher account is pending verification by admin.',
          statusCode: '403',
        );
      }
    }
    
    // Reset failed login attempts on successful login
    if (response.user != null) {
      try {
        await _client.from('users').update({
          'failed_login_attempts': 0,
          'last_failed_login_at': null,
        }).eq('id', response.user!.id);
      } catch (_) {} // Non-critical
    }

    return response;
  }

  Future<void> signOut() async => await _client.auth.signOut();

  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(
      email,
      redirectTo: 'notesnet://reset-password',
    );
  }

  Future<void> updatePassword(String newPassword) async {
    await _client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  Future<UserProfile?> getCurrentUserProfile() async {
    final uid = currentUser?.id;
    if (uid == null) return null;
    try {
      final data = await _client
          .from('users')
          .select()
          .eq('id', uid)
          .maybeSingle();
      if (data == null) return null;
      return UserProfile.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  Future<void> updateProfile(String userId, Map<String, dynamic> updates) async {
    await _client
        .from('users')
        .update({...updates, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', userId);
  }

  Future<String?> uploadAvatar(String userId, List<int> bytes) async {
    final key = '$userId/avatar.jpg';
    await _client.storage.from('avatars').uploadBinary(
      key, Uint8List.fromList(bytes),
      fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
    );
    final url = '${_client.storage.from('avatars').getPublicUrl(key)}?t=${DateTime.now().millisecondsSinceEpoch}';
    await _client.from('users')
        .update({'avatar_url': url}).eq('id', userId);
    return url;
  }

  Future<String> uploadIdCard(List<int> bytes, String extension) async {
    // Generate a unique filename using timestamp and random string
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (1000 + (DateTime.now().microsecond % 9000)).toString();
    final key = 'incoming/$timestamp-$random.$extension';
    
    await _client.storage.from('id-cards').uploadBinary(
      key, Uint8List.fromList(bytes),
      fileOptions: FileOptions(contentType: 'image/$extension', upsert: true),
    );
    
    // Return the key (path) so we can generate signed URLs later
    return key;
  }
}
