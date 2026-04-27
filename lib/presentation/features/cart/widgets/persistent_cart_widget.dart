// lib/presentation/features/cart/widgets/persistent_cart_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:patelmart/core/constants/app_colors.dart';
import 'package:patelmart/presentation/providers/cart_provider.dart';
import 'package:patelmart/presentation/providers/steal_deals_provider.dart';

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
    final hasOffers = ref.watch(offerSlabsProvider).isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Offers chip — only show when offers exist
        if (hasOffers) ...[
          _buildOffersChip(),
          const SizedBox(height: 4),
        ],
        // Main cart bar
        _buildCartBar(cartTotal, totalItems, hasOffers ? nextOffer : null, hasOffers),
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

  Widget _buildCartBar(double cartTotal, int totalItems, OfferSlabStatus? nextOffer, bool hasOffers) {
    if (!hasOffers) {
      return _buildSimpleCartBar(cartTotal, totalItems);
    }
    return _buildOfferCartBar(totalItems, nextOffer);
  }

  // No-offers layout: cart icon + total/savings info + CART button
  Widget _buildSimpleCartBar(double cartTotal, int totalItems) {
    final savings = ref.watch(cartSavingsProvider);
    return GestureDetector(
      onTap: () => context.push('/cart'),
      child: Container(
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              // Cart icon with item badge
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.shopping_cart_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$totalItems',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              // Cart total + savings
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '₹${cartTotal.toStringAsFixed(0)} Cart Total',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$totalItems Item${totalItems > 1 ? 's' : ''}${savings > 0 ? ' • ₹${savings.toStringAsFixed(0)} Saved' : ''}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // CART button
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'CART',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right, color: AppColors.primary, size: 18),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // With-offers layout: discount icon + offer teaser + cart button
  Widget _buildOfferCartBar(int totalItems, OfferSlabStatus? nextOffer) {
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
                child: _buildOfferTeaser(nextOffer, true),
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

  Widget _buildOfferTeaser(OfferSlabStatus? nextOffer, bool hasOffers) {
    if (nextOffer == null) {
      if (!hasOffers) {
        // No offers from backend — show nothing
        return const SizedBox.shrink();
      }
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

    // Use API texts
    final headingText = nextOffer.slab.offerHeadingText;
    final conditionText = nextOffer.slab.offerConditionText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          headingText.isNotEmpty ? headingText : 'Unlock next offer',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          conditionText.isNotEmpty ? conditionText : 'Add more to unlock',
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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
    final panelColors = ref.watch(offerPanelColorsProvider);

    // Auto-close if cart becomes empty
    if (cartItems.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pop();
      });
      return const SizedBox.shrink();
    }

    // Panel colors from API
    final Color panelBg = panelColors.bgColor.isNotEmpty
        ? _parseColor(panelColors.bgColor, AppColors.primaryDarker)
        : AppColors.primaryDarker;
    final Color headingColor = panelColors.headingTxtColor.isNotEmpty
        ? _parseColor(panelColors.headingTxtColor, Colors.white)
        : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: panelBg,
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
                Text(
                  'Offers for you',
                  style: TextStyle(
                    color: headingColor,
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
                      color: panelBg.withOpacity(0.5),
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
            return _buildSlabRow(slabs, index, panelColors);
          }),
        ],
      ),
    );
  }

  Widget _buildSlabRow(
      List<OfferSlabStatus> slabs, int index, OfferPanelColors panelColors) {
    final status = slabs[index];
    final isFirst = index == 0;
    final isLast = index == slabs.length - 1;

    // Unlock bg color from API panel
    final Color unlockBg = panelColors.unlockBgColor.isNotEmpty
        ? _parseColor(panelColors.unlockBgColor, _offerGreen)
        : _offerGreen;

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
                            ? unlockBg.withOpacity(0.5)
                            : Colors.white.withOpacity(0.2),
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
                          ? unlockBg
                          : Colors.white.withOpacity(0.2),
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
                            ? unlockBg.withOpacity(0.5)
                            : Colors.white.withOpacity(0.2),
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
              child: _buildSlabCard(status, panelColors),
            ),
          ],
        ),
      ),
    );
  }

  Color _parseColor(String hex, Color fallback) {
    try {
      final colorStr = hex.replaceFirst('#', '');
      return Color(int.parse('FF$colorStr', radix: 16));
    } catch (_) {
      return fallback;
    }
  }

  Widget _buildSlabCard(OfferSlabStatus status, OfferPanelColors panelColors) {
    // API-driven texts
    final headingText = status.slab.offerHeadingText;
    final conditionText = status.slab.offerConditionText;

    // Panel text colors
    final Color descriptColor = panelColors.descriptTxtColor.isNotEmpty
        ? _parseColor(panelColors.descriptTxtColor, Colors.white)
        : Colors.white;
    final Color unlockTxtColor = panelColors.unlockTxtColor.isNotEmpty
        ? _parseColor(panelColors.unlockTxtColor, Colors.white)
        : Colors.white;
    final Color unlockBg = panelColors.unlockBgColor.isNotEmpty
        ? _parseColor(panelColors.unlockBgColor, _offerGreen)
        : _offerGreen;

    // API-driven progress bar fill color
    final progressColor =
        _parseColor(status.slab.progressFillColor, _offerGreen);

    Color borderColor;
    Color? cardBgColor;
    if (status.unlocked) {
      borderColor = unlockBg;
      cardBgColor = unlockBg.withOpacity(0.08);
    } else if (status.isNext) {
      borderColor = unlockBg.withOpacity(0.6);
      cardBgColor = Colors.white.withOpacity(0.08);
    } else {
      borderColor = Colors.white.withOpacity(0.15);
      cardBgColor = Colors.white.withOpacity(0.05);
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
                // offer_heading_text from API
                Text(
                  headingText.isNotEmpty ? headingText : 'Offer',
                  style: TextStyle(
                    color: status.unlocked || status.isNext
                        ? descriptColor
                        : descriptColor.withOpacity(0.5),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                // offer_condition_text from API
                Text(
                  status.unlocked
                      ? 'Offer unlocked!'
                      : conditionText.isNotEmpty
                          ? conditionText
                          : 'Add more to unlock',
                  style: TextStyle(
                    color: status.unlocked
                        ? unlockBg
                        : descriptColor.withOpacity(0.4),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                // Progress bar with offer_progress_fill_color from API
                if (status.isNext) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: status.progress,
                      backgroundColor: Colors.white.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(progressColor),
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
                  ? unlockBg.withOpacity(0.15)
                  : Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              status.slab.offerStatus.isNotEmpty
                  ? status.slab.offerStatus
                  : (status.unlocked ? 'Unlocked' : 'Locked'),
              style: TextStyle(
                color: status.unlocked
                    ? unlockTxtColor
                    : descriptColor.withOpacity(0.5),
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
