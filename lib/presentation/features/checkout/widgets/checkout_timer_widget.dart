// lib/presentation/features/checkout/widgets/checkout_timer_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/checkout_timer_provider.dart';

// Main timer widget for checkout screen
class CheckoutTimerWidget extends ConsumerWidget {
  const CheckoutTimerWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timerState = ref.watch(checkoutTimerProvider);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _getBackgroundColor(timerState),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getBorderColor(timerState),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _getBorderColor(timerState).withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            _getIcon(timerState),
            color: _getIconColor(timerState),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _getMessage(timerState),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _getTextColor(timerState),
                  ),
                ),
                if (!timerState.hasExpired) ...[
                  const SizedBox(height: 4),
                  Text(
                    timerState.formattedTime,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _getTimeColor(timerState),
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (timerState.isActive && !timerState.hasExpired)
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _getPulseColor(timerState),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _getPulseColor(timerState).withOpacity(0.5),
                    blurRadius: 6,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Color _getBackgroundColor(CheckoutTimerState state) {
    if (state.hasExpired) {
      return Colors.red.shade50;
    } else if (state.isInCriticalZone) {
      return Colors.red.shade100;
    } else if (state.isInWarningZone) {
      return Colors.orange.shade50;
    } else {
      return Colors.blue.shade50;
    }
  }

  Color _getBorderColor(CheckoutTimerState state) {
    if (state.hasExpired) {
      return Colors.red.shade400;
    } else if (state.isInCriticalZone) {
      return Colors.red.shade500;
    } else if (state.isInWarningZone) {
      return Colors.orange.shade400;
    } else {
      return Colors.blue.shade400;
    }
  }

  Color _getIconColor(CheckoutTimerState state) {
    if (state.hasExpired) {
      return Colors.red.shade700;
    } else if (state.isInCriticalZone) {
      return Colors.red.shade800;
    } else if (state.isInWarningZone) {
      return Colors.orange.shade700;
    } else {
      return Colors.blue.shade700;
    }
  }

  Color _getTextColor(CheckoutTimerState state) {
    if (state.hasExpired) {
      return Colors.red.shade900;
    } else if (state.isInCriticalZone) {
      return Colors.red.shade900;
    } else if (state.isInWarningZone) {
      return Colors.orange.shade900;
    } else {
      return Colors.blue.shade900;
    }
  }

  Color _getTimeColor(CheckoutTimerState state) {
    if (state.hasExpired) {
      return Colors.red.shade800;
    } else if (state.isInCriticalZone) {
      return Colors.red.shade800;
    } else if (state.isInWarningZone) {
      return Colors.orange.shade800;
    } else {
      return Colors.blue.shade800;
    }
  }

  Color _getPulseColor(CheckoutTimerState state) {
    if (state.isInCriticalZone) {
      return Colors.red.shade600;
    } else if (state.isInWarningZone) {
      return Colors.orange.shade600;
    } else {
      return Colors.blue.shade600;
    }
  }

  IconData _getIcon(CheckoutTimerState state) {
    if (state.hasExpired) {
      return Icons.timer_off;
    } else if (state.isInCriticalZone) {
      return Icons.warning;
    } else if (state.isInWarningZone) {
      return Icons.access_time;
    } else {
      return Icons.access_time;
    }
  }

  String _getMessage(CheckoutTimerState state) {
    if (state.hasExpired) {
      return 'Session Expired';
    } else if (state.isInCriticalZone) {
      return 'Time Running Out!';
    } else if (state.isInWarningZone) {
      return 'Hurry! Complete your order';
    } else {
      return 'Finish your order session to grab your deal';
    }
  }
}

// Compact timer for app bar display
class CheckoutTimerCompactWidget extends ConsumerWidget {
  const CheckoutTimerCompactWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timerState = ref.watch(checkoutTimerProvider);

    if (timerState.hasExpired) {
      return IconButton(
        icon: Icon(
          Icons.timer_off,
          color: Colors.red.shade600,
          size: 20,
        ),
        onPressed: () => _showExpiredDialog(context),
        tooltip: 'Session Expired',
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getCompactBackgroundColor(timerState),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getCompactBorderColor(timerState),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.access_time,
            color: _getCompactIconColor(timerState),
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            timerState.formattedTime,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: _getCompactTextColor(timerState),
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }

  Color _getCompactBackgroundColor(CheckoutTimerState state) {
    if (state.isInCriticalZone) {
      return Colors.red.shade100;
    } else if (state.isInWarningZone) {
      return Colors.orange.shade100;
    } else {
      return Colors.blue.shade100;
    }
  }

  Color _getCompactBorderColor(CheckoutTimerState state) {
    if (state.isInCriticalZone) {
      return Colors.red.shade400;
    } else if (state.isInWarningZone) {
      return Colors.orange.shade400;
    } else {
      return Colors.blue.shade400;
    }
  }

  Color _getCompactIconColor(CheckoutTimerState state) {
    if (state.isInCriticalZone) {
      return Colors.red.shade700;
    } else if (state.isInWarningZone) {
      return Colors.orange.shade700;
    } else {
      return Colors.blue.shade700;
    }
  }

  Color _getCompactTextColor(CheckoutTimerState state) {
    if (state.isInCriticalZone) {
      return Colors.red.shade800;
    } else if (state.isInWarningZone) {
      return Colors.orange.shade800;
    } else {
      return Colors.blue.shade800;
    }
  }

  void _showExpiredDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Text(
            'Session Expired',
            style: TextStyle(
              color: Colors.red.shade900,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'Your checkout session has expired. You will be redirected to your cart to continue with your order.',
            style: TextStyle(color: Colors.black87),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Navigation will be handled by the screen
              },
              child: Text(
                'Continue to Cart',
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
