import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

enum ImagePresentation { landscape, square, portrait }

ImagePresentation presentationFor(double ratio) => ratio >= 1.3
    ? ImagePresentation.landscape
    : ratio < .85
    ? ImagePresentation.portrait
    : ImagePresentation.square;

/// A single decoded frame forms the cinematic surface. Metadata comes from
/// the image stream, never a filename or a second HTTP/HEAD request.
class AdaptiveEventComposition extends StatefulWidget {
  const AdaptiveEventComposition({
    super.key,
    required this.imageUrl,
    required this.content,
    this.imageProvider,
    this.safePadding,
  });
  final String? imageUrl;
  final Widget content;
  final EdgeInsets? safePadding;

  /// Also permits deterministic image streams in offline widget/preview tests.
  final ImageProvider? imageProvider;

  @override
  State<AdaptiveEventComposition> createState() =>
      _AdaptiveEventCompositionState();
}

class _AdaptiveEventCompositionState extends State<AdaptiveEventComposition> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  ImageInfo? _frame;
  Object? _source;
  int _generation = 0;
  bool _failed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(AdaptiveEventComposition oldWidget) {
    super.didUpdateWidget(oldWidget);
    _resolve();
  }

  void _resolve() {
    final source = widget.imageProvider ?? widget.imageUrl;
    if (_source == source && (_stream != null || _failed)) return;
    _detach();
    _source = source;
    final previous = _frame;
    _frame = null;
    WidgetsBinding.instance.addPostFrameCallback((_) => previous?.dispose());
    _failed = false;
    final generation = ++_generation;
    final uri = Uri.tryParse(widget.imageUrl ?? '');
    final valid =
        uri != null &&
        uri.hasAuthority &&
        ['https', 'http'].contains(uri.scheme);
    if (widget.imageProvider == null && !valid) {
      _failed = true;
      return;
    }
    final provider =
        widget.imageProvider ??
        ResizeImage(
          NetworkImage(widget.imageUrl!),
          width: 1200,
          height: 1600,
          policy: ResizeImagePolicy.fit,
          allowUpscaling: false,
        );
    _stream = provider.resolve(createLocalImageConfiguration(context));
    _listener = ImageStreamListener(
      (info, sync) {
        if (!mounted || generation != _generation) {
          info.dispose();
          return;
        }
        final previous = _frame;
        setState(() {
          _frame = info;
          _failed = false;
        });
        // A previous RawImage may still be referenced by the current frame.
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => previous?.dispose(),
        );
      },
      onError: (Object error, StackTrace? stack) {
        if (!mounted || generation != _generation) return;
        setState(() => _failed = true);
      },
    );
    _stream!.addListener(_listener!);
  }

  void _detach() {
    if (_listener != null) _stream?.removeListener(_listener!);
    _listener = null;
    _stream = null;
  }

  @override
  void dispose() {
    _generation++;
    _detach();
    _frame?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _frame?.image;
    final ratio = image == null ? 16 / 9 : image.width / image.height;
    final mode = presentationFor(ratio);
    // Keep the established landscape atmosphere; portrait images need less
    // softening because their composition already matches the viewport.
    final sigma = switch (mode) {
      ImagePresentation.landscape => 5.0,
      ImagePresentation.square => 3.0,
      ImagePresentation.portrait => 1.0,
    };
    return LayoutBuilder(
      builder: (context, bounds) {
        final safeArea =
            widget.safePadding ?? MediaQuery.viewPaddingOf(context);
        final top = safeArea.top + kToolbarHeight + 28;
        return ColoredBox(
          color: const Color(0xFF14251F),
          child: Stack(
            fit: StackFit.expand,
            children: [
              RepaintBoundary(
                key: ValueKey('composition:${mode.name}'),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (image != null)
                      ImageFiltered(
                        imageFilter: ui.ImageFilter.blur(
                          sigmaX: sigma,
                          sigmaY: sigma,
                        ),
                        child: RawImage(
                          key: const ValueKey('atmospheric-image'),
                          image: image,
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.medium,
                        ),
                      )
                    else
                      Center(
                        child: Icon(
                          _failed
                              ? Icons.image_not_supported_outlined
                              : Icons.landscape_outlined,
                          size: 40,
                          color: Colors.white24,
                        ),
                      ),
                    // Retains the existing atmosphere and guarantees white text
                    // contrast >4.5:1 even over a pure-white source photograph.
                    const ColoredBox(
                      key: ValueKey('detail-scrim'),
                      color: Color(0xB8000000),
                    ),
                  ],
                ),
              ),
              SingleChildScrollView(
                key: const ValueKey('event-detail-scroll'),
                padding: EdgeInsets.fromLTRB(24, top, 24, 32 + safeArea.bottom),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 712,
                      minHeight: math.max(0, bounds.maxHeight - top - 64),
                    ),
                    child: widget.content,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
