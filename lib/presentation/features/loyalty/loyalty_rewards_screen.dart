// lib/presentation/features/loyalty/loyalty_rewards_screen.dart
//
// Browse the reward catalog and redeem points. The server validates and
// computes everything (points, eligibility, coupon) — this screen only
// ever displays what it returns; see loyalty_repository.dart's doc comment.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/error_widgets.dart';
import '../../providers/loyalty_provider.dart';
import '../../../data/models/loyalty_reward_model.dart';

class LoyaltyRewardsScreen extends ConsumerWidget {
  const LoyaltyRewardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rewardsAsync = ref.watch(loyaltyRewardsProvider);
    final points = ref.watch(loyaltyPointsProvider);

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        title: const Text('Rewards'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: AppColors.primary,
            child: Text(
              'You have $points points',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
          Expanded(
            child: rewardsAsync.when(
              data: (rewards) => _buildList(context, ref, rewards, points),
              loading: () => Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (error, _) => AppErrorWidget(
                errorType: ErrorType.network,
                message: 'Failed to load rewards: $error',
                onRetry: () => ref.read(loyaltyRefreshProvider.notifier).state++,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, WidgetRef ref, List<LoyaltyReward> rewards, int points) {
    if (rewards.isEmpty) {
      return Center(
        child: Text('No rewards available right now', style: TextStyle(color: AppColors.textSecondary)),
      );
    }
    return RefreshIndicator(
      onRefresh: () async {
        ref.read(loyaltyRefreshProvider.notifier).state++;
        await ref.read(loyaltyRewardsProvider.future);
      },
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: rewards.length,
        itemBuilder: (context, i) => _RewardCard(reward: rewards[i], availablePoints: points),
      ),
    );
  }
}

class _RewardCard extends ConsumerWidget {
  final LoyaltyReward reward;
  final int availablePoints;
  const _RewardCard({required this.reward, required this.availablePoints});

  String get _valueLabel {
    if (reward.type == 'PERCENTAGE_DISCOUNT') return '${reward.discountValue.toStringAsFixed(0)}% OFF';
    if (reward.type == 'FREE_SHIPPING') return 'Free Shipping';
    return '₹${reward.discountValue.toStringAsFixed(0)} OFF';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canAfford = availablePoints >= reward.pointsRequired;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.borderLight)),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primary.withOpacity(0.1)),
            child: Icon(Icons.card_giftcard, color: AppColors.primary, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_valueLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 2),
                if (reward.minimumOrderValue > 0)
                  Text('Min order ₹${reward.minimumOrderValue.toStringAsFixed(0)}', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 4),
                Text('${reward.pointsRequired} points', style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: canAfford ? () => _confirmRedeem(context, ref) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              disabledBackgroundColor: AppColors.neutral200,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            child: Text(
              canAfford ? 'Redeem' : '${reward.pointsRequired - availablePoints} more',
              style: const TextStyle(fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRedeem(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_valueLabel),
        content: Text('Redeem for ${reward.pointsRequired} points?\n\nBalance after: ${availablePoints - reward.pointsRequired} points'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Confirm')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await ref.read(redeemRewardProvider)(reward.id);
      if (!context.mounted) return;
      Navigator.pop(context); // close loading
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Reward Unlocked! 🎉'),
          content: Text('$_valueLabel has been added to your vouchers. You can apply it at checkout.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Great!')),
          ],
        ),
      );
    } on LoyaltyException catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context); // close loading
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: AppColors.error));
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Redemption failed: $e'), backgroundColor: AppColors.error));
    }
  }
}
