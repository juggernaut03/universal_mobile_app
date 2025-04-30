// lib/core/widgets/back_button_wrapper.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/back_handler.dart';
import '../utils/logger.dart';
import '../../presentation/providers/launch_flow_provider.dart';

// Provider for the BackButtonHandler
final backButtonHandlerProvider = Provider<BackButtonHandler>((ref) {
  final logger = ref.watch(loggerProvider);
  return BackButtonHandler(logger: logger);
});

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