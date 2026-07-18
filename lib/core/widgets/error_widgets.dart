// lib/core/widgets/error_widgets.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:patelmart/core/network/api_client.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

enum ErrorType {
  network,
  server,
  location,
  dataNotFound,
  auth,
  generic
}

class AppErrorWidget extends StatelessWidget {
  final ErrorType errorType;
  final String? message;
  final VoidCallback? onRetry;
  final VoidCallback? onCancel;
  final String? retryText;
  final String? cancelText;

  const AppErrorWidget({
    Key? key,
    required this.errorType,
    this.message,
    this.onRetry,
    this.onCancel,
    this.retryText = 'Try Again',
    this.cancelText = 'Cancel',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildIcon(),
            const SizedBox(height: 16),
            Text(
              _getErrorTitle(),
              style: AppTextStyles.h5.copyWith(
                color: _getErrorColor(),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message ?? _getDefaultMessage(),
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _buildButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon() {
    IconData iconData;
    Color iconColor = _getErrorColor();
    
    switch (errorType) {
      case ErrorType.network:
        iconData = Icons.wifi_off_rounded;
        break;
      case ErrorType.server:
        iconData = Icons.cloud_off;
        break;
      case ErrorType.location:
        iconData = Icons.location_disabled;
        break;
      case ErrorType.dataNotFound:
        iconData = Icons.search_off;
        break;
      case ErrorType.generic:
      default:
        iconData = Icons.error_outline;
        break;
    }
    
    return Icon(
      iconData,
      size: 72,
      color: iconColor,
    );
  }

  Color _getErrorColor() {
    switch (errorType) {
      case ErrorType.network:
      case ErrorType.server:
        return AppColors.error;
      case ErrorType.location:
        return AppColors.warning;
      case ErrorType.dataNotFound:
        return AppColors.neutral500;
      case ErrorType.generic:
      default:
        return AppColors.error;
    }
  }

  String _getErrorTitle() {
    switch (errorType) {
      case ErrorType.network:
        return 'Network Error';
      case ErrorType.server:
        return 'Server Error';
      case ErrorType.location:
        return 'Location Error';
      case ErrorType.dataNotFound:
        return 'No Data Found';
      case ErrorType.generic:
      default:
        return 'Something Went Wrong';
    }
  }

  String _getDefaultMessage() {
    switch (errorType) {
      case ErrorType.network:
        return 'Please check your internet connection and try again.';
      case ErrorType.server:
        return 'There was an error connecting to our servers. Please try again later.';
      case ErrorType.location:
        return 'We couldn\'t access your location. Please check your location settings.';
      case ErrorType.dataNotFound:
        return 'We couldn\'t find what you\'re looking for.';
      case ErrorType.generic:
      default:
        return 'An unexpected error occurred. Please try again.';
    }
  }

  Widget _buildButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (onRetry != null)
          ElevatedButton(
            onPressed: onRetry,
            child: Text(retryText!),
          ),
        if (onRetry != null && onCancel != null)
          const SizedBox(width: 16),
        if (onCancel != null)
          OutlinedButton(
            onPressed: onCancel,
            child: Text(cancelText!),
          ),
      ],
    );
  }
}

// Toast-Style Error Message
class ErrorToast extends StatelessWidget {
  final String message;
  final VoidCallback? onDismiss;

  const ErrorToast({
    Key? key,
    required this.message,
    this.onDismiss,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(8),
      color: AppColors.errorLight,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: AppColors.error,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (onDismiss != null)
              IconButton(
                icon: const Icon(Icons.close, size: 16),
                onPressed: onDismiss,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                color: AppColors.neutral700,
              ),
          ],
        ),
      ),
    );
  }
}

// Helper function to show toast
void showErrorToast(BuildContext context, String message, {Duration duration = const Duration(seconds: 3)}) {
  final overlayState = Overlay.of(context);
  late OverlayEntry overlayEntry;
  
  overlayEntry = OverlayEntry(
    builder: (context) => Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 16,
      left: 16,
      right: 16,
      child: ErrorToast(
        message: message,
        onDismiss: () => overlayEntry.remove(),
      ),
    ),
  );

  overlayState.insert(overlayEntry);
  
  Future.delayed(duration, () {
    if (overlayEntry.mounted) {
      overlayEntry.remove();
    }
  });
}

// A widget that handles AsyncValue states
class AsyncValueWidget<T> extends StatelessWidget {
  final AsyncValue<T> value;
  final Widget Function(T data) dataBuilder;
  final Widget Function(Object error, StackTrace? stackTrace)? errorBuilder;
  final Widget? loadingWidget;

  const AsyncValueWidget({
    Key? key,
    required this.value,
    required this.dataBuilder,
    this.errorBuilder,
    this.loadingWidget,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: dataBuilder,
      loading: () => loadingWidget ?? const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) {
        if (errorBuilder != null) {
          return errorBuilder!(error, stackTrace);
        }
        
        ErrorType errorType = ErrorType.generic;
        String errorMessage = error.toString();
        
        if (error is ApiException) {
          errorType = error.type;
          errorMessage = error.message;
        }
        
        return AppErrorWidget(
          errorType: errorType,
          message: errorMessage,
          onRetry: () {
            // This is just a placeholder. In real usage, you'd pass a callback 
            // to refresh the data from the parent widget.
          },
        );
      },
    );
  }
}