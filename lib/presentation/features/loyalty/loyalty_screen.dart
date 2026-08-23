// lib/presentation/features/loyalty/loyalty_screen.dart
//
// Loyalty dashboard: points balance, tier progress, ways to earn, active
// challenges preview, referral summary, recent activity. Matches the FRD's
// dashboard mock (loyalty_rewards_frd.md section 6) as a single screen with
// entry points into the deeper sub-screens.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/error_widgets.dart';
import '../../../data/models/loyalty_dashboard_model.dart';
import '../../../data/models/loyalty_challenge_model.dart';
import '../../../data/models/loyalty_transaction_model.dart';
import '../../../data/models/loyalty_way_to_earn_model.dart';
import '../../providers/loyalty_provider.dart';
import 'widgets/loyalty_membership_card.dart';

class LoyaltyScreen extends ConsumerStatefulWidget {
  const LoyaltyScreen({super.key});

  @override
  ConsumerState<LoyaltyScreen> createState() => _LoyaltyScreenState();
}

class _LoyaltyScreenState extends ConsumerState<LoyaltyScreen> {
  @override
  void initState() {
    super.initState();
    // Points/tier/challenges can change from something that happened
    // entirely server-side (a referred order got delivered, a reward
    // expired) with no in-app action of this shopper's own to trigger a
    // refetch. loyaltyDashboardProvider is a plain (non-autoDispose)
    // FutureProvider, so it stays cached app-wide until something bumps
    // loyaltyRefreshProvider - without this, reopening this screen could
    // keep showing a balance that was correct minutes or hours ago instead
    // of the current one.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(loyaltyRefreshProvider.notifier).state++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(loyaltyDashboardProvider);

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        title: const Text('Loyalty & Rewards'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Transaction history',
            onPressed: () => context.push('/loyalty/transactions'),
          ),
        ],
      ),
      body: dashboardAsync.when(
        data: (dashboard) => _buildBody(context, ref, dashboard),
        loading: () => Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (error, _) => AppErrorWidget(
          errorType: ErrorType.network,
          message: 'Failed to load loyalty dashboard: $error',
          onRetry: () => ref.read(loyaltyRefreshProvider.notifier).state++,
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, LoyaltyDashboard dashboard) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.read(loyaltyRefreshProvider.notifier).state++;
        await ref.read(loyaltyDashboardProvider.future);
      },
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _PointsCard(dashboard: dashboard),
          const SizedBox(height: 16),

          // The physical-style membership card - tap to flip. Fully
          // backend-driven (Admin > Loyalty > Tiers for colors, Admin >
          // Loyalty > Loyalty Card for the shared front/back content), kept
          // as its own provider/section since it can be slower or fail
          // independently of the rest of the dashboard without blocking it.
          Consumer(
            builder: (context, ref, _) {
              final cardAsync = ref.watch(loyaltyCardProvider);
              return cardAsync.when(
                data: (card) => card == null
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: LoyaltyMembershipCard(card: card),
                      ),
                loading: () => const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: AspectRatio(aspectRatio: 1.65, child: Center(child: CircularProgressIndicator())),
                ),
                error: (_, __) => const SizedBox.shrink(),
              );
            },
          ),

          if (dashboard.tier.code != null) ...[
            _TierProgressCard(dashboard: dashboard),
            const SizedBox(height: 16),
          ],

          // How points are EARNED - distinct from the two sections below,
          // which are both about SPENDING points already earned.
          if (dashboard.waysToEarn.isNotEmpty) ...[
            Text('Ways to Earn', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            SizedBox(
              height: 90,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: dashboard.waysToEarn.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) => _WayToEarnCard(way: dashboard.waysToEarn[i]),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // The CATALOG you spend points on - "Rewards". What you get after
          // redeeming one (a usable voucher/coupon) lives on My Coupons,
          // reached from the row just below, not here.
          _SectionHeader(title: 'Rewards', onSeeAll: () => context.push('/loyalty/rewards')),
          const SizedBox(height: 8),
          if (dashboard.rewards.isEmpty)
            _EmptyRow(text: 'No rewards available right now')
          else
            SizedBox(
              height: 130,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: dashboard.rewards.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) => _MiniRewardCard(
                  name: dashboard.rewards[i].name,
                  points: dashboard.rewards[i].pointsRequired,
                  onTap: () => context.push('/loyalty/rewards'),
                ),
              ),
            ),
          const SizedBox(height: 12),

          // What you already claimed by redeeming a reward above - the
          // vouchers/coupons themselves, with codes and expiry, usable at
          // checkout.
          InkWell(
            onTap: () => context.push('/loyalty/coupons'),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.confirmation_number_outlined, color: AppColors.success, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('My Coupons', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  ),
                  Icon(Icons.chevron_right, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _SectionHeader(title: 'Active Challenges', onSeeAll: () => context.push('/loyalty/challenges')),
          const SizedBox(height: 8),
          if (dashboard.challenges.isEmpty)
            _EmptyRow(text: 'No active challenges')
          else
            ...dashboard.challenges.take(2).map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ChallengePreviewCard(challenge: c, onTap: () => context.push('/loyalty/challenges')),
                )),
          const SizedBox(height: 12),
          _ReferralSummaryCard(dashboard: dashboard, onTap: () => context.push('/loyalty/referral')),
          const SizedBox(height: 20),
          _SectionHeader(title: 'Recent Activity', onSeeAll: () => context.push('/loyalty/transactions')),
          const SizedBox(height: 8),
          if (dashboard.recentTransactions.isEmpty)
            _EmptyRow(text: 'No activity yet — start shopping to earn points!')
          else
            ...dashboard.recentTransactions.map((tx) => _TransactionRow(tx: tx)),
        ],
      ),
    );
  }
}

