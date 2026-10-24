import 'dart:async';

import 'package:etkinlik_kesif/core/network/api_exception.dart';
import 'package:etkinlik_kesif/features/events/controllers/events_controller.dart';
import 'package:etkinlik_kesif/features/events/models/events_page.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fixtures.dart';

void main() {
  test('loading durumundan success durumuna geçer', () async {
    final pending = Completer<EventsPage>();
    final repository = StubEventsRepository(() => pending.future);
    final controller = EventsController(repository);
    addTearDown(controller.dispose);
    final request = controller.load();
    expect(controller.status, EventsStatus.loading);
    pending.complete(samplePage());
    await request;
    expect(controller.status, EventsStatus.success);
    expect(controller.events.single.id, 'evt-012');
  });

  test('başarılı boş yanıt empty durumuna geçer', () async {
    final controller = EventsController(
      StubEventsRepository(() async => samplePage(empty: true)),
    );
    addTearDown(controller.dispose);
    await controller.load();
    expect(controller.status, EventsStatus.empty);
    expect(controller.errorMessage, isNull);
  });

  test('hata sonrasında manuel tekrar deneme başarılı olabilir', () async {
    final repository = StubEventsRepository(
      () async => throw const ApiException('Bağlantı kurulamadı.'),
    );
    final controller = EventsController(repository);
    addTearDown(controller.dispose);
    await controller.load();
    expect(controller.status, EventsStatus.error);
    expect(repository.calls, 1);
    repository.handler = () async => samplePage();
    await controller.load();
    expect(controller.status, EventsStatus.success);
    expect(controller.errorMessage, isNull);
    expect(repository.calls, 2);
  });

  test('yenileme hatasında mevcut liste korunur, sonraki yenilemede hata temizlenir', () async {
    final repository = StubEventsRepository(() async => samplePage());
    final controller = EventsController(repository);
    addTearDown(controller.dispose);
    await controller.load();
    final previous = controller.events;
    final pending = Completer<EventsPage>();
    repository.handler = () => pending.future;
    final request = controller.load();
    expect(controller.isRefreshing, isTrue);
    expect(controller.events, same(previous));
    pending.completeError(const ApiException('Sunucu yanıt veremiyor.'));
    await request;
    expect(controller.status, EventsStatus.success);
    expect(controller.events, same(previous));
    expect(controller.errorMessage, 'Sunucu yanıt veremiyor.');
    expect(controller.isRefreshing, isFalse);
    repository.handler = () async => samplePage(empty: true);
    await controller.load();
    expect(controller.status, EventsStatus.empty);
    expect(controller.errorMessage, isNull);
  });

  test('eşzamanlı çağrılar ek ağ isteği başlatmaz', () async {
    final pending = Completer<EventsPage>();
    final repository = StubEventsRepository(() => pending.future);
    final controller = EventsController(repository);
    addTearDown(controller.dispose);
    final first = controller.load();
    await controller.load();
    expect(repository.calls, 1);
    pending.complete(samplePage());
    await first;
  });

  for (final fail in [false, true]) {
    test(
      'dispose sonrası tamamlanan ${fail ? 'hatalı' : 'başarılı'} istek bildirim yapmaz',
      () async {
        final pending = Completer<EventsPage>();
        final controller = EventsController(
          StubEventsRepository(() => pending.future),
        );
        var notifications = 0;
        controller.addListener(() => notifications += 1);
        final request = controller.load();
        controller.dispose();
        if (fail) {
          pending.completeError(const ApiException('Geç gelen hata'));
        } else {
          pending.complete(samplePage());
        }
        await request;
        expect(notifications, 1);
      },
    );
  }
}
