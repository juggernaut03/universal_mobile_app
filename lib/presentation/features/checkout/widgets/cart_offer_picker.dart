// lib/presentation/features/checkout/widgets/cart_offer_picker.dart
//
// "Apply an Offer" — discount offers (models/Offer.js: cart, category /
// brand and buy-X-get-Y discounts), a distinct concept from loyalty reward
// vouchers (loyalty_reward_picker.dart) or product-deal "Steal Deals"
// (single_offer_section_widget.dart). Automatic offers are tap-to-apply;
// coupon-code offers are entered in the sheet's CouponCodeField.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/network/api_client.dart';
import '../../../../data/models/cart_offer_model.dart';
import '../../../../di/service_providers.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/outlet_provider.dart';
import '../../../providers/steal_deals_provider.dart';

/// A compact row shown in the order summary: either "Apply an offer or
/// coupon" (tap to open the picker) or the applied offer with a way to
/// remove it, plus the free-delivery status when a free-delivery offer
/// exists.
class CartOfferRow extends ConsumerWidget {
  const CartOfferRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildOfferRow(context, ref),
        const _FreeDeliveryStatusRow(),
        const _AppliedFreeDeliveryCouponRow(),
      ],
    );
  }

  Widget _buildOfferRow(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedCartOfferProvider);
    final offers = ref.watch(cartOffersProvider);
    final hasUnlocked = offers.any((o) => o.unlocked);

    if (selected == null) {
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
                  hasUnlocked ? 'Apply an offer' : 'Apply an offer or coupon',
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
            child: Text(
              selected.couponCode != null ? '${selected.title} (${selected.couponCode})' : selected.title,
              style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            '-₹${selected.effectiveDiscount.toStringAsFixed(2)}',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.success, fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () {
              ref.read(selectedCartOfferProvider.notifier).state = null;
              if (ref.read(appliedCouponProvider)?.discountOffer != null) {
                ref.read(appliedCouponProvider.notifier).state = null;
              }
            },
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
            const CouponCodeField(),
            const SizedBox(height: 16),
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
            Text(offer.lockedReason ?? 'Add ₹${offer.remainingAmount.toStringAsFixed(0)} more to unlock',
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
        // Picking an automatic offer replaces a discount coupon.
        if (ref.read(appliedCouponProvider)?.discountOffer != null) {
          ref.read(appliedCouponProvider.notifier).state = null;
        }
        Navigator.pop(context);
      },
    );
  }
}

/// Coupon entry: checks the code with POST /api/offers/apply-coupon and, if
/// accepted, applies it — a discount coupon replaces the selected offer, a
/// free-delivery coupon waives the delivery fee.
class CouponCodeField extends ConsumerStatefulWidget {
  const CouponCodeField({super.key});

  @override
  ConsumerState<CouponCodeField> createState() => _CouponCodeFieldState();
}

class _CouponCodeFieldState extends ConsumerState<CouponCodeField> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final code = _controller.text.trim().toUpperCase();
    if (code.isEmpty) return;
    final storeCode = ref.read(selectedOutletProvider).valueOrNull?.storeCode;
    if (storeCode == null || storeCode.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await ref.read(apiServiceProvider).applyCoupon(
            code: code,
            storeCode: storeCode,
            cartTotal: ref.read(cartTotalProvider),
          );
      final coupon = AppliedCoupon.fromJson(code, raw);
      ref.read(appliedCouponProvider.notifier).state = coupon;
      if (coupon.discountOffer != null) {
        ref.read(selectedCartOfferProvider.notifier).state = coupon.discountOffer;
      }
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not apply coupon. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _apply(),
            decoration: InputDecoration(
              hintText: 'Enter coupon code',
              isDense: true,
              errorText: _error,
              errorMaxLines: 2,
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 44,
          child: ElevatedButton(
            onPressed: _loading ? null : _apply,
            child: _loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Apply'),
          ),
        ),
      ],
    );
  }
}

/// "Free delivery applied" once a free-delivery offer applies, or "Add ₹X
/// more for free delivery" while the automatic one is still locked.
class _FreeDeliveryStatusRow extends ConsumerWidget {
  const _FreeDeliveryStatusRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applied = ref.watch(appliedFreeDeliveryOfferProvider);
    final auto = ref.watch(freeDeliveryOfferProvider);
    // A free-delivery coupon has its own row below.
    if (applied != null && applied.couponCode != null) return const SizedBox.shrink();

    final String? text;
    final Color color;
    if (applied != null) {
      text = '${applied.title} — free delivery applied';
      color = AppColors.success;
    } else if (auto != null && !auto.unlocked) {
      text = 'Add ₹${auto.remainingAmount.toStringAsFixed(0)} more for free delivery';
      color = AppColors.textSecondary;
    } else {
      text = null;
      color = AppColors.textSecondary;
    }
    if (text == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.local_shipping_outlined, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: AppTextStyles.bodySmall.copyWith(color: color))),
        ],
      ),
    );
  }
}

class _AppliedFreeDeliveryCouponRow extends ConsumerWidget {
  const _AppliedFreeDeliveryCouponRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coupon = ref.watch(appliedCouponProvider);
    final offer = coupon?.freeDeliveryOffer;
    if (coupon == null || offer == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.local_shipping, size: 16, color: AppColors.success),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '${offer.title} (${coupon.code}) — free delivery',
              style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => ref.read(appliedCouponProvider.notifier).state = null,
          ),
        ],
      ),
    );
  }
}
