import 'dart:convert';
import 'dart:io';

import 'package:etkinlik_kesif/core/network/api_client.dart';
import 'package:etkinlik_kesif/core/network/api_exception.dart';
import 'package:etkinlik_kesif/features/events/data/events_repository.dart';
import 'package:etkinlik_kesif/features/events/models/event_categories.dart';
import 'package:etkinlik_kesif/features/events/models/events_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers/fixtures.dart';

Map<String, Object?> categoryJson() =>
    jsonDecode(File('test/fixtures/categories.json').readAsStringSync())
        as Map<String, Object?>;

void main() {
  test('gerçek kategori String listesi ve harf biçimi korunur', () {
    final result = EventCategories.fromJson(categoryJson());
    expect(result.items, [
      'Hackathon',
      'Panel',
      'Seminer',
      'Sosyal',
      'Workshop',
      'Yarışma',
    ]);
    expect(() => result.items.clear(), throwsUnsupportedError);
  });

  for (final value in [
    null,
    'Workshop',
    [1],
    [''],
    [
      {'name': 'Workshop'},
    ],
  ]) {
    test('geçersiz kategori şeması reddedilir: $value', () {
      expect(
        () => EventCategories.fromJson({'items': value}),
        throwsFormatException,
      );
    });
  }

  test(
    'categories gerçek endpointten okunur; bozuk yanıt güvenli hata olur',
    () async {
      var body = categoryJson();
      final client = MockClient((request) async {
        expect(request.url.path, '/categories');
        return http.Response(
          jsonEncode(body),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      addTearDown(client.close);
      final repository = HttpEventsRepository(ApiClient(client));
      expect(await repository.fetchCategories(), contains('Yarışma'));
      body = {
        'items': [12],
      };
      await expectLater(
        repository.fetchCategories(),
        throwsA(isA<ApiException>()),
      );
    },
  );

  test('arama, kategori, online ve sayfa Uri ile Türkçe/boşluk/özel karakterleri encode eder', () async {
    final client = MockClient((request) async {
      expect(request.url.queryParameters, {
        'q': 'Yapay zekâ & ürün',
        'category': 'Yarışma',
        'online': 'false',
        'page': '2',
        'limit': '10',
      });
      expect(request.url.path, '/events');
      expect(request.url.toString(), contains('%C3%A2'));
      return http.Response(
        jsonEncode(readPageJson()),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    addTearDown(client.close);
    await HttpEventsRepository(ApiClient(client)).fetchEvents(
      query: ' Yapay zekâ & ürün ',
      category: 'Yarışma',
      online: false,
      page: 2,
      limit: 10,
    );
  });

  test(
    'Tümü ve boş sorgu için query/category parametresi gönderilmez',
    () async {
      final client = MockClient((request) async {
        expect(request.url.queryParameters, {'page': '1', 'limit': '10'});
        return http.Response(
          jsonEncode(readPageJson()),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      addTearDown(client.close);
      await HttpEventsRepository(ApiClient(client))
          .fetchEvents(query: ' ', page: 1, limit: 10);
    },
  );

  test(
    'gerçek iki sayfa fixture toplamı 16 farklı ID ve son hasMore false',
    () {
      EventsPage read(String file) => EventsPage.fromJson(
        jsonDecode(File('test/fixtures/$file.json').readAsStringSync())
            as Map<String, Object?>,
      );
      final first = read('events_first_page');
      final second = read('events_second_page');
      expect(first.items.length, 10);
      expect(first.hasMore, isTrue);
      expect(second.page, 2);
      expect(second.items.length, 6);
      expect(second.hasMore, isFalse);
      expect(
        {
          ...first.items.map((e) => e.id),
          ...second.items.map((e) => e.id),
        }.length,
        first.total,
      );
    },
  );

  test('geçersiz sayfalama metadata ve istek aralıkları reddedilir', () async {
    for (final override in [
      {'page': 0},
      {'limit': 0},
      {'limit': 51},
      {'total': -1},
    ]) {
      expect(
        () => EventsPage.fromJson({...readPageJson(), ...override}),
        throwsFormatException,
      );
    }
    final client = MockClient((_) async => throw StateError('Ağa çıkılmamalı'));
    addTearDown(client.close);
    final repository = HttpEventsRepository(ApiClient(client));
    await expectLater(
      repository.fetchEvents(page: 0),
      throwsA(isA<ApiException>()),
    );
    await expectLater(
      repository.fetchEvents(limit: 51),
      throwsA(isA<ApiException>()),
    );
  });
}
