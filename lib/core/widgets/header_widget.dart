// lib/presentation/widgets/header_widget.dart
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class HeaderWidget extends StatelessWidget {
  final String pincode;
  final VoidCallback onChangeTap;

  const HeaderWidget({
    Key? key,
    required this.pincode,
    required this.onChangeTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0), // Reduced vertical padding
      child: Row(
        children: [
          const Icon(
            Icons.location_on,
            color: Colors.white,
            size: 18, // Slightly smaller icon
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Delivery to: $pincode',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: 15, // Slightly smaller text
              ),
            ),
          ),
          ElevatedButton(
            onPressed: onChangeTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.3), // Increased opacity for better contrast
              foregroundColor: Colors.white,
              elevation: 0, // Remove shadow
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              minimumSize: const Size(10, 30), // Smaller height
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: const Text(
              'Change',
              style: TextStyle(
                fontWeight: FontWeight.w600, // Added weight to make it more visible
              ),
            ),
          ),
        ],
      ),
    );
  }
}