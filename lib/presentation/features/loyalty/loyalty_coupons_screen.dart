// lib/presentation/features/loyalty/loyalty_coupons_screen.dart
//
// "My Coupons" - every voucher this customer has redeemed points for, any
// status. Distinct from LoyaltyRewardsScreen (the catalog you SPEND points
// on) and from the "Ways to Earn" section on the dashboard (how you EARN
// points in the first place) - this is what you already claimed and either
// still can, or can no longer, use.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/error_widgets.dart';
import '../../providers/loyalty_provider.dart';
import '../../../data/models/loyalty_redemption_model.dart';

class LoyaltyCouponsScreen extends ConsumerWidget {
  const LoyaltyCouponsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final redemptionsAsync = ref.watch(loyaltyAllRedemptionsProvider);

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        title: const Text('My Coupons'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: redemptionsAsync.when(
        data: (redemptions) {
          if (redemptions.isEmpty) {
            return _EmptyState(onBrowseRewards: () => context.push('/loyalty/rewards'));
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.read(loyaltyRefreshProvider.notifier).state++;
              await ref.read(loyaltyAllRedemptionsProvider.future);
            },
            color: AppColors.primary,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: redemptions.length,
              itemBuilder: (context, i) => _CouponCard(redemption: redemptions[i]),
            ),
          );
        },
        loading: () => Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (error, _) => AppErrorWidget(
          errorType: ErrorType.network,
          message: 'Failed to load your coupons: $error',
          onRetry: () => ref.read(loyaltyRefreshProvider.notifier).state++,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onBrowseRewards;
  const _EmptyState({required this.onBrowseRewards});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_activity_outlined, size: 56, color: AppColors.textDisabled),
            const SizedBox(height: 16),
            Text('No coupons yet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 6),
            Text(
              'Redeem points for a reward to get your first coupon.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onBrowseRewards,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              child: const Text('Browse Rewards'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusStyle {
  final Color color;
  final String label;
  const _StatusStyle(this.color, this.label);

  factory _StatusStyle.forStatus(String status) => switch (status) {
        'ACTIVE' => _StatusStyle(AppColors.success, 'Ready to use'),
        'USED' => _StatusStyle(AppColors.textSecondary, 'Used'),
        'EXPIRED' => _StatusStyle(AppColors.error, 'Expired'),
        'CANCELLED' => _StatusStyle(AppColors.error, 'Cancelled'),
        _ => _StatusStyle(AppColors.textSecondary, status),
      };
}

class _CouponCard extends StatelessWidget {
  final LoyaltyRedemption redemption;
  const _CouponCard({required this.redemption});

  String get _valueLabel {
    if (redemption.rewardType == 'PERCENTAGE_DISCOUNT') return '${redemption.discountValue.toStringAsFixed(0)}% OFF';
    if (redemption.rewardType == 'FREE_SHIPPING') return 'Free Shipping';
    return '₹${redemption.discountValue.toStringAsFixed(0)} OFF';
  }

  @override
  Widget build(BuildContext context) {
    final style = _StatusStyle.forStatus(redemption.status);
    final isUsable = redemption.status == 'ACTIVE';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isUsable ? AppColors.success.withOpacity(0.4) : AppColors.borderLight),
      ),
      child: Opacity(
        opacity: isUsable ? 1 : 0.6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(_valueLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: style.color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                  child: Text(style.label, style: TextStyle(color: style.color, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(redemption.rewardName, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            if (redemption.minimumOrderValue > 0)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('Min. order ₹${redemption.minimumOrderValue.toStringAsFixed(0)}', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ),
            const SizedBox(height: 10),
            DottedDivider(color: AppColors.borderLight),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.confirmation_number_outlined, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  redemption.couponCode,
                  style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
                ),
                if (isUsable) ...[
                  const Spacer(),
                  InkWell(
                    onTap: () async {
                      await Clipboard.setData(ClipboardData(text: redemption.couponCode));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coupon code copied')));
                      }
                    },
                    child: Icon(Icons.copy, size: 16, color: AppColors.primary),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text(
              redemption.status == 'USED' && redemption.usedAt != null
                  ? 'Used on ${_formatDate(redemption.usedAt!)}'
                  : redemption.status == 'ACTIVE'
                      ? 'Apply at checkout · Expires ${_formatDate(redemption.expiresAt)}'
                      : 'Expired ${_formatDate(redemption.expiresAt)}',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';
}

/// A light dashed-line divider, evoking a ticket/coupon perforation without
/// pulling in an image asset.
class DottedDivider extends StatelessWidget {
  final Color color;
  const DottedDivider({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final dashCount = (constraints.maxWidth / 6).floor();
        return Row(
          children: List.generate(
            dashCount,
            (_) => Expanded(child: Container(height: 1, color: color, margin: const EdgeInsets.symmetric(horizontal: 1))),
          ),
        );
      },
    );
  }
}
