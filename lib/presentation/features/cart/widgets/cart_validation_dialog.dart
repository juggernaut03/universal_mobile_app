// lib/presentation/features/cart/widgets/cart_validation_dialog.dart
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../data/services/cart_validator.dart';
import 'package:flutter/foundation.dart';

class CartValidationDialog extends StatelessWidget {
  final CartValidationResult result;
  final VoidCallback onContinue;
  final VoidCallback onUpdateCart;

  const CartValidationDialog({
    super.key,
    required this.result,
    required this.onContinue,
    required this.onUpdateCart,
  });

  @override
  Widget build(BuildContext context) {
    // Debug print to verify dialog is being built
    if (kDebugMode) {
      print('Building CartValidationDialog with ${result.removedItems.length} removed items, '
          '${result.priceChangedItems.length} price changes, and ${result.itemsWithIssues.length} items with issues');
    }
    if (kDebugMode) print('Cart validation message: "${result.validationMessage}"');
    if (kDebugMode) print('Is save error: ${result.isSaveError}');

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
                    "${item.product.productName}: ₹${_money(item.oldPrice)} → ₹${_money(item.newPrice)}"
                  ).toList()
                ),

              // 2. Quantity caps (stock ran low, or per-order limit hit).
              //
              // This is the single most common validation failure, and it used
              // to render nothing at all — the dialog listed only the three
              // buckets below, so a capped item produced an empty dialog with
              // no way to tell which product was at fault.
              if (result.quantityChangedItems.isNotEmpty)
                _buildIssueList(
                  "Quantity updated:",
                  result.quantityChangedItems.map((item) =>
                    "${item.product.productName}: ${item.oldQuantity} → ${item.newQuantity}"
                    "${item.reason.isNotEmpty ? " (${item.reason})" : ""}"
                  ).toList()
                ),

              // 3. Out-of-stock items
              if (result.removedItems.isNotEmpty)
                _buildIssueList(
                  "Items out of stock:",
                  result.removedItems.map((item) =>
                    item.product.productName
                  ).toList()
                ),

              // 4. Other issues
              if (result.itemsWithIssues.isNotEmpty)
                _buildIssueList(
                  "Update",
                  result.itemsWithIssues.map((item) =>
                    "${item.product.productName}: ${item.issue}"
                  ).toList()
                ),

              // If no specific issues are listed but cart is invalid
              if (!_hasItemisedChanges && !result.isValid)
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

                  // The second action. This was hardcoded to `onPressed: null`
                  // and labelled "REQUIRED", which left UPDATE CART as the only
                  // live control on a barrier-dismissible:false dialog — so a
                  // shopper whose cart could not be auto-fixed had no way out
                  // of the dialog at all.
                  //
                  // `onContinue` decides what happens: it proceeds to checkout
                  // when the server called the cart valid (a price change alone
                  // is valid), and otherwise just closes and asks the shopper to
                  // adjust the cart by hand.
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onContinue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: result.isValid
                            ? AppColors.primary
                            : Colors.grey[200],
                        foregroundColor: result.isValid
                            ? Colors.white
                            : Colors.black87,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(result.isValid ? "CONTINUE" : "CANCEL"),
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
  
  /// True when at least one bucket renders a line, so the generic
  /// "we'll refresh your cart" fallback only appears when there really is
  /// nothing itemised to show.
  bool get _hasItemisedChanges =>
      result.priceChangedItems.isNotEmpty ||
      result.quantityChangedItems.isNotEmpty ||
      result.removedItems.isNotEmpty ||
      result.itemsWithIssues.isNotEmpty;

  /// Drop the decimals on whole-rupee amounts, keep two otherwise.
  static String _money(double value) =>
      value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2);

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