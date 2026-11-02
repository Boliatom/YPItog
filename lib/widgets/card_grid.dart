import 'package:flutter/material.dart';

class CardGrid<T> extends StatelessWidget {
  const CardGrid({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.columns = 1,
    this.spacing = 8,
    this.padding = EdgeInsets.zero,
    this.controller,
  });

  final List<T> items;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final int columns;
  final double spacing;
  final EdgeInsets padding;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    if (columns <= 1) {
      return ListView.separated(
        controller: controller,
        padding: padding,
        itemCount: items.length,
        separatorBuilder: (_, _) => SizedBox(height: spacing),
        itemBuilder: (context, index) => itemBuilder(context, items[index]),
      );
    }

    final rows = (items.length / columns).ceil();
    return ListView.separated(
      controller: controller,
      padding: padding,
      itemCount: rows,
      separatorBuilder: (_, _) => SizedBox(height: spacing),
      itemBuilder: (context, row) {
        final children = <Widget>[];
        for (var c = 0; c < columns; c++) {
          final index = row * columns + c;
          if (c > 0) children.add(SizedBox(width: spacing));
          children.add(
            Expanded(
              child: index < items.length
                  ? itemBuilder(context, items[index])
                  : const SizedBox.shrink(),
            ),
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        );
      },
    );
  }
}

class TwoDimensionalScroll extends StatefulWidget {
  const TwoDimensionalScroll({super.key, required this.child});

  final Widget child;

  @override
  State<TwoDimensionalScroll> createState() => _TwoDimensionalScrollState();
}

class _TwoDimensionalScrollState extends State<TwoDimensionalScroll> {
  final _vertical = ScrollController();
  final _horizontal = ScrollController();

  @override
  void dispose() {
    _vertical.dispose();
    _horizontal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Scrollbar(
        controller: _vertical,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _vertical,
          child: Scrollbar(
            controller: _horizontal,
            notificationPredicate: (n) => n.depth == 1,
            child: SingleChildScrollView(
              controller: _horizontal,
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
