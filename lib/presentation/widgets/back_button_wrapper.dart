// lib/core/widgets/back_button_wrapper.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_shell_providers.dart';


class BackButtonWrapper extends ConsumerWidget {
  final Widget child;
  final String? alternateRoute;
  final String? customExitMessage;
  final Duration exitConfirmTime;

  const BackButtonWrapper({
    super.key,
    required this.child,
    this.alternateRoute,
    this.customExitMessage,
    this.exitConfirmTime = const Duration(seconds: 2),
  });

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

