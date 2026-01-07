// lib/presentation/features/cart/widgets/cart_validation_dialog.dart
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../data/services/cart_validator.dart';

class CartValidationDialog extends StatelessWidget {
  final CartValidationResult result;
  final VoidCallback onContinue;
  final VoidCallback onUpdateCart;

  const CartValidationDialog({
    Key? key,
    required this.result,
    required this.onContinue,
    required this.onUpdateCart,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Debug print to verify dialog is being built
    print('Building CartValidationDialog with ${result.removedItems.length} removed items, '
          '${result.priceChangedItems.length} price changes, and ${result.itemsWithIssues.length} items with issues');
    print('Cart validation message: "${result.validationMessage}"');
    print('Is save error: ${result.isSaveError}');

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Dialog Header with warning icon
              Row(
                children: [
                 
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Quick Update",
                      style: AppTextStyles.h5.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              
              const Divider(height: 24),
              
              // Warning box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        " Please update your cart to continue ",
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w500,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Explanation text
              Text(
                "Some items price, quantity or stock may have changed.Please check",
                style: AppTextStyles.bodyMedium,
              ),
              
              const SizedBox(height: 16),
              
              // List specific issues
              
              // 1. Price changes
              if (result.priceChangedItems.isNotEmpty)
                _buildIssueList(
                  "Price changes detected:",
                  result.priceChangedItems.map((item) =>
                    "${item.product.productName}: ₹${item.oldPrice.toStringAsFixed(item.oldPrice.truncateToDouble() == item.oldPrice ? 0 : 2)} → ₹${item.newPrice.toStringAsFixed(item.newPrice.truncateToDouble() == item.newPrice ? 0 : 2)}"
                  ).toList()
                ),
                
              // 2. Out-of-stock items
              if (result.removedItems.isNotEmpty)
                _buildIssueList(
                  "Items out of stock:", 
                  result.removedItems.map((item) => 
                    "${item.product.productName}"
                  ).toList()
                ),
                
              // 3. Other issues
              if (result.itemsWithIssues.isNotEmpty)
                _buildIssueList(
                  "Update", 
                  result.itemsWithIssues.map((item) => 
                    "${item.product.productName}: ${item.issue}"
                  ).toList()
                ),
                
              // If no specific issues are listed but cart is invalid
              if (result.removedItems.isEmpty && 
                  result.priceChangedItems.isEmpty && 
                  result.itemsWithIssues.isEmpty && 
                  !result.isValid)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    " Clicking 'UPDATE CART' will refresh your cart with the latest information.",
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                
              const SizedBox(height: 8),
              
              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onUpdateCart,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text("UPDATE CART"),
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  Expanded(
                    child: ElevatedButton(
                      onPressed: null, // Always disabled
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[300],
                        foregroundColor: Colors.grey[600],
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text("REQUIRED"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildIssueList(String title, List<String> issues) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...issues.map((issue) => Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("• ", style: TextStyle(fontWeight: FontWeight.bold)),
              Expanded(child: Text(issue)),
            ],
          ),
        )),
        const SizedBox(height: 16),
      ],
    );
  }
}