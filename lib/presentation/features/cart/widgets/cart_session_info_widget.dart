// lib/presentation/widgets/cart_session_info_widget.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:patelmart/core/constants/app_colors.dart';
import 'package:patelmart/core/constants/app_text_styles.dart';
import 'package:patelmart/presentation/providers/cart_provider.dart';


/// A widget that displays information about the cart session
/// This is optional and can be used for debugging or to show users when their cart will expire
class CartSessionInfoWidget extends ConsumerStatefulWidget {
  const CartSessionInfoWidget({super.key});

  @override
  ConsumerState<CartSessionInfoWidget> createState() => _CartSessionInfoWidgetState();
}

class _CartSessionInfoWidgetState extends ConsumerState<CartSessionInfoWidget> {
  Timer? _refreshTimer;
  String _remainingTime = '';
  
  @override
  void initState() {
    super.initState();
    _updateRemainingTime();
    // Update the remaining time every minute
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _updateRemainingTime();
    });
  }
  
  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
  
  void _updateRemainingTime() {
    final cartNotifier = ref.read(cartProvider.notifier);
    final remainingMillis = cartNotifier.getRemainingSessionTime();
    
    if (remainingMillis <= 0) {
      setState(() {
        _remainingTime = 'Expired';
      });
      return;
    }
    
    // Calculate days, hours, minutes
    final days = remainingMillis ~/ (24 * 60 * 60 * 1000);
    final hours = (remainingMillis % (24 * 60 * 60 * 1000)) ~/ (60 * 60 * 1000);
    final minutes = (remainingMillis % (60 * 60 * 1000)) ~/ (60 * 1000);
    
    setState(() {
      if (days > 0) {
        _remainingTime = '$days days, $hours hours';
      } else if (hours > 0) {
        _remainingTime = '$hours hours, $minutes minutes';
      } else {
        _remainingTime = '$minutes minutes';
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final cartItems = ref.watch(cartItemsProvider);
    
    // Don't show anything if the cart is empty
    if (cartItems.isEmpty) {
      return const SizedBox.shrink();
    }
    
    // Get expiration date
    final cartNotifier = ref.read(cartProvider.notifier);
    final remainingMillis = cartNotifier.getRemainingSessionTime();
    final expirationDate = DateTime.now().add(Duration(milliseconds: remainingMillis));
    final formattedDate = DateFormat('MMM dd, yyyy').format(expirationDate);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: AppColors.infoLight,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: AppColors.info,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Your cart will be saved for $_remainingTime (until $formattedDate)',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.info,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              cartNotifier.refreshSession().then((_) {
                _updateRemainingTime();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Cart session refreshed'),
                    duration: Duration(seconds: 2),
                  ),
                );
              });
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Refresh',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}