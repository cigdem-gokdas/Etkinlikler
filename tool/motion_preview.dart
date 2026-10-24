// Offline simulator fixtures. This entry point is never imported by main.dart.
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:etkinlik_kesif/app/launch/launch_intro.dart';
import 'package:etkinlik_kesif/app/theme/app_theme.dart';
import 'package:etkinlik_kesif/features/auth/controllers/auth_controller.dart';
import 'package:etkinlik_kesif/features/events/data/events_repository.dart';
import 'package:etkinlik_kesif/features/events/models/event.dart';
import 'package:etkinlik_kesif/features/events/models/events_page.dart';
import 'package:etkinlik_kesif/features/events/presentation/screens/event_detail_screen.dart';
import 'package:etkinlik_kesif/features/favorites/controllers/favorites_controller.dart';
import 'package:etkinlik_kesif/features/onboarding/data/onboarding_repository.dart';
import 'package:etkinlik_kesif/features/onboarding/presentation/onboarding_gate.dart';

Future<void> main() async {
  if (!kDebugMode) throw UnsupportedError('Debug fixture only');
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr_TR');
  runApp(const Preview());
}

class Preview extends StatelessWidget {
  const Preview({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: AppTheme.light,
    debugShowCheckedModeBanner: false,
    home: LaunchIntro(
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Görsel test fixture’ları')),
          body: ListView(
            children: [
              for (final size in [
                const Size(800, 450),
                const Size(600, 600),
                const Size(600, 800),
                const Size(450, 800),
              ])
                ListTile(
                  title: Text('${size.width.toInt()} × ${size.height.toInt()}'),
                  subtitle: const Text(
                    'Sentetik ölçüm görseli · API fotoğrafı değil',
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => FixtureDetail(size: size),
                    ),
                  ),
                ),
              ListTile(
                title: const Text('Uzun içerik · büyük yazı'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        const FixtureDetail(size: Size(800, 450), long: true),
                  ),
                ),
              ),
              ListTile(
                title: const Text('Intro → onboarding önizleme'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => LaunchIntro(
                      child: OnboardingGate(
                        repository: PreviewOnboardingRepository(),
                        child: const Scaffold(
                          body: Center(child: Text('Önizleme tamamlandı')),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class FixtureDetail extends StatefulWidget {
  const FixtureDetail({super.key, required this.size, this.long = false});
  final Size size;
  final bool long;
  @override
  State<FixtureDetail> createState() => _FixtureDetailState();
}

class _FixtureDetailState extends State<FixtureDetail> {
  final auth = AuthController();
  final favorites = FavoritesController(null);
  late final image = makeFixture(widget.size);
  late final repo = FixtureRepository(long: widget.long);
  @override
  void dispose() {
    auth.dispose();
    favorites.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<ImageProvider>(
    future: image,
    builder: (context, snapshot) => snapshot.data == null
        ? const Scaffold(body: Center(child: CircularProgressIndicator()))
        : MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(widget.long ? 1.8 : 1)),
            child: EventDetailScreen(
              eventId: 'fixture',
              repository: repo,
              favorites: favorites,
              auth: auth,
              onSignIn: () async {},
              imageProvider: snapshot.data,
            ),
          ),
  );
}

Future<ImageProvider> makeFixture(Size size) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFC8D2BE));
  for (var x = 0.0; x < size.width; x += 50) {
    for (var y = 0.0; y < size.height; y += 50) {
      if (((x + y) / 50).round().isEven) {
        canvas.drawRect(
          Rect.fromLTWH(x, y, 50, 50),
          Paint()..color = const Color(0xFF7C9887),
        );
      }
    }
  }
  canvas.drawRect(
    (Offset.zero & size).deflate(8),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..color = Colors.white,
  );
  final label = TextPainter(
    text: TextSpan(
      text: '${size.width.toInt()} × ${size.height.toInt()}\nTEST FIXTURE',
      style: const TextStyle(
        fontSize: 38,
        color: Color(0xFF14251F),
        fontWeight: FontWeight.bold,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  label.paint(
    canvas,
    Offset((size.width - label.width) / 2, (size.height - label.height) / 2),
  );
  final picture = recorder.endRecording();
  final frame = await picture.toImage(size.width.toInt(), size.height.toInt());
  final bytes = await frame.toByteData(format: ui.ImageByteFormat.png);
  picture.dispose();
  frame.dispose();
  label.dispose();
  return MemoryImage(bytes!.buffer.asUint8List());
}

class FixtureRepository implements EventsRepository {
  FixtureRepository({required this.long});
  final bool long;
  @override
  Future<Event> fetchEvent(String id) async => Event(
    id: id,
    title: long
        ? List.filled(4, 'Uzun başlık ve erişilebilir metin').join(' ')
        : 'Fotoğraf kompozisyonu',
    category: 'TEST FIXTURE',
    startDate: DateTime(2026, 11, 18, 19),
    endDate: DateTime(2026, 11, 18, 20, 30),
    location: 'Çevrim dışı görsel doğrulama',
    organizer: '',
    imageUrl: null,
    capacity: 0,
    registeredCount: 0,
    isOnline: false,
    tags: [],
    description: long
        ? '${List.filled(20, 'Bu içerik yalnızca taşma, büyük yazı ve kaydırma sınaması içindir.').join('\n\n')}\nAÇIKLAMANIN SONU'
        : 'Bu sentetik ölçüm görseli canlı etkinlik verisi değildir. Kenar çizgileri ve kareler, esneme ve kırpmayı görünür kılar.',
  );
  @override
  Future<List<String>> fetchCategories() async => [];
  @override
  Future<EventsPage> fetchEvents({
    int? page,
    int? limit,
    String? query,
    String? category,
    bool? online,
  }) => throw UnsupportedError('Detail only');
}
