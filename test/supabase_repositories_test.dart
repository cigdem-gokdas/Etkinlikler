import 'dart:convert';

import 'package:etkinlik_kesif/core/network/api_exception.dart';
import 'package:etkinlik_kesif/features/auth/data/auth_repository.dart';
import 'package:etkinlik_kesif/features/favorites/data/favorites_repository.dart';
import 'package:etkinlik_kesif/features/favorites/models/favorite.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'helpers/account_fakes.dart';

Map<String, Object?> sessionJson(String id) => {
  // Synthetic transport data only. No real credential is used by these tests.
  'access_token': 'test-access-token', 'refresh_token': 'test-refresh-token',
  'token_type': 'bearer', 'expires_in': 3600,
  'user': {
    'id': id,
    'email': 'test@example.com',
    'aud': 'authenticated',
    'app_metadata': <String, Object?>{},
    'user_metadata': <String, Object?>{},
    'created_at': '2026-10-24T10:00:00Z',
  },
};

SupabaseClient testClient(
  Future<http.Response> Function(http.Request) handler,
) {
  final client = SupabaseClient(
    'https://example.supabase.co',
    'test-publishable-key',
    httpClient: MockClient((request) async {
      final response = await handler(request);
      return http.Response.bytes(
        response.bodyBytes,
        response.statusCode,
        headers: response.headers,
        request: request,
      );
    }),
    authOptions: AuthClientOptions(
      autoRefreshToken: false,
      pkceAsyncStorage: MemoryPkceStorage(),
    ),
  );
  addTearDown(client.dispose);
  return client;
}

