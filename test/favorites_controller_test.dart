import 'dart:async';

import 'package:etkinlik_kesif/core/network/api_exception.dart';
import 'package:etkinlik_kesif/features/favorites/controllers/favorites_controller.dart';
import 'package:etkinlik_kesif/features/favorites/models/favorite.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/account_fakes.dart';
import 'helpers/fixtures.dart';

Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  test('girişsiz favori işlemi ağ çağrısı yapmaz', () async {
    final repository = FakeFavoritesRepository();
    final controller = FavoritesController(repository);
    addTearDown(controller.dispose);
    await controller.toggle(sampleEvent());
    expect(controller.status, FavoritesStatus.signedOut);
    expect(repository.adds, 0);
    expect(repository.fetches, 0);
  });

  test('favoriler loading ve sunucu saved_at sırasıyla listelenir', () async {
    final repository = FakeFavoritesRepository();
    final pending = Completer<List<Favorite>>();
    repository.onFetch = (_) => pending.future;
    final controller = FavoritesController(repository);
    addTearDown(controller.dispose);
    controller.setUser(userA.id);
    expect(controller.status, FavoritesStatus.loading);
    expect(controller.canMutate, isFalse);
    pending.complete([
      savedFavorite(userA.id, eventId: 'old', savedAt: DateTime(2026, 1, 1)),
      savedFavorite(userA.id, eventId: 'new', savedAt: DateTime(2026, 2, 1)),
    ]);
    await settle();
    expect(controller.status, FavoritesStatus.success);
    expect(controller.favorites.first.eventId, 'new');
  });

  test('veritabanı hatası boş liste gibi gösterilmez, retry çalışır', () async {
    final repository = FakeFavoritesRepository()
      ..onFetch = (_) async => throw const ApiException('Sunucu hatası.');
    final controller = FavoritesController(repository);
    addTearDown(controller.dispose);
    controller.setUser(userA.id);
    await settle();
    expect(controller.status, FavoritesStatus.error);
    repository.onFetch = null;
    await controller.load();
    expect(controller.status, FavoritesStatus.success);
    expect(controller.favorites, isEmpty);
  });

  test('favori ekleme/kaldırma sonucuyla ID durumu değişir', () async {
    final repository = FakeFavoritesRepository();
    final controller = FavoritesController(repository);
    addTearDown(controller.dispose);
    controller.setUser(userA.id);
    await settle();
    await controller.toggle(sampleEvent());
    expect(controller.contains('evt-012'), isTrue);
    expect(repository.byUser[userA.id]?.single.eventId, 'evt-012');
    await controller.toggle(sampleEvent());
    expect(controller.contains('evt-012'), isFalse);
    expect(repository.adds, 1);
    expect(repository.removes, 1);
  });

  test('aynı etkinliğe hızlı çift tıklama mükerrer yazma yapmaz', () async {
    final pending = Completer<Favorite>();
    final repository = FakeFavoritesRepository()..onAdd = (_) => pending.future;
    final controller = FavoritesController(repository);
    addTearDown(controller.dispose);
    controller.setUser(userA.id);
    await settle();
    final first = controller.toggle(sampleEvent());
    await controller.toggle(sampleEvent());
    expect(controller.isPending('evt-012'), isTrue);
    expect(controller.contains('evt-012'), isFalse);
    expect(repository.adds, 1);
    pending.complete(savedFavorite(userA.id));
    await first;
    expect(controller.isPending('evt-012'), isFalse);
    expect(controller.contains('evt-012'), isTrue);
  });

  test('başarısız ekleme offline kayıt yapılmış gibi gösterilmez', () async {
    final repository = FakeFavoritesRepository()
      ..onAdd = (_) async => throw const ApiException('Bağlantı yok.');
    final controller = FavoritesController(repository);
    addTearDown(controller.dispose);
    controller.setUser(userA.id);
    await settle();
    await controller.toggle(sampleEvent());
    expect(controller.contains('evt-012'), isFalse);
    expect(controller.errorMessage, 'Bağlantı yok.');
  });

  test('başarısız kaldırma ve yenilemede eski kayıt korunur', () async {
    final repository = FakeFavoritesRepository();
    repository.byUser[userA.id] = [savedFavorite(userA.id)];
    repository.onRemove = (_, _) async =>
        throw const ApiException('Bağlantı yok.');
    final controller = FavoritesController(repository);
    addTearDown(controller.dispose);
    controller.setUser(userA.id);
    await settle();
    await controller.remove('evt-012');
    expect(controller.contains('evt-012'), isTrue);
    repository.onFetch = (_) async => throw const ApiException('Yenilenemedi.');
    await controller.load();
    expect(controller.status, FavoritesStatus.success);
    expect(controller.favorites, hasLength(1));
    expect(controller.errorMessage, 'Yenilenemedi.');
  });

  test('A çıkınca hemen temizlenir; B yüklenir; A tekrar girince kendi kayıtları gelir', () async {
    final repository = FakeFavoritesRepository();
    repository.byUser[userA.id] = [savedFavorite(userA.id)];
    final controller = FavoritesController(repository);
    addTearDown(controller.dispose);
    controller.setUser(userA.id);
    await settle();
    expect(controller.favorites.single.userId, userA.id);
    controller.setUser(null);
    expect(controller.favorites, isEmpty);
    controller.setUser(userB.id);
    expect(controller.favorites, isEmpty);
    await settle();
    expect(controller.favorites, isEmpty);
    controller.setUser(userA.id);
    await settle();
    expect(controller.favorites.single.userId, userA.id);
  });

  test('A’nın gecikmiş liste yanıtı B’ye uygulanmaz', () async {
    final pending = Completer<List<Favorite>>();
    final repository = FakeFavoritesRepository()
      ..onFetch = (id) => id == userA.id ? pending.future : Future.value([]);
    final controller = FavoritesController(repository);
    addTearDown(controller.dispose);
    controller.setUser(userA.id);
    controller.setUser(userB.id);
    await settle();
    pending.complete([savedFavorite(userA.id)]);
    await settle();
    expect(controller.favorites, isEmpty);
    expect(controller.status, FavoritesStatus.success);
  });

  test('A’nın gecikmiş ekleme yanıtı B’nin verisine uygulanmaz', () async {
    final pending = Completer<Favorite>();
    final repository = FakeFavoritesRepository()..onAdd = (_) => pending.future;
    final controller = FavoritesController(repository);
    addTearDown(controller.dispose);
    controller.setUser(userA.id);
    await settle();
    final request = controller.toggle(sampleEvent());
    controller.setUser(userB.id);
    await settle();
    pending.complete(savedFavorite(userA.id));
    await request;
    expect(controller.favorites, isEmpty);
    expect(controller.isPending('evt-012'), isFalse);
  });

  test('başka hesaba ait repository yanıtı reddedilir', () async {
    final repository = FakeFavoritesRepository()
      ..onFetch = (_) async => [savedFavorite(userB.id)];
    final controller = FavoritesController(repository);
    addTearDown(controller.dispose);
    controller.setUser(userA.id);
    await settle();
    expect(controller.status, FavoritesStatus.error);
    expect(controller.favorites, isEmpty);
  });

  test('geçersiz oturum hatası yeniden giriş seçeneği gerektirir', () async {
    final repository = FakeFavoritesRepository()
      ..onFetch = (_) async =>
          throw const ApiException('Tekrar giriş yapın.', statusCode: 401);
    final controller = FavoritesController(repository);
    addTearDown(controller.dispose);
    controller.setUser(userA.id);
    await settle();
    expect(controller.requiresSignIn, isTrue);
    expect(controller.canMutate, isFalse);
  });

  test(
    'controller yeniden oluşturulunca favorileri repository’den yükler',
    () async {
      final repository = FakeFavoritesRepository();
      final first = FavoritesController(repository)..setUser(userA.id);
      await settle();
      await first.toggle(sampleEvent());
      first.dispose();
      final second = FavoritesController(repository)..setUser(userA.id);
      addTearDown(second.dispose);
      await settle();
      expect(second.contains('evt-012'), isTrue);
      expect(repository.fetches, 2);
    },
  );
}
