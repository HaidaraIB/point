import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Shows a blocking loading dialog while [action] runs, then always closes it.
///
/// Prefer this over raw [Get.dialog] for Meta Graph bootstrap — on web,
/// [Get.isDialogOpen] is unreliable and the spinner can stick after errors.
Future<T> runWithMetaGraphLoadingOverlay<T>(Future<T> Function() action) async {
  final overlayContext = Get.overlayContext;
  if (overlayContext == null) return action();

  // Do not await — showDialog completes only when the route is popped.
  unawaited(
    showDialog<void>(
      context: overlayContext,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator()),
      ),
    ),
  );

  // Let the dialog route mount before starting the network call.
  await Future<void>.delayed(Duration.zero);

  try {
    return await action();
  } finally {
    _closeMetaGraphLoadingOverlay(overlayContext);
  }
}

void _closeMetaGraphLoadingOverlay(BuildContext overlayContext) {
  try {
    final navigator = Navigator.of(overlayContext, rootNavigator: true);
    if (navigator.canPop()) {
      navigator.pop();
    }
  } catch (_) {
    if (Get.isDialogOpen == true) {
      Get.back(closeOverlays: true);
    }
  }
}