http.Response jsonResponse(Object? body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  test(
    'SDK kod gönderirken yeni hesap oluşturmayı açar; oturum oluşturmaz',
    () async {
      final client = testClient((request) async {
        expect(request.url.path, '/auth/v1/otp');
        final json = jsonDecode(request.body) as Map<String, Object?>;
        expect(json['create_user'], isTrue);
        expect(json['email'], 'test@example.com');
        return jsonResponse({});
      });
      final repository = SupabaseAuthRepository(client);
      await repository.sendCode('test@example.com');
      expect(repository.currentUser, isNull);
    },
  );

  test(
    'SDK verifyOTP email tipiyle gerçek Session oluşumunu kontrol eder',
    () async {
      final client = testClient((request) async {
        expect(request.url.path, '/auth/v1/verify');
        expect(
          (jsonDecode(request.body) as Map<String, Object?>)['type'],
          'email',
        );
        return jsonResponse(sessionJson(userA.id));
      });
      final repository = SupabaseAuthRepository(client);
      final user = await repository.verifyCode('test@example.com', '123456');
      expect(client.auth.currentSession, isNotNull);
      expect(user.id, userA.id);
      expect(repository.currentUser?.id, userA.id);
    },
  );

  test('verify yanıtında Session yoksa başarılı giriş sayılmaz', () async {
    final client = testClient(
      (_) async => jsonResponse({'user': sessionJson(userA.id)['user']}),
    );
    await expectLater(
      SupabaseAuthRepository(client).verifyCode('test@example.com', '123456'),
      throwsA(isA<ApiException>()),
    );
    expect(client.auth.currentSession, isNull);
  });

  test(
    'sekiz haneli sentetik OTP baştaki sıfırlarla SDK isteğine aynen gider',
    () async {
      final client = testClient((request) async {
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body['token'], '00123456');
        expect(body['type'], 'email');
        return jsonResponse(sessionJson(userA.id));
      });
      await SupabaseAuthRepository(client)
          .verifyCode('test@example.com', '00123456');
    },
  );

  test(
    'DELETE başarılı görünse bile kayıt duruyorsa sahte başarı verilmez',
    () async {
      final client = testClient(
        (request) async => request.method == 'DELETE'
            ? http.Response('', 204)
            : jsonResponse([
                {'event_id': 'evt-012'},
              ]),
      );
      await client.auth.setInitialSession(jsonEncode(sessionJson(userA.id)));
      await expectLater(
        SupabaseFavoritesRepository(client).remove(userA.id, 'evt-012'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('kaldırılamadı'),
          ),
        ),
      );
    },
  );

  test('SDK signOut çağrısı sessionı temizler', () async {
    final client = testClient((request) async {
      expect(request.url.path, '/auth/v1/logout');
      return http.Response('', 204);
    });
    await client.auth.setInitialSession(jsonEncode(sessionJson(userA.id)));
    final repository = SupabaseAuthRepository(client);
    await repository.signOut();
    expect(repository.currentUser, isNull);
    expect(client.auth.currentSession, isNull);
  });

  for (final entry in {
    'otp_expired': 'Kod hatalı veya süresi dolmuş',
    'over_email_send_rate_limit': 'Çok fazla istek',
    'email_address_not_authorized': 'gönderime izin vermiyor',
    'unexpected_failure': 'e-posta gönderimi',
    'session_expired': 'tekrar giriş',
  }.entries) {
    test('auth hata kodu güvenli Türkçe mesaja çevrilir: ${entry.key}', () {
      final message = authErrorMessage(
        AuthException('test-only-sensitive-detail', code: entry.key),
      );
      expect(message, contains(entry.value));
      expect(message, isNot(contains('test-only-sensitive-detail')));
    });
  }

  test(
    'anon veya başka kullanıcı kimliğiyle favori isteği gönderilmez',
    () async {
      var requests = 0;
      final client = testClient((_) async {
        requests++;
        return jsonResponse([]);
      });
      final repository = SupabaseFavoritesRepository(client);
      await expectLater(
        repository.fetchFavorites(userA.id),
        throwsA(isA<ApiException>()),
      );
      await client.auth.setInitialSession(jsonEncode(sessionJson(userA.id)));
      await expectLater(
        repository.fetchFavorites(userB.id),
        throwsA(isA<ApiException>()),
      );
      expect(requests, 0);
    },
  );

  test('favori SELECT kullanıcı filtresi ve saved_at DESC içerir', () async {
    final client = testClient((request) async {
      expect(request.url.path, '/rest/v1/favorites');
      expect(request.url.queryParameters['user_id'], 'eq.${userA.id}');
      expect(request.url.queryParameters['order'], 'saved_at.desc.nullslast');
      return jsonResponse([
        {
          ...savedFavorite(userA.id).toInsertJson(),
          'saved_at': '2026-10-24T10:00:00Z',
        },
      ]);
    });
    await client.auth.setInitialSession(jsonEncode(sessionJson(userA.id)));
    final rows = await SupabaseFavoritesRepository(client)
        .fetchFavorites(userA.id);
    expect(rows.single.userId, userA.id);
  });

  test('favori INSERT yalnızca mevcut kolonları gönderir; saved_at sunucuda oluşur', () async {
    final client = testClient((request) async {
      expect(request.method, 'POST');
      final body = jsonDecode(request.body) as Map<String, Object?>;
      expect(body.keys.toSet(), {
        'user_id',
        'event_id',
        'title',
        'image_url',
        'starts_at',
        'location',
        'category',
      });
      expect(body.containsKey('saved_at'), isFalse);
      expect(body['user_id'], userA.id);
      return jsonResponse({...body, 'saved_at': '2026-10-24T10:00:00Z'}, 201);
    });
    await client.auth.setInitialSession(jsonEncode(sessionJson(userA.id)));
    final result = await SupabaseFavoritesRepository(client)
        .add(savedFavorite(userA.id));
    expect(result.savedAt, DateTime.utc(2026, 10, 24, 10));
  });

  test(
    'favori DELETE kullanıcı ve event_id filtrelerini birlikte kullanır',
    () async {
      final client = testClient((request) async {
        expect(request.method, anyOf('DELETE', 'GET'));
        expect(request.url.queryParameters['user_id'], 'eq.${userA.id}');
        expect(request.url.queryParameters['event_id'], 'eq.evt-012');
        return request.method == 'DELETE'
            ? http.Response('', 204)
            : jsonResponse([]);
      });
      await client.auth.setInitialSession(jsonEncode(sessionJson(userA.id)));
      await SupabaseFavoritesRepository(client).remove(userA.id, 'evt-012');
    },
  );

  test('PRIMARY KEY çakışması UPDATE yerine mevcut kaydı okur', () async {
    final methods = <String>[];
    final client = testClient((request) async {
      methods.add(request.method);
      if (request.method == 'POST') {
        return jsonResponse({'code': '23505', 'message': 'duplicate'}, 409);
      }
      expect(request.url.queryParameters['event_id'], 'eq.evt-012');
      return jsonResponse({
        ...savedFavorite(userA.id).toInsertJson(),
        'saved_at': '2026-10-24T10:00:00Z',
      });
    });
    await client.auth.setInitialSession(jsonEncode(sessionJson(userA.id)));
    final favorite = await SupabaseFavoritesRepository(client)
        .add(savedFavorite(userA.id));
    expect(favorite.eventId, 'evt-012');
    expect(methods, ['POST', 'GET']);
  });

  test('RLS/oturum hatası sahte boş listeye dönüştürülmez', () async {
    final client = testClient(
      (_) async => jsonResponse({'code': '42501', 'message': 'denied'}, 403),
    );
    await client.auth.setInitialSession(jsonEncode(sessionJson(userA.id)));
    await expectLater(
      SupabaseFavoritesRepository(client).fetchFavorites(userA.id),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)),
    );
  });

  test('favori nullable alanları ve gerçek API image_url kaydı korunur', () {
    final favorite = Favorite.fromJson({
      'user_id': userA.id,
      'event_id': 'evt-007',
      'title': 'Test',
      'image_url': null,
      'starts_at': null,
      'location': null,
      'category': null,
      'saved_at': null,
    });
    expect(favorite.imageUrl, isNull);
    expect(favorite.startsAt, isNull);
    expect(favorite.savedAt, isNull);
  });
}

class MemoryPkceStorage extends GotrueAsyncStorage {
  final _values = <String, String>{};
  @override
  Future<String?> getItem({required String key}) async => _values[key];
  @override
  Future<void> setItem({required String key, required String value}) async {
    _values[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    _values.remove(key);
  }
}
