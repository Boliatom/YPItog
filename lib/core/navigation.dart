import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

void popOrGo(BuildContext context, String fallback, [Object? result]) {
  if (context.canPop()) {
    context.pop(result);
  } else {
    context.go(fallback);
  }
}
