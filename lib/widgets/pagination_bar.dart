import 'package:flutter/material.dart';

import '../models/list_query.dart';
import '../models/page_result.dart';

class PaginationBar extends StatelessWidget {
  const PaginationBar({
    super.key,
    required this.page,
    required this.size,
    required this.onPage,
    required this.onSize,
    this.enabled = true,
  });

  final PageResult<dynamic> page;

  final int size;
  final ValueChanged<int> onPage;
  final ValueChanged<int> onSize;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final current = page.page;
    final last = page.totalPages;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 4,
        children: [
          Text(
            'Всего записей: ${page.total}',
            key: const ValueKey('total-count'),
          ),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              IconButton(
                key: const ValueKey('page-first'),
                tooltip: 'Первая страница',
                onPressed: enabled && page.hasPrevious ? () => onPage(1) : null,
                icon: const Icon(Icons.first_page),
              ),
              IconButton(
                key: const ValueKey('page-prev'),
                tooltip: 'Предыдущая страница',
                onPressed: enabled && page.hasPrevious
                    ? () => onPage(current - 1)
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'Страница $current из $last',
                  key: const ValueKey('page-label'),
                ),
              ),
              IconButton(
                key: const ValueKey('page-next'),
                tooltip: 'Следующая страница',
                onPressed: enabled && page.hasNext
                    ? () => onPage(current + 1)
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
              IconButton(
                key: const ValueKey('page-last'),
                tooltip: 'Последняя страница',
                onPressed: enabled && page.hasNext ? () => onPage(last) : null,
                icon: const Icon(Icons.last_page),
              ),
            ],
          ),
          MergeSemantics(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('На странице:'),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  key: const ValueKey('page-size'),
                  value: pageSizes.contains(size) ? size : pageSizes.first,
                  onChanged: enabled
                      ? (value) {
                          if (value != null && value != size) onSize(value);
                        }
                      : null,
                  items: [
                    for (final option in pageSizes)
                      DropdownMenuItem(value: option, child: Text('$option')),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
