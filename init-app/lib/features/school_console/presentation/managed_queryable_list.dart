import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mobile_template/app/theme/app_dimensions.dart';

enum ManagedActivityFilter { all, active, inactive }

class ManagedQueryableList<T> extends StatefulWidget {
  const ManagedQueryableList({
    required this.items,
    required this.searchText,
    required this.isActive,
    required this.compare,
    required this.itemBuilder,
    required this.searchHint,
    required this.emptyMessage,
    super.key,
  });

  final List<T> items;
  final String Function(T item) searchText;
  final bool Function(T item) isActive;
  final int Function(T a, T b) compare;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final String searchHint;
  final String emptyMessage;

  @override
  State<ManagedQueryableList<T>> createState() =>
      _ManagedQueryableListState<T>();
}

class _ManagedQueryableListState<T> extends State<ManagedQueryableList<T>> {
  static const pageSize = 10;
  final search = TextEditingController();
  ManagedActivityFilter activity = ManagedActivityFilter.all;
  bool ascending = true;
  int page = 0;

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = search.text.trim().toLowerCase();
    final filtered =
        widget.items.where((item) {
          final active = widget.isActive(item);
          final matchesActivity = switch (activity) {
            ManagedActivityFilter.all => true,
            ManagedActivityFilter.active => active,
            ManagedActivityFilter.inactive => !active,
          };
          return matchesActivity &&
              (query.isEmpty ||
                  widget.searchText(item).toLowerCase().contains(query));
        }).toList()..sort(
          (a, b) => ascending ? widget.compare(a, b) : widget.compare(b, a),
        );
    final pageCount = math.max(1, (filtered.length / pageSize).ceil());
    if (page >= pageCount) page = pageCount - 1;
    final visible = filtered
        .skip(page * pageSize)
        .take(pageSize)
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppDimensions.spaceS,
          runSpacing: AppDimensions.spaceS,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 340,
              child: TextField(
                controller: search,
                onChanged: (_) => setState(() => page = 0),
                decoration: InputDecoration(
                  labelText: widget.searchHint,
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Очистить поиск',
                          onPressed: () {
                            search.clear();
                            setState(() => page = 0);
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
            ),
            SizedBox(
              width: 190,
              child: DropdownButtonFormField<ManagedActivityFilter>(
                initialValue: activity,
                decoration: const InputDecoration(labelText: 'Активность'),
                items: const [
                  DropdownMenuItem(
                    value: ManagedActivityFilter.all,
                    child: Text('Все'),
                  ),
                  DropdownMenuItem(
                    value: ManagedActivityFilter.active,
                    child: Text('Активные'),
                  ),
                  DropdownMenuItem(
                    value: ManagedActivityFilter.inactive,
                    child: Text('Отключённые'),
                  ),
                ],
                onChanged: (value) => setState(() {
                  activity = value ?? ManagedActivityFilter.all;
                  page = 0;
                }),
              ),
            ),
            IconButton.outlined(
              tooltip: ascending ? 'По возрастанию' : 'По убыванию',
              onPressed: () => setState(() {
                ascending = !ascending;
                page = 0;
              }),
              icon: Icon(
                ascending
                    ? Icons.sort_by_alpha_rounded
                    : Icons.sort_by_alpha_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spaceL),
        if (visible.isEmpty)
          Padding(
            padding: AppDimensions.paddingAllXL,
            child: Center(child: Text(widget.emptyMessage)),
          )
        else
          ...visible.map((item) => widget.itemBuilder(context, item)),
        if (filtered.length > pageSize) ...[
          const SizedBox(height: AppDimensions.spaceM),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Предыдущая страница',
                onPressed: page == 0 ? null : () => setState(() => page--),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Text(
                'Страница ${page + 1} из $pageCount · ${filtered.length} записей',
              ),
              IconButton(
                tooltip: 'Следующая страница',
                onPressed: page + 1 >= pageCount
                    ? null
                    : () => setState(() => page++),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
