
// lib/presentation/widgets/outlet_status_banner.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:patelmart/core/constants/app_colors.dart';
import 'package:patelmart/core/constants/app_text_styles.dart';
import 'package:patelmart/data/models/outlet_status_model.dart';
import 'package:patelmart/data/services/outlet_status_service.dart';
import 'package:patelmart/presentation/providers/launch_flow_provider.dart';
import 'package:patelmart/presentation/providers/outlet_provider.dart';
import 'package:patelmart/presentation/providers/outlet_status_provider.dart';


class OutletStatusBanner extends ConsumerWidget {
  final bool showOnlyIfUnavailable;

  const OutletStatusBanner({
    Key? key,
    this.showOnlyIfUnavailable = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outletStatusAsync = ref.watch(currentOutletStatusProvider);
    final statusMessage = ref.watch(outletStatusMessageProvider);
    
    return outletStatusAsync.when(
      data: (status) {
        if (status == null) return const SizedBox.shrink();
        
        // If showOnlyIfUnavailable is true, only show when there are issues
        if (showOnlyIfUnavailable && status.isFullyOperational) {
          return const SizedBox.shrink();
        }
        
        // Determine banner color based on status
        Color backgroundColor;
        Color textColor;
        IconData icon;
        
        if (!status.isEnabled) {
          backgroundColor = AppColors.errorLight;
          textColor = AppColors.error;
          icon = Icons.store_outlined;
        } else if (!status.hasAnyServiceAvailable) {
          backgroundColor = AppColors.warningLight;
          textColor = AppColors.warning;
          icon = Icons.delivery_dining_outlined;
        } else if (!status.hasBothServices) {
          backgroundColor = AppColors.infoLight;
          textColor = AppColors.info;
          icon = Icons.info_outline;
        } else {
          backgroundColor = AppColors.successLight;
          textColor = AppColors.success;
          icon = Icons.check_circle_outline;
        }
        
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: textColor.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: textColor,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getStatusTitle(status),
                      style: AppTextStyles.labelMedium.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (statusMessage != null && statusMessage.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        statusMessage,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: textColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!status.isFullyOperational)
                IconButton(
                  icon: Icon(Icons.refresh, color: textColor, size: 20),
                  onPressed: () {
                    ref.read(refreshOutletStatusProvider)();
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (error, stackTrace) => const SizedBox.shrink(),
    );
  }

  String _getStatusTitle(OutletStatus status) {
    if (!status.isEnabled) {
      return 'Store Temporarily Closed';
    } else if (!status.hasAnyServiceAvailable) {
      return 'No Services Available';
    } else if (status.hasDeliveryOnly) {
      return 'Home Delivery Only';
    } else if (status.hasPickupOnly) {
      return 'Store Pickup Only';
    } else {
      return 'All Services Available';
    }
  }
}