class _PointsCard extends StatelessWidget {
  final LoyaltyDashboard dashboard;
  const _PointsCard({required this.dashboard});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (dashboard.tier.name != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
              child: Text('${dashboard.tier.name} Member', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          const SizedBox(height: 12),
          Text(
            '${dashboard.availablePoints} Points',
            style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold),
          ),
          if (dashboard.pendingPoints > 0) ...[
            const SizedBox(height: 4),
            Text('+${dashboard.pendingPoints} pending', style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13)),
          ],
        ],
      ),
    );
  }
}

class _TierProgressCard extends StatelessWidget {
  final LoyaltyDashboard dashboard;
  const _TierProgressCard({required this.dashboard});

  @override
  Widget build(BuildContext context) {
    final tier = dashboard.tier;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.borderLight)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${tier.multiplier}x Points', style: const TextStyle(fontWeight: FontWeight.w600)),
              if (tier.nextTier != null)
                Text('Next: ${tier.nextTier}', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: tier.progress / 100,
              minHeight: 8,
              backgroundColor: AppColors.neutral200,
              valueColor: AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
          if (tier.nextTierSpend != null) ...[
            const SizedBox(height: 6),
            Text(
              '₹${tier.currentSpend.toStringAsFixed(0)} / ₹${tier.nextTierSpend!.toStringAsFixed(0)} to ${tier.nextTier}',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onSeeAll;
  const _SectionHeader({required this.title, required this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        TextButton(onPressed: onSeeAll, child: const Text('See all')),
      ],
    );
  }
}

class _EmptyRow extends StatelessWidget {
  final String text;
  const _EmptyRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(text, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
    );
  }
}

class _WayToEarnCard extends StatelessWidget {
  final LoyaltyWayToEarn way;
  const _WayToEarnCard({required this.way});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.borderLight)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(way.label, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          Text(way.description, style: TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _MiniRewardCard extends StatelessWidget {
  final String name;
  final int points;
  final VoidCallback onTap;
  const _MiniRewardCard({required this.name, required this.points, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 130,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.borderLight)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(Icons.card_giftcard, color: AppColors.primary, size: 26),
            Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            Text('$points pts', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _ChallengePreviewCard extends StatelessWidget {
  final LoyaltyChallenge challenge;
  final VoidCallback onTap;
  const _ChallengePreviewCard({required this.challenge, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.borderLight)),
        child: Row(
          children: [
            Icon(Icons.flag_rounded, color: AppColors.warning, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(challenge.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: challenge.progressFraction,
                      minHeight: 6,
                      backgroundColor: AppColors.neutral200,
                      valueColor: AlwaysStoppedAnimation(AppColors.warning),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text('+${challenge.rewardPoints}', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _ReferralSummaryCard extends StatelessWidget {
  final LoyaltyDashboard dashboard;
  final VoidCallback onTap;
  const _ReferralSummaryCard({required this.dashboard, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.infoLight, borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            Icon(Icons.card_giftcard_rounded, color: AppColors.info, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Invite Friends', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text('Your code: ${dashboard.referral.code}', style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  final LoyaltyTransaction tx;
  const _TransactionRow({required this.tx});

  @override
  Widget build(BuildContext context) {
    final isCredit = tx.isCredit;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            isCredit ? Icons.add_circle_outline : Icons.remove_circle_outline,
            color: isCredit ? AppColors.success : AppColors.error,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tx.source.replaceAll('_', ' '),
              style: const TextStyle(fontSize: 13.5),
            ),
          ),
          Text(
            '${isCredit ? '+' : '-'}${tx.points}',
            style: TextStyle(color: isCredit ? AppColors.success : AppColors.error, fontWeight: FontWeight.w700, fontSize: 13.5),
          ),
        ],
      ),
    );
  }
}
