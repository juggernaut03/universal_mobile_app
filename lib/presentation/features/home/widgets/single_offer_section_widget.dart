import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../data/models/product_model.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/steal_deals_provider.dart';
import '../../../providers/outlet_status_provider.dart';

/// A single offer section: title + horizontal product card list.
/// Can be placed individually anywhere in the widget tree.
class SingleOfferSectionWidget extends ConsumerWidget {
  final StealDealOffer offer;

  const SingleOfferSectionWidget({super.key, required this.offer});

  Color _parseColor(String hex, Color fallback) {
    try {
      final colorStr = hex.replaceFirst('#', '');
      return Color(int.parse('FF$colorStr', radix: 16));
    } catch (_) {
      return fallback;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isUnlocked = offer.isUnlocked;

    final Color headingBg =
        _parseColor(offer.headingBgColor, Colors.orange.shade700);
    final Color headingTextColor =
        _parseColor(offer.headingTextColor, Colors.black);
    final Color cardBg = _parseColor(offer.cardBgColor, Colors.white);
    final Color unlockedBadge =
        _parseColor(offer.unlockedBadgeColor, AppColors.success);
    final Color lockedBadge =
        _parseColor(offer.lockedBadgeColor, Colors.grey);
    final Color badgeColor = isUnlocked ? unlockedBadge : lockedBadge;
    final IconData headerIcon =
        isUnlocked ? Icons.check_circle_outline : Icons.lock_outline;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section title: offer_heading_text ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Text(
            offer.offerHeadingText,
            style: AppTextStyles.h5.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),

        // ── Product cards — each is a wide steal-deal style card ──
        SizedBox(
          height: 210,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: offer.products.length,
            itemBuilder: (context, index) {
              return _OfferProductCard(
                product: offer.products[index],
                offer: offer,
                isUnlocked: isUnlocked,
                headingBg: headingBg,
                headingTextColor: headingTextColor,
                cardBg: cardBg,
                badgeColor: badgeColor,
                headerIcon: headerIcon,
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _OfferProductCard extends ConsumerStatefulWidget {
  final ProductModel product;
  final StealDealOffer offer;
  final bool isUnlocked;
  final Color headingBg;
  final Color headingTextColor;
  final Color cardBg;
  final Color badgeColor;
  final IconData headerIcon;

  const _OfferProductCard({
    required this.product,
    required this.offer,
    required this.isUnlocked,
    required this.headingBg,
    required this.headingTextColor,
    required this.cardBg,
    required this.badgeColor,
    required this.headerIcon,
  });

  @override
  ConsumerState<_OfferProductCard> createState() => _OfferProductCardState();
}

class _OfferProductCardState extends ConsumerState<_OfferProductCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  bool _wasInCart = false;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _flipController,
        curve: Curves.easeInOutCubic,
      ),
    );
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  String _formatPrice(double price) {
    return price.truncateToDouble() == price
        ? price.toInt().toString()
        : price.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = screenWidth * 0.68;

    final cartItems = ref.watch(cartProvider);
    final cartItem = cartItems
        .where((item) => item.product.pCode == widget.product.pCode)
        .toList();
    final bool isInCart = cartItem.isNotEmpty;
    final isCartEnabled = ref.watch(isCartEnabledProvider);

    // Trigger flip when product is added to cart (unlocked offer)
    if (widget.isUnlocked && isInCart && !_wasInCart) {
      _wasInCart = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) _flipController.forward();
        });
      });
    }
    // Flip back when product is removed from cart
    if (_wasInCart && !isInCart) {
      _wasInCart = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _flipController.reverse();
      });
    }

    return AnimatedBuilder(
      animation: _flipAnimation,
      builder: (context, child) {
        final angle = _flipAnimation.value * 3.14159;
        final isBack = _flipAnimation.value >= 0.5;

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0008)
            ..rotateY(angle),
          child: isBack
              ? Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..rotateY(3.14159),
                  child: _buildClaimedCard(cardWidth),
                )
              : _buildFrontCard(context, cardWidth, isInCart, isCartEnabled),
        );
      },
    );
  }

  Color _parseHexColor(String hex, Color fallback) {
    try {
      final colorStr = hex.replaceFirst('#', '');
      return Color(int.parse('FF$colorStr', radix: 16));
    } catch (_) {
      return fallback;
    }
  }

  Widget _buildClaimedCard(double cardWidth) {
    final claimBg = widget.offer.claimBgColor.isNotEmpty
        ? _parseHexColor(widget.offer.claimBgColor, AppColors.success)
        : AppColors.success;

    return Container(
      width: cardWidth,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: claimBg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Offer Claimed!',
            style: AppTextStyles.bodyMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              widget.product.productName,
              style: AppTextStyles.labelSmall.copyWith(
                color: Colors.white.withOpacity(0.85),
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFrontCard(
      BuildContext context, double cardWidth, bool isInCart, bool isCartEnabled) {
    return GestureDetector(
      onTap: () => context.push('/product/${widget.product.pCode}'),
      child: Container(
        width: cardWidth,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: widget.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: widget.headingBg,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Icon(widget.headerIcon, color: widget.badgeColor, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.offer.offerConditionText,
                      style: AppTextStyles.labelLarge.copyWith(
                        color: widget.headingTextColor,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: widget.badgeColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.offer.offerStatus,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Body: image left, details right ──
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: cardWidth * 0.38,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: _buildProductImage(
                                widget.product, cardWidth * 0.38),
                          ),
                          if (widget.isUnlocked && !isInCart)
                            Positioned(
                              bottom: -4,
                              right: -4,
                              child: _buildAddButton(
                                  ref, widget.product, isCartEnabled),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Text(
                              '${widget.product.packageSize % 1 == 0 ? widget.product.packageSize.toInt() : widget.product.packageSize} ${widget.product.packageUnit}',
                              style: AppTextStyles.labelMedium.copyWith(
                                color: AppColors.neutral700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.product.productName,
                            style: AppTextStyles.bodySmall.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Price row ──
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '₹${_formatPrice(widget.product.ourPrice)}',
                      style: AppTextStyles.h6.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '₹${_formatPrice(widget.product.productMrp)}',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.neutral500,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductImage(ProductModel product, double size) {
    if (product.pcodeImg.isNotEmpty &&
        product.pcodeImg != 'null' &&
        product.pcodeImg.toLowerCase() != 'null') {
      return Image.network(
        product.pcodeImg,
        width: size,
        height: size,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: size,
            height: size,
            color: Colors.grey[100],
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) =>
            _buildFallbackImage(size),
      );
    }
    return _buildFallbackImage(size);
  }

  Widget _buildFallbackImage(double size) {
    return Image.network(
      ApiConstants.fallbackImageUrl,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => Container(
        width: size,
        height: size,
        color: Colors.grey[100],
        child: Icon(
          Icons.shopping_bag_outlined,
          color: AppColors.primary.withOpacity(0.5),
          size: 32,
        ),
      ),
    );
  }

  Widget _buildAddButton(
      WidgetRef ref, ProductModel product, bool isCartEnabled) {
    return GestureDetector(
      onTap: isCartEnabled
          ? () => ref.read(cartProvider.notifier).addItem(product)
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isCartEnabled ? AppColors.primary : Colors.grey.shade300,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Text(
          'Add',
          style: TextStyle(
            color: isCartEnabled ? AppColors.primary : Colors.grey.shade400,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
