// lib/data/repositories/loyalty_repository.dart
//
// Loyalty & Rewards against the universal backend (/api/loyalty/*). The
// server is the sole source of truth for balances, tier, and reward
// eligibility — this repository only ever displays what it returns, never
// computes a balance or discount client-side.

import '../../core/constants/app_constants.dart';
import '../models/loyalty_tier_model.dart';
import '../models/loyalty_reward_model.dart';
import '../models/loyalty_challenge_model.dart';
import '../models/loyalty_dashboard_model.dart';
import '../models/loyalty_redemption_model.dart';
import '../models/loyalty_transaction_model.dart';
import 'base_repository.dart';

/// Thrown for a redeem/claim/apply-code failure that carries a server error
/// code (loyalty_rewards_frd.md section 63) worth showing distinctly, e.g.
/// "You do not have enough points" rather than a generic failure toast.
class LoyaltyException implements Exception {
  final String code;
  final String message;
  const LoyaltyException(this.code, this.message);

  @override
  String toString() => message;
}

class LoyaltyRepository extends BaseRepository {
  LoyaltyRepository({
    required super.authManager,
    required super.apiClient,
    required super.logger,
  });

  Map<String, dynamic>? _asMap(dynamic response) =>
      response is Map<String, dynamic> ? response : null;

  Future<LoyaltyDashboard> getDashboard() async {
    return await makeAuthenticatedRequest<LoyaltyDashboard>(
      () async {
        final response = await getWithAuth(ApiConstants.loyaltyDashboard);
        final map = _asMap(response);
        if (map == null || map['data'] is! Map) {
          logActivity('Unexpected loyalty dashboard response format');
          return LoyaltyDashboard.empty;
        }
        return LoyaltyDashboard.fromJson(Map<String, dynamic>.from(map['data'] as Map));
      },
      onAuthError: () => LoyaltyDashboard.empty,
    ) ?? LoyaltyDashboard.empty;
  }

