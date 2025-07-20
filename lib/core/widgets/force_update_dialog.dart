// lib/core/widgets/force_update_dialog.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:patelmart/data/services/force_update_service.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../../presentation/providers/force_update_providers.dart';

class ForceUpdateDialog extends ConsumerStatefulWidget {
  final UpdateCheckResponse updateInfo;

  const ForceUpdateDialog({
    Key? key,
    required this.updateInfo,
  }) : super(key: key);

  @override
  ConsumerState<ForceUpdateDialog> createState() => _ForceUpdateDialogState();
}

class _ForceUpdateDialogState extends ConsumerState<ForceUpdateDialog> {
  bool _isUpdating = false;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevent back button dismissal
      child: Material(
        color: Colors.black.withOpacity(0.8), // Dark overlay to block interaction
        child: Container(
          width: double.infinity,
          height: double.infinity,
          child: Center(
            child: Container(
              margin: const EdgeInsets.all(24.0),
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Update Icon
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.system_update,
                      size: 40,
                      color: AppColors.primary,
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Title
                  Text(
                    widget.updateInfo.forceUpdate 
                        ? 'Update Required' 
                        : 'Update Available',
                    style: AppTextStyles.h5.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Update Message
                  Text(
                    widget.updateInfo.updateMessage,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Version Info
                  Text(
                    'Latest version: ${widget.updateInfo.latestVersion}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  // Platform-specific download info
                  const SizedBox(height: 4),
                  Text(
                    Platform.isAndroid 
                        ? 'Available on Google Play Store'
                        : 'Available on App Store',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Buttons
                  Row(
                    children: [
                      // Exit button (always show for force update)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isUpdating ? null : _exitApp,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Exit App',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(width: 12),
                      
                      // Update button
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isUpdating ? null : _handleUpdate,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isUpdating
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Text(
                                  Platform.isAndroid ? 'Update on Play Store' : 'Update on App Store',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleUpdate() async {
    setState(() {
      _isUpdating = true;
    });

    try {
      final downloadUrl = widget.updateInfo.downloadUrl;
      debugPrint('🔗 Attempting to open platform-specific URL: "$downloadUrl"');
      debugPrint('📱 Platform: ${Platform.isAndroid ? "Android" : "iOS"}');
      
      // Check if URL is empty
      if (downloadUrl.isEmpty) {
        debugPrint('⚠️ Download URL is empty, showing manual update message');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                Platform.isAndroid 
                    ? 'Please update manually from Google Play Store'
                    : 'Please update manually from App Store'
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }
      
      final service = ref.read(forceUpdateServiceProvider);
      final success = await service.openUpdateUrl(downloadUrl);
      
      debugPrint('🔗 URL open result: $success');
      
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              Platform.isAndroid
                  ? 'Could not open Play Store. Please update manually.'
                  : 'Could not open App Store. Please update manually.'
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error in _handleUpdate: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening store: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  void _exitApp() {
    debugPrint('🚪 User chose to exit app instead of updating');
    if (Platform.isAndroid) {
      SystemNavigator.pop();
    } else {
      exit(0);
    }
  }
}

/// Helper function to show force update dialog as full-screen blocking modal
void showForceUpdateDialog(BuildContext context, UpdateCheckResponse updateInfo) {
  debugPrint('🎬 SHOW FORCE UPDATE DIALOG CALLED:');
  debugPrint('   └─ Context: ${context != null}');
  debugPrint('   └─ Force Update: ${updateInfo.forceUpdate}');
  debugPrint('   └─ Platform: ${Platform.isAndroid ? "Android" : "iOS"}');
  debugPrint('   └─ Android URL: ${updateInfo.androidDownloadUrl}');
  debugPrint('   └─ iOS URL: ${updateInfo.iosDownloadUrl}');
  debugPrint('   └─ Selected URL: ${updateInfo.downloadUrl}');
  
  try {
    // Show as a full-screen route that can't be dismissed
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          debugPrint('📦 Force update dialog route builder called');
          return ForceUpdateDialog(updateInfo: updateInfo);
        },
        transitionDuration: const Duration(milliseconds: 300),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        barrierDismissible: false, // Can't dismiss by tapping outside
        fullscreenDialog: true, // Treat as full-screen dialog
      ),
    ).then((result) {
      debugPrint('🔚 Force update dialog closed with result: $result');
    });
    debugPrint('✅ Force update route pushed successfully');
  } catch (e) {
    debugPrint('❌ Error in showForceUpdateDialog: $e');
    rethrow;
  }
}