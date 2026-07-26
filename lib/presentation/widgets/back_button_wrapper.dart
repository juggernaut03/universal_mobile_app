// lib/core/widgets/back_button_wrapper.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/back_handler.dart';
import '../../di/infrastructure_providers.dart';


class BackButtonWrapper extends ConsumerWidget {
  final Widget child;
  final String? alternateRoute;
  final String? customExitMessage;
  final Duration exitConfirmTime;

  const BackButtonWrapper({
    Key? key,
    required this.child,
    this.alternateRoute,
    this.customExitMessage,
    this.exitConfirmTime = const Duration(seconds: 2),
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backHandler = ref.watch(backButtonHandlerProvider);
    
    return WillPopScope(
      onWillPop: () => backHandler.handleBackPress(
        context,
        alternateRoute: alternateRoute,
        customExitMessage: customExitMessage,
        exitConfirmTime: exitConfirmTime,
      ),
      child: child,
    );
  }
}

final backButtonHandlerProvider = Provider<BackButtonHandler>((ref) {
  final logger = ref.watch(loggerProvider);
  return BackButtonHandler(logger: logger);
});
