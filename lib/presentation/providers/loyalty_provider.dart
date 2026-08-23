// lib/presentation/providers/loyalty_provider.dart
//
// The customer's loyalty state: dashboard, transaction history, rewards,
// tiers, challenges, referral. Same shape as notifications_provider.dart —
// one refresh-bump StateProvider per logical group, plain FutureProviders
// watching it, mutation Provider<Future<T> Function(...)> closures that bump
// the refresh token on success.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/loyalty_tier_model.dart';
import '../../data/repositories/loyalty_repository.dart';
import '../../data/models/loyalty_reward_model.dart';
import '../../di/repository_providers.dart';
import '../../data/models/loyalty_challenge_model.dart';
import '../../data/models/loyalty_dashboard_model.dart';
import '../../data/models/loyalty_redemption_model.dart';
import '../../data/models/loyalty_transaction_model.dart';

export '../../data/repositories/loyalty_repository.dart' show LoyaltyException;

/// Bumped after any mutation (redeem, claim, apply referral) to force every
/// loyalty provider to refetch — the dashboard's points/rewards/challenges
/// can all change from a single redemption.
final loyaltyRefreshProvider = StateProvider<int>((ref) => 0);

final loyaltyDashboardProvider = FutureProvider<LoyaltyDashboard>((ref) async {
  ref.watch(loyaltyRefreshProvider);
  return ref.read(loyaltyRepositoryProvider).getDashboard();
});

/// Just the points, for cheap places like the home app-bar chip that don't
/// need the rest of the dashboard payload.
final loyaltyPointsProvider = Provider<int>((ref) {
  return ref.watch(loyaltyDashboardProvider).valueOrNull?.availablePoints ?? 0;
});

final loyaltyTransactionsProvider = FutureProvider.autoDispose.family<List<LoyaltyTransaction>, int>((ref, page) async {
  ref.watch(loyaltyRefreshProvider);
  return ref.read(loyaltyRepositoryProvider).getTransactions(page: page);
});

final loyaltyRewardsProvider = FutureProvider<List<LoyaltyReward>>((ref) async {
  ref.watch(loyaltyRefreshProvider);
  return ref.read(loyaltyRepositoryProvider).getRewards();
});

final loyaltyActiveRedemptionsProvider = FutureProvider<List<LoyaltyRedemption>>((ref) async {
  ref.watch(loyaltyRefreshProvider);
  return ref.read(loyaltyRepositoryProvider).getActiveRedemptions();
});

/// Every voucher ever redeemed, any status - backs the "My Coupons" screen.
/// Distinct from loyaltyActiveRedemptionsProvider, which the checkout picker
/// uses and only ever has what's still usable.
final loyaltyAllRedemptionsProvider = FutureProvider<List<LoyaltyRedemption>>((ref) async {
  ref.watch(loyaltyRefreshProvider);
  return ref.read(loyaltyRepositoryProvider).getAllRedemptions();
});

/// The reward voucher the customer picked at checkout, if any. Shared
/// between the payment step's summary card and the "View Order details"
/// bottom sheet in checkout_flow_screen.dart so both agree on what's
/// applied. Cleared on successful order placement (see payment_step.dart) so
/// a stale selection never carries into the next order.
///
/// This is a display-only convenience: the server independently validates
/// and computes the actual discount at place-order time regardless of what
/// the client shows (see utils/orderService.js's loyalty_redemption_id
/// handling) - the client is never the source of truth for the amount.
final selectedLoyaltyRedemptionProvider = StateProvider<LoyaltyRedemption?>((ref) => null);

final loyaltyTiersProvider = FutureProvider<List<LoyaltyTier>>((ref) async {
  return ref.read(loyaltyRepositoryProvider).getTiers();
});

final loyaltyChallengesProvider = FutureProvider<List<LoyaltyChallenge>>((ref) async {
  ref.watch(loyaltyRefreshProvider);
  return ref.read(loyaltyRepositoryProvider).getChallenges();
});

final loyaltyReferralProvider = FutureProvider<LoyaltyReferralSummary>((ref) async {
  ref.watch(loyaltyRefreshProvider);
  return ref.read(loyaltyRepositoryProvider).getReferral();
});

/// Redeems a reward, bumping refresh on success. Returns the new available
/// balance; throws [LoyaltyException] on failure — callers show its message.
final redeemRewardProvider = Provider<Future<int> Function(String rewardId)>((ref) {
  return (String rewardId) async {
    final idempotencyKey = 'redeem_${rewardId}_${DateTime.now().millisecondsSinceEpoch}';
    final balance = await ref.read(loyaltyRepositoryProvider).redeemReward(rewardId, idempotencyKey);
    ref.read(loyaltyRefreshProvider.notifier).state++;
    return balance;
  };
});

final claimChallengeProvider = Provider<Future<int> Function(String challengeId)>((ref) {
  return (String challengeId) async {
    final balance = await ref.read(loyaltyRepositoryProvider).claimChallenge(challengeId);
    ref.read(loyaltyRefreshProvider.notifier).state++;
    return balance;
  };
});

final applyReferralCodeProvider = Provider<Future<void> Function(String code)>((ref) {
  return (String code) async {
    await ref.read(loyaltyRepositoryProvider).applyReferralCode(code);
    ref.read(loyaltyRefreshProvider.notifier).state++;
  };
});
