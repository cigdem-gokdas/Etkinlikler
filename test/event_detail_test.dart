import 'dart:async';
import 'dart:convert';

import 'package:etkinlik_kesif/core/network/api_client.dart';
import 'package:etkinlik_kesif/core/network/api_exception.dart';
import 'package:etkinlik_kesif/features/events/controllers/event_detail_controller.dart';
import 'package:etkinlik_kesif/features/events/data/events_repository.dart';
import 'package:etkinlik_kesif/features/events/models/event.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers/fixtures.dart';
import 'helpers/detail_fixture.dart';

void main() {
  test(
    'gerçek detay endpointi, String ID ve açıklama doğru ayrıştırılır',
    () async {
      final json = detailJson();
      final client = MockClient((request) async {
        expect(request.url.path, '/events/evt-001');
        return http.Response.bytes(utf8.encode(jsonEncode(json)), 200);
      });
      addTearDown(client.close);
      final event = await HttpEventsRepository(ApiClient(client))
          .fetchEvent('evt-001');
      expect(event.id, 'evt-001');
      expect(event.description, json['description']);
      expect(event.imageUrl, json['imageUrl']);
      expect(event.startDate, DateTime.utc(2026, 10, 21, 15));
    },
  );

  test('event ID URL yolu olarak güvenle encode edilir', () async {
    const id = 'evt /?query#fragment';
    final client = MockClient((request) async {
      expect(request.url.pathSegments, ['events', id]);
      expect(request.url.query, isEmpty);
      expect(request.url.fragment, isEmpty);
      return http.Response(
        jsonEncode({...detailJson(), 'id': id}),
        200,
        headers: const {'content-type': 'application/json; charset=utf-8'},
      );
    });
    addTearDown(client.close);
    expect(
      (await HttpEventsRepository(ApiClient(client)).fetchEvent(id)).id,
      id,
    );
  });

  test('404 genel sunucu hatasından ayrılır', () async {
    final client = MockClient((_) async => http.Response('{}', 404));
    addTearDown(client.close);
    await expectLater(
      HttpEventsRepository(ApiClient(client)).fetchEvent('missing'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'status', 404)
            .having((e) => e.message, 'message', contains('bulunamadı')),
      ),
    );
  });

  test('detay isteği aynı ApiClient timeout sınırına uyar', () async {
    final pending = Completer<http.Response>();
    final client = MockClient((_) => pending.future);
    addTearDown(client.close);
    await expectLater(
      HttpEventsRepository(
        ApiClient(client, timeout: const Duration(milliseconds: 10)),
      ).fetchEvent('evt-001'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          contains('zaman aşımına'),
        ),
      ),
    );
    pending.complete(http.Response('{}', 200));
  });

  test('detay bağlantı hatası kullanıcı mesajına çevrilir', () async {
    final client = MockClient(
      (_) async => throw http.ClientException('offline'),
    );
    addTearDown(client.close);
    await expectLater(
      HttpEventsRepository(ApiClient(client)).fetchEvent('evt-001'),
      throwsA(isA<ApiException>()),
    );
  });

  for (final change in <Map<String, Object?>>[
    {'id': 'wrong'},
    {'title': 1},
    {'description': 12},
  ]) {
    test('geçersiz detay alanı kabul edilmez: ${change.keys.single}', () async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({...detailJson(), ...change}),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        ),
      );
      addTearDown(client.close);
      await expectLater(
        HttpEventsRepository(ApiClient(client)).fetchEvent('evt-001'),
        throwsA(isA<ApiException>()),
      );
    });
  }

  test('description, konum ve görsel null olabilir', () {
    final event = Event.fromJson({
      ...detailJson(),
      'description': null,
      'location': null,
      'imageUrl': null,
    });
    expect(event.description, isNull);
    expect(event.location, isNull);
    expect(event.imageUrl, isNull);
  });

  test(
    'bellekteki etkinlik yükleme sırasında korunur, detayla tamamlanır',
    () async {
      final pending = Completer<Event>();
      final repository = StubEventsRepository(() async => samplePage())
        ..detailHandler = (_) => pending.future;
      final snapshot = Event.fromJson({...detailJson(), 'description': null});
      final controller = EventDetailController(
        repository,
        eventId: 'evt-001',
        initialEvent: snapshot,
      );
      addTearDown(controller.dispose);
      final request = controller.load();
      expect(controller.event, same(snapshot));
      expect(controller.status, EventDetailStatus.loading);
      pending.complete(Event.fromJson(detailJson()));
      await request;
      expect(controller.status, EventDetailStatus.success);
      expect(controller.event?.description, isNotEmpty);
    },
  );

  test('detay controller 404 sonrası manuel retry yapabilir', () async {
    final repository = StubEventsRepository(() async => samplePage())
      ..detailHandler = (_) async =>
          throw const ApiException('Etkinlik bulunamadı.', statusCode: 404);
    final controller = EventDetailController(repository, eventId: 'evt-001');
    addTearDown(controller.dispose);
    await controller.load();
    expect(controller.status, EventDetailStatus.notFound);
    repository.detailHandler = (_) async => Event.fromJson(detailJson());
    await controller.load();
    expect(controller.status, EventDetailStatus.success);
    expect(repository.detailCalls, 2);
  });

  for (final fails in [false, true]) {
    test(
      'dispose sonrası ${fails ? 'hatalı' : 'başarılı'} detay sonucu bildirim yapmaz',
      () async {
        final pending = Completer<Event>();
        final repository = StubEventsRepository(() async => samplePage())
          ..detailHandler = (_) => pending.future;
        final controller = EventDetailController(
          repository,
          eventId: 'evt-001',
        );
        var notifications = 0;
        controller.addListener(() => notifications++);
        final request = controller.load();
        await controller.load();
        expect(repository.detailCalls, 1);
        controller.dispose();
        if (fails) {
          pending.completeError(const ApiException('offline'));
        } else {
          pending.complete(Event.fromJson(detailJson()));
        }
        await request;
        expect(notifications, 1);
      },
    );
  }
}
