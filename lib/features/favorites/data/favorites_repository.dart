import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/api_exception.dart';
import '../models/favorite.dart';

abstract interface class FavoritesRepository {
  Future<List<Favorite>> fetchFavorites(String userId);
  Future<Favorite> add(Favorite favorite);
  Future<void> remove(String userId, String eventId);
}

class SupabaseFavoritesRepository implements FavoritesRepository {
  SupabaseFavoritesRepository(this._client);
  final SupabaseClient _client;
  static const _columns =
      'user_id,event_id,title,image_url,starts_at,location,category,saved_at';

  void _requireUser(String userId) {
    final session = _client.auth.currentSession;
    if (session == null || session.isExpired || session.user.id != userId) {
      throw const ApiException(
        'Oturumunuz geçersizleşti. Lütfen tekrar giriş yapın.',
        statusCode: 401,
      );
    }
  }

  Favorite _parse(Map<String, Object?> json, String userId) {
    final favorite = Favorite.fromJson(json);
    if (favorite.userId != userId) {
      throw const ApiException('Favori yanıtı hesabınızla eşleşmiyor.');
    }
    return favorite;
  }

  @override
  Future<List<Favorite>> fetchFavorites(String userId) => _perform(() async {
    _requireUser(userId);
    final rows = await _client
        .from('favorites')
        .select(_columns)
        .eq('user_id', userId)
        .order('saved_at', ascending: false, nullsFirst: false);
    return rows.map((row) => _parse(row, userId)).toList();
  });

  @override
  Future<Favorite> add(Favorite favorite) => _perform(() async {
    _requireUser(favorite.userId);
    try {
      final row = await _client
          .from('favorites')
          .insert(favorite.toInsertJson())
          .select(_columns)
          .single();
      return _parse(row, favorite.userId);
    } on PostgrestException catch (error) {
      if (error.code != '23505') rethrow;
      // Another device may already have inserted the same primary key.
      _requireUser(favorite.userId);
      final row = await _client
          .from('favorites')
          .select(_columns)
          .eq('user_id', favorite.userId)
          .eq('event_id', favorite.eventId)
          .single();
      return _parse(row, favorite.userId);
    }
  });

  @override
  Future<void> remove(String userId, String eventId) => _perform(() async {
    _requireUser(userId);
    await _client
        .from('favorites')
        .delete()
        .eq('user_id', userId)
        .eq('event_id', eventId);
    _requireUser(userId);
    final remaining = await _client
        .from('favorites')
        .select('event_id')
        .eq('user_id', userId)
        .eq('event_id', eventId)
        .maybeSingle();
    if (remaining != null) {
      throw const ApiException('Favori kaldırılamadı. Lütfen tekrar deneyin.');
    }
  });

  Future<T> _perform<T>(Future<T> Function() operation) async {
    try {
      return await operation().timeout(const Duration(seconds: 20));
    } on PostgrestException catch (error) {
      if (error.code == 'PGRST301' ||
          error.code == 'PGRST303' ||
          error.code == '42501') {
        throw const ApiException(
          'Favorilere erişilemedi. Hesabınızı kontrol edip tekrar giriş yapın.',
          statusCode: 401,
        );
      }
      throw const ApiException(
        'Favori işlemi tamamlanamadı. Lütfen tekrar deneyin.',
      );
    } on AuthException {
      throw const ApiException(
        'Oturumunuz geçersizleşti. Lütfen tekrar giriş yapın.',
        statusCode: 401,
      );
    } on TimeoutException {
      throw const ApiException(
        'Favori isteği zaman aşımına uğradı. Sonucu kontrol etmek için listeyi yenileyin.',
      );
    } on http.ClientException {
      throw const ApiException(
        'Bağlantı kurulamadı. İnternet bağlantınızı kontrol edin.',
      );
    } on FormatException {
      throw const ApiException(
        'Favori verileri okunamadı. Lütfen tekrar deneyin.',
      );
    }
  }
}