  Future<List<LoyaltyTransaction>> getTransactions({int page = 1, int limit = 20}) async {
    return await makeAuthenticatedRequest<List<LoyaltyTransaction>>(
      () async {
        final response = await getWithAuth(
          ApiConstants.loyaltyTransactions,
          additionalParams: {'page': '$page', 'limit': '$limit'},
        );
        final map = _asMap(response);
        if (map == null || map['data'] is! List) return <LoyaltyTransaction>[];
        return (map['data'] as List)
            .whereType<Map>()
            .map((e) => LoyaltyTransaction.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      },
      onAuthError: () => <LoyaltyTransaction>[],
    ) ?? <LoyaltyTransaction>[];
  }

  Future<List<LoyaltyReward>> getRewards() async {
    return await makeAuthenticatedRequest<List<LoyaltyReward>>(
      () async {
        final response = await getWithAuth(ApiConstants.loyaltyRewards);
        final map = _asMap(response);
        if (map == null || map['data'] is! List) return <LoyaltyReward>[];
        return (map['data'] as List)
            .whereType<Map>()
            .map((e) => LoyaltyReward.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      },
      onAuthError: () => <LoyaltyReward>[],
    ) ?? <LoyaltyReward>[];
  }

  /// Parses `{success, balance:{availablePoints}}` or `{success:false,
  /// error:{code,message}}` and either returns the new balance or throws
  /// [LoyaltyException] with the server's exact code/message.
  ///
  /// Deliberately bypasses makeAuthenticatedRequest() for this shape of
  /// call: it treats every exception thrown inside its callback — including
  /// an intentional LoyaltyException for an ordinary "insufficient points"
  /// rejection — as an auth failure and calls handleAuthError() (which
  /// forces a token re-validation), which is wrong for a plain business-rule
  /// rejection a shopper will hit constantly just by tapping redeem without
  /// enough points.
  Future<int> _postForBalance(String url, {Map<String, dynamic>? body, required String fallbackCode, required String fallbackMessage}) async {
    if (!await isUserLoggedIn()) {
      throw const LoyaltyException('UNAUTHENTICATED', 'Please sign in again');
    }
    final response = await postWithAuth(url, body: body);
    final map = _asMap(response);
    if (map != null && map['success'] == true) {
      final balance = map['balance'];
      if (balance is Map && balance['availablePoints'] is num) {
        return (balance['availablePoints'] as num).toInt();
      }
      return 0;
    }
    final error = map?['error'];
    if (error is Map) {
      throw LoyaltyException(
        (error['code'] ?? fallbackCode).toString(),
        (error['message'] ?? fallbackMessage).toString(),
      );
    }
    throw LoyaltyException(fallbackCode, fallbackMessage);
  }

  /// Redeems [rewardId] for [idempotencyKey] worth of points. Throws
  /// [LoyaltyException] on a server-reported failure (insufficient points,
  /// reward inactive, etc.) rather than returning a sentinel — the UI needs
  /// the distinct message, not just pass/fail.
  Future<int> redeemReward(String rewardId, String idempotencyKey) {
    return _postForBalance(
      ApiConstants.loyaltyRedeem(rewardId),
      body: {'idempotencyKey': idempotencyKey},
      fallbackCode: 'REDEMPTION_FAILED',
      fallbackMessage: 'Redemption failed',
    );
  }

  /// What discount [redemptionId] would produce against the given cart right
  /// now — server-computed, per loyalty_rewards_frd.md's "backend is always
  /// the source of truth" principle. Used by the checkout reward picker.
  Future<double?> previewRedemptionDiscount(String redemptionId, {required double orderSubtotal, double deliveryCharges = 0}) async {
    return await makeAuthenticatedRequest<double?>(
      () async {
        final response = await postWithAuth(
          ApiConstants.loyaltyRedemptionPreview(redemptionId),
          body: {'orderSubtotal': orderSubtotal, 'deliveryCharges': deliveryCharges},
        );
        final map = _asMap(response);
        final data = map?['data'];
        if (data is Map && data['valid'] == true && data['discountAmount'] is num) {
          return (data['discountAmount'] as num).toDouble();
        }
        return null;
      },
      onAuthError: () => null,
    );
  }

  Future<List<LoyaltyRedemption>> getActiveRedemptions() async {
    return await makeAuthenticatedRequest<List<LoyaltyRedemption>>(
      () async {
        final response = await getWithAuth(ApiConstants.loyaltyActiveRedemptions);
        final map = _asMap(response);
        if (map == null || map['data'] is! List) return <LoyaltyRedemption>[];
        return (map['data'] as List)
            .whereType<Map>()
            .map((e) => LoyaltyRedemption.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      },
      onAuthError: () => <LoyaltyRedemption>[],
    ) ?? <LoyaltyRedemption>[];
  }

  /// Every voucher this customer has ever redeemed, any status - "My
  /// Coupons". Distinct from getActiveRedemptions(), which only has what's
  /// still usable and is what the checkout picker reads from.
  Future<List<LoyaltyRedemption>> getAllRedemptions() async {
    return await makeAuthenticatedRequest<List<LoyaltyRedemption>>(
      () async {
        final response = await getWithAuth(ApiConstants.loyaltyRedemptions);
        final map = _asMap(response);
        if (map == null || map['data'] is! List) return <LoyaltyRedemption>[];
        return (map['data'] as List)
            .whereType<Map>()
            .map((e) => LoyaltyRedemption.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      },
      onAuthError: () => <LoyaltyRedemption>[],
    ) ?? <LoyaltyRedemption>[];
  }

  Future<List<LoyaltyTier>> getTiers() async {
    return await makeAuthenticatedRequest<List<LoyaltyTier>>(
      () async {
        final response = await getWithAuth(ApiConstants.loyaltyTiers);
        final map = _asMap(response);
        if (map == null || map['data'] is! List) return <LoyaltyTier>[];
        return (map['data'] as List)
            .whereType<Map>()
            .map((e) => LoyaltyTier.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      },
      onAuthError: () => <LoyaltyTier>[],
    ) ?? <LoyaltyTier>[];
  }

  Future<List<LoyaltyChallenge>> getChallenges() async {
    return await makeAuthenticatedRequest<List<LoyaltyChallenge>>(
      () async {
        final response = await getWithAuth(ApiConstants.loyaltyChallenges);
        final map = _asMap(response);
        if (map == null || map['data'] is! List) return <LoyaltyChallenge>[];
        return (map['data'] as List)
            .whereType<Map>()
            .map((e) => LoyaltyChallenge.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      },
      onAuthError: () => <LoyaltyChallenge>[],
    ) ?? <LoyaltyChallenge>[];
  }

  Future<int> claimChallenge(String challengeId) {
    return _postForBalance(
      ApiConstants.loyaltyClaimChallenge(challengeId),
      fallbackCode: 'CLAIM_FAILED',
      fallbackMessage: 'Could not claim this challenge',
    );
  }

  Future<void> applyReferralCode(String code) async {
    if (!await isUserLoggedIn()) {
      throw const LoyaltyException('UNAUTHENTICATED', 'Please sign in again');
    }
    final response = await postWithAuth(ApiConstants.loyaltyReferralApply, body: {'referralCode': code});
    final map = _asMap(response);
    if (map != null && map['success'] == true) return;
    final error = map?['error'];
    if (error is Map) {
      throw LoyaltyException(
        (error['code'] ?? 'REFERRAL_INVALID').toString(),
        (error['message'] ?? 'Invalid referral code').toString(),
      );
    }
    throw const LoyaltyException('REFERRAL_INVALID', 'Invalid referral code');
  }

  /// Full referral stats (dashboard only carries the compact summary).
  Future<LoyaltyReferralSummary> getReferral() async {
    return await makeAuthenticatedRequest<LoyaltyReferralSummary>(
      () async {
        final response = await getWithAuth(ApiConstants.loyaltyReferral);
        final map = _asMap(response);
        if (map == null || map['data'] is! Map) {
          return const LoyaltyReferralSummary(code: '', successfulReferrals: null, earnedPoints: null);
        }
        return LoyaltyReferralSummary.fromJson(Map<String, dynamic>.from(map['data'] as Map));
      },
      onAuthError: () => const LoyaltyReferralSummary(code: '', successfulReferrals: null, earnedPoints: null),
    ) ?? const LoyaltyReferralSummary(code: '', successfulReferrals: null, earnedPoints: null);
  }
}
