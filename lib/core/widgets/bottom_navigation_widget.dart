// lib/presentation/widgets/bottom_navigation_widget.dart
import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class BottomNavigationWidget extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const BottomNavigationWidget({
    Key? key,
    required this.currentIndex,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // On some newer Android devices with gesture navigation, SafeArea might report 0 bottom padding 
    // or the system gesture pill might overlap the UI. 
    // We get the system bottom padding and ensure a minimum padding of 14 for safe interaction.
    final double bottomPadding = MediaQuery.of(context).padding.bottom;
    final double effectiveBottomPadding = bottomPadding > 0 ? bottomPadding : 14.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 0,
            blurRadius: 4,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      // Apply the calculated padding at the bottom instead of relying on SafeArea,
      // which can sometimes fail on specific Android OEM implementations
      padding: EdgeInsets.only(bottom: effectiveBottomPadding),
      child: Container(
        height: 64, // Slightly increased from 60 for better touch targets
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(0, Icons.home, 'Home'),
            _buildNavItem(1, Icons.grid_view, 'Category'),
            _buildOrderButton(2),
            _buildNavItem(3, Icons.shopping_bag_outlined, 'Reorder'),
            _buildNavItem(4, Icons.person_outline, 'Account'),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = currentIndex == index;
    final color = isSelected ? AppColors.primary : Colors.grey;
    
    return InkWell(
      onTap: () => onTap(index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: color,
            size: 22,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderButton(int index) {
    return InkWell(
      onTap: () => onTap(index),
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Icon(
            Icons.shopping_cart_outlined,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }
}