import 'dart:async';

import 'package:etkinlik_kesif/features/auth/data/auth_repository.dart';
import 'package:etkinlik_kesif/features/auth/models/auth_user.dart';
import 'package:etkinlik_kesif/features/favorites/data/favorites_repository.dart';
import 'package:etkinlik_kesif/features/favorites/models/favorite.dart';

const userA = AuthUser(id: 'user-a', email: 'a@example.com');
const userB = AuthUser(id: 'user-b', email: 'b@example.com');

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.user});
  AuthUser? user;
  final changes = StreamController<AuthUser?>.broadcast(sync: true);
  int signIns = 0;
  int signUps = 0;
  int signOuts = 0;
  Future<AuthUser> Function()? onSignIn;
  Future<AuthUser> Function()? onSignUp;

  void emit(AuthUser? user) {
    this.user = user;
    changes.add(user);
  }

  @override
  AuthUser? get currentUser => user;
  @override
  Stream<AuthUser?> get userChanges => changes.stream;
  @override
  Future<AuthUser> signIn(String email, String password) async {
    signIns++;
    final result = await (onSignIn?.call() ?? Future.value(userA));
    emit(result);
    return result;
  }

  @override
  Future<AuthUser> signUp(String email, String password) async {
    signUps++;
    final result = await (onSignUp?.call() ?? Future.value(userA));
    emit(result);
    return result;
  }

  @override
  Future<void> signOut() async {
    signOuts++;
    emit(null);
  }

  Future<void> dispose() => changes.close();
}

Favorite savedFavorite(
  String userId, {
  String eventId = 'evt-012',
  DateTime? savedAt,
}) => Favorite(
  userId: userId,
  eventId: eventId,
  title: 'Sky Lab Tanışma Kahvaltısı',
  startsAt: DateTime.utc(2026, 10, 17, 7),
  savedAt: savedAt ?? DateTime.utc(2026, 10, 24),
  category: 'Sosyal',
);

class FakeFavoritesRepository implements FavoritesRepository {
  final Map<String, List<Favorite>> byUser = {};
  Future<List<Favorite>> Function(String)? onFetch;
  Future<Favorite> Function(Favorite)? onAdd;
  Future<void> Function(String, String)? onRemove;
  int fetches = 0;
  int adds = 0;
  int removes = 0;

  @override
  Future<List<Favorite>> fetchFavorites(String userId) async {
    fetches++;
    if (onFetch != null) return onFetch!(userId);
    return List.of(byUser[userId] ?? []);
  }

  @override
  Future<Favorite> add(Favorite favorite) async {
    adds++;
    if (onAdd != null) return onAdd!(favorite);
    final saved = Favorite.fromJson({
      ...favorite.toInsertJson(),
      'saved_at': DateTime.now().toUtc().toIso8601String(),
    });
    (byUser[favorite.userId] ??= []).add(saved);
    return saved;
  }

  @override
  Future<void> remove(String userId, String eventId) async {
    removes++;
    if (onRemove != null) return onRemove!(userId, eventId);
    byUser[userId]?.removeWhere((favorite) => favorite.eventId == eventId);
  }
}
