// lib/presentation/features/loyalty/loyalty_challenges_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/error_widgets.dart';
import '../../providers/loyalty_provider.dart';
import '../../../data/models/loyalty_challenge_model.dart';

class LoyaltyChallengesScreen extends ConsumerWidget {
  const LoyaltyChallengesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challengesAsync = ref.watch(loyaltyChallengesProvider);

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        title: const Text('Challenges'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: challengesAsync.when(
        data: (challenges) {
          if (challenges.isEmpty) {
            return Center(child: Text('No active challenges right now', style: TextStyle(color: AppColors.textSecondary)));
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.read(loyaltyRefreshProvider.notifier).state++;
              await ref.read(loyaltyChallengesProvider.future);
            },
            color: AppColors.primary,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: challenges.length,
              itemBuilder: (context, i) => _ChallengeCard(challenge: challenges[i]),
            ),
          );
        },
        loading: () => Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (error, _) => AppErrorWidget(
          errorType: ErrorType.network,
          message: 'Failed to load challenges: $error',
          onRetry: () => ref.read(loyaltyRefreshProvider.notifier).state++,
        ),
      ),
    );
  }
}

class _ChallengeCard extends ConsumerWidget {
  final LoyaltyChallenge challenge;
  const _ChallengeCard({required this.challenge});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.borderLight)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flag_rounded, color: AppColors.warning, size: 22),
              const SizedBox(width: 8),
              Expanded(child: Text(challenge.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
              Text('+${challenge.rewardPoints} pts', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          Text(challenge.description, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: challenge.progressFraction,
              minHeight: 8,
              backgroundColor: AppColors.neutral200,
              valueColor: AlwaysStoppedAnimation(challenge.isCompleted ? AppColors.success : AppColors.warning),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${challenge.currentValue} / ${challenge.targetValue}', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              if (challenge.isClaimed)
                Text('Claimed', style: TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w600))
              else if (challenge.isCompleted)
                SizedBox(
                  height: 32,
                  child: ElevatedButton(
                    onPressed: () => _claim(context, ref),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
                    child: const Text('Claim', style: TextStyle(fontSize: 12.5)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _claim(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(claimChallengeProvider)(challenge.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('+${challenge.rewardPoints} points claimed!'), backgroundColor: AppColors.success),
      );
    } on LoyaltyException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: AppColors.error));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not claim: $e'), backgroundColor: AppColors.error));
    }
  }
}
