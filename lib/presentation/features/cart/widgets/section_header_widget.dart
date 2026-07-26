// lib/presentation/features/cart/widgets/section_header_widget.dart
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';

class SectionHeaderWidget extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final bool isExpanded;
  final Color? backgroundColor;
  final ValueChanged<bool>? onToggle; // Changed from VoidCallback to ValueChanged<bool>

  const SectionHeaderWidget({
    super.key,
    required this.title,
    this.trailing,
    required this.isExpanded,
    this.backgroundColor,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor ?? Colors.white,
      child: ExpansionTile(
        title: Text(
          title,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: trailing ?? Icon(
          isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
          color: AppColors.textPrimary,
        ),
        initiallyExpanded: isExpanded,
        onExpansionChanged: onToggle, // Now this will match the expected type
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: EdgeInsets.zero,
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        backgroundColor: backgroundColor ?? Colors.white,
        collapsedBackgroundColor: backgroundColor ?? Colors.white,
        children: const [], // No children needed as we're just using this for the header
      ),
    );
  }
}