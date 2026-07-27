// lib/presentation/features/home/sections/merchandising_sections.dart
//
// The section types added for conversion rather than navigation: urgency
// (flash sale), repeat purchase (buy again), basket-building (free-delivery
// nudge) and reassurance (trust badges).
//
// Each is driven entirely by a feed section, so a merchandiser adds one from
// the panel without an app release.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../data/models/home_feed_models.dart';
import '../../../../data/models/home_feed_mappers.dart';
import '../../../../data/models/product_model.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/delivery_charges_provider.dart';
import '../../../providers/order_history_provider.dart';
import 'countdown_text.dart';
import 'home_product_card.dart';

// ----------------------------------------------------------------------

/// A product rail with a deadline.
///
/// Renders nothing once the window closes: the feed is cached, so a stale
/// campaign would otherwise keep counting down from zero.
class FlashSaleSection extends ConsumerStatefulWidget {
  final HomeSection section;

  const FlashSaleSection({super.key, required this.section});

  @override
  ConsumerState<FlashSaleSection> createState() => _FlashSaleSectionState();
}

class _FlashSaleSectionState extends ConsumerState<FlashSaleSection> {
  bool _expired = false;

  @override
  Widget build(BuildContext context) {
    final section = widget.section;
    final endsAt = section.endsAt;

    if (_expired || (endsAt != null && endsAt.isBefore(DateTime.now()))) {
      return const SizedBox.shrink();
    }

    final products = section.toProducts();
    if (products.isEmpty) return const SizedBox.shrink();

    final label = (section.config['label'] ?? 'Ends in').toString();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(vertical: 12),
      color: homeSectionBackground(section.style.backgroundColor) ?? AppColors.primaryLighter,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    section.title.isNotEmpty ? section.title : 'Flash sale',
                    style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                if (endsAt != null) ...[
                  Icon(Icons.timer_outlined, size: 16, color: AppColors.error),
                  const SizedBox(width: 4),
                  Text('$label ', style: AppTextStyles.bodySmall),
                  CountdownText(
                    endsAt: endsAt,
                    style: AppTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.error,
                    ),
                    // Drop the section the moment it lapses, without waiting
                    // for the next feed refresh.
                    onExpired: () => setState(() => _expired = true),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 250,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: products.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) =>
                  HomeProductCard(product: products[index]),
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------

/// Products from the user's own order history.
///
/// Personalised, so the server sends an empty placeholder and this fills it —
/// which is what keeps the feed itself cacheable.
class BuyAgainSection extends ConsumerWidget {
  final HomeSection section;

  const BuyAgainSection({super.key, required this.section});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(orderHistoryProvider);

    return ordersAsync.maybeWhen(
      data: (orders) {
        // Most recent first, de-duplicated: seeing the same staple three times
        // is worse than a shorter rail.
        final seen = <String>{};
        final products = <ProductModel>[];

        for (final order in orders) {
          for (final item in order.items) {
            final product = item.product;
            if (seen.add(product.pCode)) products.add(product);
            if (products.length >= 12) break;
          }
          if (products.length >= 12) break;
        }

        if (products.isEmpty) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  section.title.isNotEmpty ? section.title : 'Buy again',
                  style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 250,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: products.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) =>
                      HomeProductCard(product: products[index]),
                ),
              ),
            ],
          ),
        );
      },
      // A signed-out or first-time shopper has no history; showing an empty
      // "Buy again" would be worse than showing nothing.
      orElse: () => const SizedBox.shrink(),
    );
  }
}

// ----------------------------------------------------------------------

/// "₹120 more for free delivery" — a basket-size nudge.
class FreeDeliveryProgressSection extends ConsumerWidget {
  final HomeSection section;

  const FreeDeliveryProgressSection({super.key, required this.section});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartTotal = ref.watch(cartTotalProvider);
    final delivery = ref.watch(deliveryChargesProvider);

    // Nothing to nudge toward with an empty cart, and nothing to gain once the
    // threshold is already met.
    if (cartTotal <= 0 || delivery.freeDeliveryEligible) {
      return const SizedBox.shrink();
    }

    final threshold = double.tryParse('${section.config['threshold'] ?? ''}') ?? 0;
    if (threshold <= 0 || cartTotal >= threshold) return const SizedBox.shrink();

    final remaining = threshold - cartTotal;
    final progress = (cartTotal / threshold).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: homeSectionBackground(section.style.backgroundColor) ?? AppColors.successLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_shipping_outlined, size: 18, color: AppColors.success),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  section.title.isNotEmpty
                      ? section.title
                      : 'Add ₹${remaining.toStringAsFixed(0)} more for free delivery',
                  style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.white,
              valueColor: AlwaysStoppedAnimation(AppColors.success),
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------

/// Trust badges. Content is entirely config, so a tenant edits the copy from
/// the panel without any new backend collection.
class UspStripSection extends StatelessWidget {
  final HomeSection section;

  const UspStripSection({super.key, required this.section});

  @override
  Widget build(BuildContext context) {
    final raw = section.config['items'];
    final entries = raw is List ? raw.whereType<Map>().toList() : const [];
    if (entries.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: homeSectionBackground(section.style.backgroundColor),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (final entry in entries)
            Expanded(
              child: Column(
                children: [
                  Icon(Icons.verified_outlined, size: 22, color: AppColors.primary),
                  const SizedBox(height: 4),
                  Text(
                    (entry['label'] ?? '').toString(),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
