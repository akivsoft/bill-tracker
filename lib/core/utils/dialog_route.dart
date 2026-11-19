import 'package:flutter/material.dart';

/// Shows a dialog and waits until its route has finished leaving the tree.
///
/// The future returned by [showDialog] can complete while the reverse
/// transition is still running. Callers that own controllers used by dialog
/// fields should wait for [DialogRoute.completed] before disposing them.
Future<T?> showDialogAndWaitForExit<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  TraversalEdgeBehavior traversalEdgeBehavior =
      TraversalEdgeBehavior.closedLoop,
}) async {
  final NavigatorState navigator = Navigator.of(context, rootNavigator: true);
  final CapturedThemes themes = InheritedTheme.capture(
    from: context,
    to: navigator.context,
  );
  final DialogRoute<T> route = DialogRoute<T>(
    context: context,
    builder: builder,
    themes: themes,
    barrierColor:
        DialogTheme.of(context).barrierColor ??
        Theme.of(context).dialogTheme.barrierColor ??
        Colors.black54,
    barrierDismissible: barrierDismissible,
    traversalEdgeBehavior: traversalEdgeBehavior,
  );
  final T? result = await navigator.push<T>(route);
  await route.completed;
  return result;
}
