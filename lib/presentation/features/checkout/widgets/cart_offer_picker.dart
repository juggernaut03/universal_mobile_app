// lib/presentation/features/checkout/widgets/cart_offer_picker.dart
//
// "Apply an Offer" — cart_discount offers (models/Offer.js), a distinct
// concept from loyalty reward vouchers (loyalty_reward_picker.dart) or
// product-deal "Steal Deals" (single_offer_section_widget.dart). Same
// tap-to-apply shape as both of those: no coupon code entry anywhere in
// this app.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../data/models/cart_offer_model.dart';
import '../../../providers/steal_deals_provider.dart';

/// A compact row shown in the order summary: either "Apply an offer" (tap to
/// open the picker, only shown when at least one unlocked offer exists) or
/// the applied offer with a way to remove it.
class CartOfferRow extends ConsumerWidget {
  const CartOfferRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedCartOfferProvider);
    final offers = ref.watch(cartOffersProvider);
    final hasUnlocked = offers.any((o) => o.unlocked);

    if (selected == null) {
      if (!hasUnlocked) return const SizedBox.shrink();
      return InkWell(
        onTap: () => _openPicker(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(Icons.local_offer, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Apply an offer',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: AppColors.primary),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(Icons.local_offer, size: 16, color: AppColors.success),
          const SizedBox(width: 6),
          Expanded(
            child: Text(selected.title, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
          ),
          Text(
            '-₹${selected.effectiveDiscount.toStringAsFixed(2)}',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.success, fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => ref.read(selectedCartOfferProvider.notifier).state = null,
          ),
        ],
      ),
    );
  }

  void _openPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetContext) => const _OfferPickerSheet(),
    );
  }
}

class _OfferPickerSheet extends ConsumerWidget {
  const _OfferPickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offers = ref.watch(cartOffersProvider);

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
            Text('Available Offers', style: AppTextStyles.h6),
            const SizedBox(height: 12),
            Flexible(
              child: offers.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text('No offers available right now', style: TextStyle(color: AppColors.textSecondary)),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: offers.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) => _OfferOptionTile(offer: offers[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfferOptionTile extends ConsumerWidget {
  final CartOffer offer;
  const _OfferOptionTile({required this.offer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!offer.unlocked) {
      return ListTile(
        enabled: false,
        leading: Icon(Icons.lock_outline, color: AppColors.textDisabled),
        title: Text(offer.title, style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDisabled)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: offer.progress / 100,
                minHeight: 4,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation(AppColors.primary.withOpacity(0.5)),
              ),
            ),
            const SizedBox(height: 4),
            Text('Add ₹${offer.remainingAmount.toStringAsFixed(0)} more to unlock',
                style: TextStyle(color: AppColors.error, fontSize: 12)),
          ],
        ),
      );
    }

    return ListTile(
      leading: Icon(Icons.local_offer, color: AppColors.primary),
      title: Text(offer.title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: offer.description.isNotEmpty ? Text(offer.description) : null,
      trailing: Text(
        '-₹${offer.effectiveDiscount.toStringAsFixed(2)}',
        style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold),
      ),
      onTap: () {
        ref.read(selectedCartOfferProvider.notifier).state = offer;
        Navigator.pop(context);
      },
    );
  }
}
