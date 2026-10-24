import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../app/widgets/collapsing_header.dart';
import '../../../../core/widgets/status_message.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../controllers/events_controller.dart';
import '../../models/event.dart';
import '../widgets/event_row.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({
    super.key,
    required this.controller,
    this.eventBuilder,
    this.headerActions = const [],
  });

  final EventsController controller;
  final List<Widget> headerActions;
  final Widget Function(BuildContext, Event)? eventBuilder;

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _scroll = ScrollController();
  late final TextEditingController _search;
  int _filterRevision = 0;
  int _paginationCycle = 0;
  int _viewportFillAttempts = 0;
  bool _frameScheduled = false;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: widget.controller.query);
    _filterRevision = widget.controller.filterRevision;
    _paginationCycle = widget.controller.paginationCycle;
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    if (position.maxScrollExtent > 0 &&
        position.pixels >= position.maxScrollExtent * 0.70) {
      unawaited(widget.controller.loadMore());
    }
  }

  void _afterLayout() {
    if (_frameScheduled) return;
    _frameScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _frameScheduled = false;
      if (!mounted) return;
      final controller = widget.controller;
      if (_filterRevision != controller.filterRevision && _scroll.hasClients) {
        _filterRevision = controller.filterRevision;
        _scroll.jumpTo(0);
      }
      if (_paginationCycle != controller.paginationCycle) {
        _paginationCycle = controller.paginationCycle;
        _viewportFillAttempts = 0;
      }
      // At most three automatic fills per query/refresh, never an unbounded loop.
      if (_scroll.hasClients &&
          _scroll.position.maxScrollExtent <= 0 &&
          controller.status == EventsStatus.success &&
          controller.activity == EventsActivity.idle &&
          controller.hasMore &&
          controller.paginationError == null &&
          _viewportFillAttempts < 3) {
        _viewportFillAttempts++;
        unawaited(controller.loadMore());
      }
    });
  }

  void _clearSearch() {
    _search.clear();
    widget.controller.clearSearch();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, child) {
      _afterLayout();
      final controller = widget.controller;
      final controlHeight =
          120.0 +
          (MediaQuery.textScalerOf(context).scale(16) - 16) * 2 +
          (controller.categoriesStatus == CategoriesStatus.error ? 74 : 0);
      return ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: RefreshIndicator(
          onRefresh: controller.load,
          child: CustomScrollView(
            key: const PageStorageKey('events-list'),
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              CollapsingHeader(title: 'Keşfet', actions: widget.headerActions),
              SliverPersistentHeader(
                delegate: SearchFilterHeader(
                  height: controlHeight,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                        child: TextField(
                          key: const ValueKey('event-search'),
                          controller: _search,
                          onChanged: controller.setSearchQuery,
                          textInputAction: TextInputAction.search,
                          autocorrect: false,
                          decoration: InputDecoration(
                            hintText: 'Etkinlik ara',
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            prefixIcon: const Icon(Icons.search, size: 20),
                            suffixIcon: controller.query.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'Aramayı temizle',
                                    onPressed: _clearSearch,
                                    icon: const Icon(Icons.close, size: 18),
                                  ),
                          ),
                        ),
                      ),
                      _categories(context),
                    ],
                  ),
                ),
              ),
              ..._results(context),
            ],
          ),
        ),
      );
    },
  );

  Widget _categories(BuildContext context) {
    final controller = widget.controller;
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          key: const ValueKey('category-scroll'),
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
          child: Row(
            children: [
              _category(context, null, 'Tümü'),
              for (final category in controller.categories)
                _category(context, category, category),
              if (controller.categoriesStatus == CategoriesStatus.loading &&
                  controller.categories.isEmpty)
                const CategorySkeleton(),
            ],
          ),
        ),
        if (controller.categoriesStatus == CategoriesStatus.loading &&
            controller.categories.isNotEmpty)
          const LinearProgressIndicator(
            minHeight: 1,
            semanticsLabel: 'Kategoriler yükleniyor',
          ),
        if (controller.categoriesStatus == CategoriesStatus.error)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    controller.categoriesError!,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                TextButton(
                  onPressed: controller.loadCategories,
                  child: const Text('Kategorileri yenile'),
                ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.small),
      ],
    );
  }

  Widget _category(BuildContext context, String? value, String label) {
    final selected = widget.controller.selectedCategory == value;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.small),
      child: Semantics(
        selected: selected,
        button: true,
        child: TextButton(
          key: ValueKey('category:${value ?? 'all'}'),
          onPressed: () => widget.controller.selectCategory(value),
          style: TextButton.styleFrom(
            foregroundColor: selected
                ? theme.colorScheme.onSurface
                : theme.colorScheme.onSurfaceVariant,
            backgroundColor: selected
                ? theme.colorScheme.surfaceContainerHighest
                : Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            textStyle: theme.textTheme.bodySmall?.copyWith(
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
              side: BorderSide(color: theme.dividerColor),
            ),
          ),
          child: Text(label),
        ),
      ),
    );
  }

  List<Widget> _results(BuildContext context) {
    final controller = widget.controller;
    if (controller.status == EventsStatus.loading) {
      return [
        SliverFillRemaining(
          hasScrollBody: true,
          child: controller.activity == EventsActivity.debouncing
              ? Semantics(
                  liveRegion: true,
                  label: 'Arama hazırlanıyor',
                  child: const SizedBox.expand(),
                )
              : const EventListSkeleton(),
        ),
      ];
    }
    if (controller.status == EventsStatus.error) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: StatusMessage(
            title: 'Etkinlikler yüklenemedi',
            description: controller.errorMessage,
            onRetry: controller.load,
          ),
        ),
      ];
    }
    return [
      if (controller.isRefreshing)
        const SliverToBoxAdapter(child: LinearProgressIndicator(minHeight: 2)),
      if (controller.errorMessage != null)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                Text('Yenileme başarısız. ${controller.errorMessage}'),
                TextButton(
                  onPressed: controller.isRefreshing ? null : controller.load,
                  child: const Text('Tekrar dene'),
                ),
              ],
            ),
          ),
        ),
      if (controller.status == EventsStatus.empty)
        SliverFillRemaining(
          hasScrollBody: false,
          child: StatusMessage(
            title: controller.query.isNotEmpty
                ? 'Bu aramayla eşleşen etkinlik bulunamadı.'
                : controller.selectedCategory != null
                ? 'Bu kategoride etkinlik bulunamadı.'
                : 'Henüz etkinlik yok.',
            description: 'Yenilemek için aşağı çekin.',
            onRetry: controller.query.isNotEmpty ? _clearSearch : null,
            retryLabel: 'Aramayı temizle',
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          sliver: SliverList.builder(
            itemCount: controller.events.length,
            itemBuilder: (context, index) {
              final event = controller.events[index];
              return Column(
                key: ValueKey(event.id),
                children: [
                  if (index > 0) const Divider(),
                  widget.eventBuilder?.call(context, event) ??
                      EventRow(event: event),
                ],
              );
            },
          ),
        ),
      SliverToBoxAdapter(child: _footer(context)),
    ];
  }

  Widget _footer(BuildContext context) {
    final controller = widget.controller;
    if (controller.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.medium),
        child: Center(
          child: SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              semanticsLabel: 'Diğer etkinlikler yükleniyor',
            ),
          ),
        ),
      );
    }
    if (controller.paginationError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.medium),
        child: Column(
          children: [
            Text(
              'Kalan etkinlikler yüklenemedi.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            TextButton(
              onPressed: () => controller.loadMore(retry: true),
              child: const Text('Tekrar dene'),
            ),
          ],
        ),
      );
    }
    if (controller.hasMore &&
        _viewportFillAttempts >= 3 &&
        _scroll.hasClients &&
        _scroll.position.maxScrollExtent <= 0) {
      return TextButton(
        onPressed: controller.loadMore,
        child: const Text('Diğer etkinlikleri yükle'),
      );
    }
    return const SizedBox(height: AppSpacing.small);
  }
}
