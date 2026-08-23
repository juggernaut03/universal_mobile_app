// lib/presentation/features/checkout/widgets/loyalty_reward_picker.dart
//
// "Apply a Reward" — lets the customer pick one of their active loyalty
// vouchers to use on this order. There is no code-entry coupon flow
// anywhere in this app (checked before building this), so this follows the
// same shape as the existing steal-deals offers: a list you tap, not a
// field you type into.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../data/models/loyalty_redemption_model.dart';
import '../../../providers/loyalty_provider.dart';

/// A compact row shown in the order summary: either "Apply a Reward" (tap to
/// open the picker) or the applied voucher with a way to remove it.
class LoyaltyRewardRow extends ConsumerWidget {
  final double orderSubtotal;
  final double deliveryCharges;

  const LoyaltyRewardRow({
    super.key,
    required this.orderSubtotal,
    required this.deliveryCharges,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedLoyaltyRedemptionProvider);
    final activeAsync = ref.watch(loyaltyActiveRedemptionsProvider);
    final hasAny = activeAsync.valueOrNull?.isNotEmpty ?? false;

    if (selected == null) {
      if (!hasAny) return const SizedBox.shrink();
      return InkWell(
        onTap: () => _openPicker(context, ref),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(Icons.card_giftcard, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Apply a reward voucher',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: AppColors.primary),
            ],
          ),
        ),
      );
    }

    final discount = selected.estimateDiscount(orderSubtotal: orderSubtotal, deliveryCharges: deliveryCharges);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(Icons.card_giftcard, size: 16, color: AppColors.success),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(selected.rewardName, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                if (discount == null)
                  Text(
                    'Needs min. order ₹${selected.minimumOrderValue.toStringAsFixed(0)} — won\'t be applied',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
                  ),
              ],
            ),
          ),
          if (discount != null)
            Text(
              '-₹${discount.toStringAsFixed(2)}',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.success, fontWeight: FontWeight.bold),
            ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => ref.read(selectedLoyaltyRedemptionProvider.notifier).state = null,
          ),
        ],
      ),
    );
  }

  void _openPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetContext) => _RewardPickerSheet(orderSubtotal: orderSubtotal, deliveryCharges: deliveryCharges),
    );
  }
}

class _RewardPickerSheet extends ConsumerWidget {
  final double orderSubtotal;
  final double deliveryCharges;
  const _RewardPickerSheet({required this.orderSubtotal, required this.deliveryCharges});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeAsync = ref.watch(loyaltyActiveRedemptionsProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 32,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Text('Your Rewards', style: AppTextStyles.h6),
            const SizedBox(height: 12),
            Flexible(
              child: activeAsync.when(
                data: (redemptions) {
                  if (redemptions.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text('No reward vouchers available', style: TextStyle(color: AppColors.textSecondary)),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: redemptions.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) => _RewardOptionTile(
                      redemption: redemptions[i],
                      orderSubtotal: orderSubtotal,
                      deliveryCharges: deliveryCharges,
                    ),
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text('Failed to load rewards: $error', style: TextStyle(color: AppColors.error)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RewardOptionTile extends ConsumerWidget {
  final LoyaltyRedemption redemption;
  final double orderSubtotal;
  final double deliveryCharges;

  const _RewardOptionTile({required this.redemption, required this.orderSubtotal, required this.deliveryCharges});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final discount = redemption.estimateDiscount(orderSubtotal: orderSubtotal, deliveryCharges: deliveryCharges);
    final eligible = discount != null;

    return ListTile(
      enabled: eligible,
      leading: Icon(Icons.card_giftcard, color: eligible ? AppColors.primary : AppColors.textDisabled),
      title: Text(redemption.rewardName, style: TextStyle(fontWeight: FontWeight.w600, color: eligible ? null : AppColors.textDisabled)),
      subtitle: eligible
          ? null
          : Text('Minimum order ₹${redemption.minimumOrderValue.toStringAsFixed(0)}', style: TextStyle(color: AppColors.error, fontSize: 12)),
      trailing: eligible
          ? Text('-₹${discount.toStringAsFixed(2)}', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold))
          : null,
      onTap: eligible
          ? () {
              ref.read(selectedLoyaltyRedemptionProvider.notifier).state = redemption;
              Navigator.pop(context);
            }
          : null,
    );
  }
}
