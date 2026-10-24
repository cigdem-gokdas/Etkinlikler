import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/widgets/status_message.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../controllers/events_controller.dart';
import '../../models/event.dart';
import '../widgets/event_row.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key, required this.controller, this.eventBuilder});

  final EventsController controller;
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
      return ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: LayoutBuilder(
          builder: (context, constraints) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  0,
                  AppSpacing.page,
                  AppSpacing.small,
                ),
                child: TextField(
                  key: const ValueKey('event-search'),
                  controller: _search,
                  onChanged: controller.setSearchQuery,
                  keyboardType: TextInputType.text,
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
              // Keep the input usable when a large keyboard leaves little room.
              if (constraints.maxHeight >= 180 ||
                  MediaQuery.viewInsetsOf(context).bottom == 0)
                _categories(context),
              Expanded(child: _results(context)),
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

  Widget _results(BuildContext context) {
    final controller = widget.controller;
    if (controller.status == EventsStatus.loading) {
      // The existing debounce is the only wait. Fast responses finish before a
      // frame; consecutive keystrokes retain the same non-interactive subtree.
      return controller.activity == EventsActivity.debouncing
          ? Semantics(
              liveRegion: true,
              label: 'Arama hazırlanıyor',
              child: const SizedBox.expand(),
            )
          : const EventListSkeleton();
    }
    if (controller.status == EventsStatus.error) {
      return SingleChildScrollView(
        child: StatusMessage(
          title: 'Etkinlikler yüklenemedi',
          description: controller.errorMessage,
          onRetry: controller.load,
        ),
      );
    }
    return Column(
      children: [
        if (controller.isRefreshing)
          const LinearProgressIndicator(minHeight: 2),
        if (controller.errorMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Yenileme başarısız. ${controller.errorMessage}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                TextButton(
                  onPressed: controller.isRefreshing ? null : controller.load,
                  child: const Text('Tekrar dene'),
                ),
              ],
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: controller.load,
            child: controller.status == EventsStatus.empty
                ? LayoutBuilder(
                    builder: (context, constraints) => ListView(
                      controller: _scroll,
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: StatusMessage(
                            title: controller.query.isNotEmpty
                                ? 'Bu aramayla eşleşen etkinlik bulunamadı.'
                                : controller.selectedCategory != null
                                ? 'Bu kategoride etkinlik bulunamadı.'
                                : 'Henüz etkinlik yok.',
                            description: 'Yenilemek için aşağı çekin.',
                            onRetry: controller.query.isNotEmpty
                                ? _clearSearch
                                : null,
                            retryLabel: 'Aramayı temizle',
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    key: const PageStorageKey('events-list'),
                    controller: _scroll,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.page,
                    ),
                    itemCount: controller.events.length + 1,
                    itemBuilder: (context, index) {
                      if (index == controller.events.length) {
                        return _footer(context);
                      }
                      final event = controller.events[index];
                      return Column(
                        key: ValueKey(event.id),
                        children: [
                          if (index > 0) const Divider(),
                          if (widget.eventBuilder != null)
                            widget.eventBuilder!(context, event)
                          else
                            EventRow(event: event),
                        ],
                      );
                    },
                  ),
          ),
        ),
      ],
    );
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
