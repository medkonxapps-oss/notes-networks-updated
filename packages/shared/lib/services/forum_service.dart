import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/forum.dart';

class ForumService {
  final SupabaseClient _client;
  ForumService(this._client);

  Future<List<ForumQuestion>> getQuestions({String? subject, String? query, String? userId}) async {
    if (query != null && query.isNotEmpty) {
      try {
        final data = await _client.rpc('search_forum_fuzzy', params: {
          'p_query': query,
          'p_subject': (subject == null || subject == 'All') ? null : subject,
        });
        
        if ((data as List).isEmpty) return [];
        
        final ids = data.map((e) => e['id']).toList();
        var fullDataQuery = _client
            .from('forum_questions')
            .select('*, users!user_id(id, full_name, avatar_url, is_verified_creator)')
            .inFilter('id', ids);
            
        if (userId != null) {
          fullDataQuery = fullDataQuery.eq('user_id', userId);
        }

        final fullData = await fullDataQuery;
            
        final mappedData = { for (var e in fullData) e['id'] : e };
        final orderedData = ids.map((id) => mappedData[id]).where((e) => e != null).toList();
        
        return (orderedData as List).map((e) => ForumQuestion.fromJson(e)).toList();
      } catch (e) {
        print('Fuzzy search failed, falling back to FTS: $e');
      }
    }

    var q = _client
        .from('forum_questions')
        .select('*, users!user_id(id, full_name, avatar_url, is_verified_creator)')
        .isFilter('deleted_at', null);

    if (subject != null && subject != 'All') {
      q = q.eq('subject', subject);
    }

    if (userId != null) {
      q = q.eq('user_id', userId);
    }

    if (query != null && query.isNotEmpty) {
      q = q.textSearch('fts', query);
    }

    final data = await q.order('created_at', ascending: false);
    return (data as List).map((e) => ForumQuestion.fromJson(e)).toList();
  }

  Future<ForumQuestion?> getQuestionById(String id) async {
    final data = await _client
        .from('forum_questions')
        .select('*, users!user_id(id, full_name, avatar_url, is_verified_creator)')
        .eq('id', id)
        .maybeSingle();
    if (data == null) return null;
    return ForumQuestion.fromJson(data);
  }

  Future<String> createQuestion(String title, String content, String subject) async {
    final uid = _client.auth.currentUser!.id;
    final data = await _client.from('forum_questions').insert({
      'user_id': uid,
      'title': title,
      'content': content,
      'subject': subject,
    }).select('id').single();
    return data['id'];
  }

  Future<void> updateQuestion(String id, String title, String content, String subject) async {
    await _client.from('forum_questions').update({
      'title': title,
      'content': content,
      'subject': subject,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id).eq('user_id', _client.auth.currentUser!.id);
  }

  Future<void> toggleClosed(String id, bool isClosed) async {
    await _client.from('forum_questions').update({
      'is_closed': isClosed,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id).eq('user_id', _client.auth.currentUser!.id);
  }

  Future<void> deleteQuestion(String id) async {
    await _client.from('forum_questions').update({
      'deleted_at': DateTime.now().toIso8601String(),
    }).eq('id', id).eq('user_id', _client.auth.currentUser!.id);
  }

  Future<List<ForumAnswer>> getAnswers(String questionId) async {
    final data = await _client
        .from('forum_answers')
        .select('*, users!user_id(id, full_name, avatar_url, is_verified_creator)')
        .eq('question_id', questionId)
        .isFilter('deleted_at', null)
        .order('created_at', ascending: true);
    return (data as List).map((e) => ForumAnswer.fromJson(e)).toList();
  }

  Future<void> createAnswer(String questionId, String content, {String? parentId}) async {
    final uid = _client.auth.currentUser!.id;
    await _client.from('forum_answers').insert({
      'question_id': questionId,
      'user_id': uid,
      'content': content,
      'parent_id': parentId,
    });
  }

  Future<void> updateAnswer(String id, String content) async {
    await _client.from('forum_answers').update({
      'content': content,
    }).eq('id', id).eq('user_id', _client.auth.currentUser!.id);
  }

  Future<void> deleteAnswer(String id) async {
    await _client.from('forum_answers').update({
      'deleted_at': DateTime.now().toIso8601String(),
    }).eq('id', id).eq('user_id', _client.auth.currentUser!.id);
  }

  Future<void> incrementViews(String id) async {
    try {
      await _client.rpc('increment_forum_views', params: {'p_question_id': id});
    } catch (_) {
      // Fallback or ignore
    }
  }
}
