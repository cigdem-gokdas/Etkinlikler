import 'dart:async';
import 'dart:convert';

import 'package:etkinlik_kesif/core/network/api_client.dart';
import 'package:etkinlik_kesif/core/network/api_exception.dart';
import 'package:etkinlik_kesif/features/events/data/events_repository.dart';
import 'package:etkinlik_kesif/features/events/models/event.dart';
import 'package:etkinlik_kesif/features/events/models/events_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers/fixtures.dart';

void main() {
  test(
    'gerçek API kaydı, metin ID, saat dilimi ve null görsel ayrıştırılır',
    () {
      final page = EventsPage.fromJson(readPageJson());
      expect(page.items, hasLength(16));
      expect(page.page, 1);
      expect(page.limit, 50);
      expect(page.total, 16);
      expect(page.hasMore, isFalse);
      final first = page.items.first;
      expect(first.id, 'evt-012');
      expect(first.title, 'Sky Lab Tanışma Kahvaltısı');
      expect(first.startDate, DateTime.utc(2026, 10, 17, 7));
      expect(first.tags, contains('kahvaltı'));
      expect(
        page.items.singleWhere((event) => event.id == 'evt-007').imageUrl,
        isNull,
      );
      expect(
        page.items.singleWhere((event) => event.id == 'evt-016').tags,
        isEmpty,
      );
      expect(() => page.items.clear(), throwsUnsupportedError);
    },
  );

  test('konum ve görsel eksik veya null olabilir', () {
    final items = readPageJson()['items']! as List<Object?>;
    final json = Map<String, Object?>.from(items.first! as Map<String, Object?>)
      ..remove('location')
      ..remove('imageUrl');
    final event = Event.fromJson(json);
    expect(event.location, isNull);
    expect(event.imageUrl, isNull);
  });

  test(
    'ilk sayfa gerçek endpoint üzerinden istenir ve UTF-8 korunur',
    () async {
      final client = MockClient((request) async {
        expect(
          request.url.toString(),
          'https://mobilab-task-api.vercel.app/events',
        );
        expect(request.method, 'GET');
        return http.Response.bytes(
          utf8.encode(jsonEncode(readPageJson())),
          200,
        );
      });
      addTearDown(client.close);
      final repository = HttpEventsRepository(ApiClient(client));
      final page = await repository.fetchEvents();
      expect(page.items.first.title, 'Sky Lab Tanışma Kahvaltısı');
    },
  );

  for (final status in [404, 429, 503]) {
    test('HTTP $status kullanıcı hatasına çevrilir', () async {
      final client = MockClient((_) async => http.Response('error', status));
      addTearDown(client.close);
      final repository = HttpEventsRepository(ApiClient(client));
      await expectLater(
        repository.fetchEvents(),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', status),
        ),
      );
    });
  }

  test('bağlantı hatası Türkçe hata mesajına çevrilir', () async {
    final client = MockClient(
      (_) async => throw http.ClientException('offline'),
    );
    addTearDown(client.close);
    await expectLater(
      HttpEventsRepository(ApiClient(client)).fetchEvents(),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          contains('İnternet'),
        ),
      ),
    );
  });

  test('yavaş yanıt timeout olur; otomatik yeniden istek atılmaz', () async {
    var calls = 0;
    final pending = Completer<http.Response>();
    final client = MockClient((_) {
      calls += 1;
      return pending.future;
    });
    addTearDown(client.close);
    final repository = HttpEventsRepository(
      ApiClient(client, timeout: const Duration(milliseconds: 10)),
    );
    await expectLater(
      repository.fetchEvents(),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          contains('zaman aşımına'),
        ),
      ),
    );
    expect(calls, 1);
    pending.complete(http.Response('{}', 200));
  });

  for (final body in ['<html>error</html>', '[]', '{}']) {
    test(
      'bozuk JSON veya eksik yanıt alanları hata olarak bildirilir: $body',
      () async {
        final client = MockClient((_) async => http.Response(body, 200));
        addTearDown(client.close);
        await expectLater(
          HttpEventsRepository(ApiClient(client)).fetchEvents(),
          throwsA(isA<ApiException>()),
        );
      },
    );
  }

  test('sayısal ID ve geçersiz tarih sessizce kabul edilmez', () {
    final items = readPageJson()['items']! as List<Object?>;
    final json = Map<String, Object?>.from(
      items.first! as Map<String, Object?>,
    );
    expect(() => Event.fromJson({...json, 'id': 12}), throwsFormatException);
    expect(
      () => Event.fromJson({...json, 'startDate': 'invalid'}),
      throwsFormatException,
    );
  });
}
