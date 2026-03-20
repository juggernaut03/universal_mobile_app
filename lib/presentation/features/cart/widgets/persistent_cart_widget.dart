// lib/presentation/features/cart/widgets/persistent_cart_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:patelmart/core/constants/app_colors.dart';
import 'package:patelmart/presentation/providers/cart_provider.dart';

// Offer slab colors — mapped to AppColors
const Color _offerGreen = AppColors.secondary;
const Color _offerGreenBorder = AppColors.secondaryLight;

class PersistentCartWidget extends ConsumerStatefulWidget {
  const PersistentCartWidget({Key? key}) : super(key: key);

  @override
  ConsumerState<PersistentCartWidget> createState() => _PersistentCartWidgetState();
}

class _PersistentCartWidgetState extends ConsumerState<PersistentCartWidget> {
  void _showOffersBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _OffersBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartItems = ref.watch(cartProvider);
    if (cartItems.isEmpty) return const SizedBox.shrink();

    final cartTotal = ref.watch(cartTotalProvider);
    final totalItems = cartItems.fold(0, (sum, item) => sum + item.quantity);
    final nextOffer = ref.watch(nextOfferSlabProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Offers chip
        _buildOffersChip(),
        const SizedBox(height: 4),
        // Main cart bar
        _buildCartBar(cartTotal, totalItems, nextOffer),
      ],
    );
  }

  Widget _buildOffersChip() {
    return GestureDetector(
      onTap: _showOffersBottomSheet,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primaryLighter.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primaryLight.withOpacity(0.4), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Offers',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.expand_less, size: 16, color: AppColors.primaryDark),
          ],
        ),
      ),
    );
  }

  Widget _buildCartBar(double cartTotal, int totalItems, OfferSlabStatus? nextOffer) {
    return Container(
      margin: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primaryDarker],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              // Offer icon
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.discount_outlined,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              // Offer teaser text
              Expanded(
                child: _buildOfferTeaser(nextOffer),
              ),
              const SizedBox(width: 12),
              // Cart button
              _buildCartButton(totalItems),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOfferTeaser(OfferSlabStatus? nextOffer) {
    if (nextOffer == null) {
      // All offers unlocked
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'All offers unlocked! 🎉',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            'You\'re saving the most!',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 11,
            ),
          ),
        ],
      );
    }

    final discount = nextOffer.slab.discount.toInt();
    final remaining = nextOffer.remaining;
    final remainingStr = remaining.toStringAsFixed(
      remaining.truncateToDouble() == remaining ? 0 : 0,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Unlock extra ₹$discount OFF',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          'Shop for ₹$remainingStr more',
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildCartButton(int totalItems) {
    return GestureDetector(
      onTap: () => context.push('/cart'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shopping_cart_outlined, color: AppColors.primary, size: 18),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Cart',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$totalItems item${totalItems > 1 ? 's' : ''}',
                  style: TextStyle(
                    color: AppColors.primaryLight,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Offers Bottom Sheet ───

class _OffersBottomSheet extends ConsumerWidget {
  const _OffersBottomSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slabs = ref.watch(offerSlabsStatusProvider);
    final cartItems = ref.watch(cartProvider);

    // Auto-close if cart becomes empty
    if (cartItems.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pop();
      });
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.primaryDarker,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.only(top: 16, bottom: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Text(
                  'Offers for you',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primaryDark.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Slab list
          ...List.generate(slabs.length, (index) {
            return _buildSlabRow(slabs, index);
          }),
        ],
      ),
    );
  }

  Widget _buildSlabRow(List<OfferSlabStatus> slabs, int index) {
    final status = slabs[index];
    final isFirst = index == 0;
    final isLast = index == slabs.length - 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Timeline
            SizedBox(
              width: 32,
              child: Column(
                children: [
                  // Top connector line
                  if (!isFirst)
                    Expanded(
                      child: Container(
                        width: 2,
                        color: status.unlocked || status.isNext
                            ? _offerGreen.withOpacity(0.5)
                            : AppColors.primaryDark.withOpacity(0.6),
                      ),
                    )
                  else
                    const Expanded(child: SizedBox()),
                  // Circle icon
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: status.unlocked
                          ? _offerGreen
                          : AppColors.primaryDark.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      status.unlocked ? Icons.lock_open : Icons.lock,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                  // Bottom connector line
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        color: status.unlocked
                            ? _offerGreen.withOpacity(0.5)
                            : AppColors.primaryDark.withOpacity(0.6),
                      ),
                    )
                  else
                    const Expanded(child: SizedBox()),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Card
            Expanded(
              child: _buildSlabCard(status),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlabCard(OfferSlabStatus status) {
    final discount = status.slab.discount.toInt();
    final remaining = status.remaining;
    final remainingStr = remaining.toStringAsFixed(
      remaining.truncateToDouble() == remaining ? 0 : 0,
    );

    Color borderColor;
    Color? cardBgColor;
    if (status.unlocked) {
      borderColor = _offerGreen;
      cardBgColor = _offerGreen.withOpacity(0.08);
    } else if (status.isNext) {
      borderColor = _offerGreenBorder;
      cardBgColor = AppColors.primaryDark;
    } else {
      borderColor = AppColors.primaryDark.withOpacity(0.5);
      cardBgColor = AppColors.primaryDark;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor,
          width: status.isNext ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          // Text content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Unlock extra ₹$discount OFF',
                  style: TextStyle(
                    color: status.unlocked || status.isNext
                        ? Colors.white
                        : Colors.white54,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  status.unlocked
                      ? 'Offer unlocked!'
                      : 'Shop for ₹$remainingStr more',
                  style: TextStyle(
                    color: status.unlocked
                        ? _offerGreen
                        : Colors.white38,
                    fontSize: 12,
                  ),
                ),
                // Progress bar for active slab
                if (status.isNext) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: status.progress,
                      backgroundColor: AppColors.primaryDarker,
                      valueColor: const AlwaysStoppedAnimation<Color>(_offerGreen),
                      minHeight: 4,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: status.unlocked
                  ? _offerGreen.withOpacity(0.15)
                  : AppColors.primaryDark.withOpacity(0.8),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              status.unlocked ? 'Unlocked' : 'Locked',
              style: TextStyle(
                color: status.unlocked ? _offerGreen : AppColors.primaryLight.withOpacity(0.5),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
