// lib/data/models/loyalty_card_model.dart
//
// Everything the membership card (front + back) needs. See GET
// /api/loyalty/card. Entirely backend-driven - the admin panel's
// Loyalty > Tiers (per-tier colors) and Loyalty > Loyalty Card (shared
// content) write every field here; nothing about the card's content or
// color is hardcoded in the app.

class LoyaltyCardBenefit {
  final String icon;
  final String title;
  final String subtitle;

  const LoyaltyCardBenefit({required this.icon, required this.title, required this.subtitle});

  factory LoyaltyCardBenefit.fromJson(Map<String, dynamic> json) {
    return LoyaltyCardBenefit(
      icon: (json['icon'] ?? 'card_giftcard').toString(),
      title: (json['title'] ?? '').toString(),
      subtitle: (json['subtitle'] ?? '').toString(),
    );
  }
}

class LoyaltyCardTier {
  final String code;
  final String name;
  final String cardPrimaryColor;
  final String cardAccentColor;

  const LoyaltyCardTier({
    required this.code,
    required this.name,
    required this.cardPrimaryColor,
    required this.cardAccentColor,
  });

  factory LoyaltyCardTier.fromJson(Map<String, dynamic> json) {
    return LoyaltyCardTier(
      code: (json['code'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      cardPrimaryColor: (json['cardPrimaryColor'] ?? '#1A1A1A').toString(),
      cardAccentColor: (json['cardAccentColor'] ?? '#D4AF37').toString(),
    );
  }
}

class LoyaltyCard {
  final String memberName;
  final String memberNumber;
  final LoyaltyCardTier? tier;

  /// Effective card colors - [tier]'s colors once the customer has one,
  /// else the tenant's configured default (Admin > Loyalty > Loyalty
  /// Card). Always sent by the server (routes/loyalty.js's GET /card), so
  /// these - not a hardcoded color in this app - are what the card widget
  /// should render with.
  final String cardPrimaryColor;
  final String cardAccentColor;

  final String brandTitle;
  final String brandSubtitle;
  final String memberLabel;
  final String thankYouMessage;
  final List<LoyaltyCardBenefit> benefits;
  final String supportPhone;
  final String website;
  final String termsText;

  const LoyaltyCard({
    required this.memberName,
    required this.memberNumber,
    required this.tier,
    required this.cardPrimaryColor,
    required this.cardAccentColor,
    required this.brandTitle,
    required this.brandSubtitle,
    required this.memberLabel,
    required this.thankYouMessage,
    required this.benefits,
    required this.supportPhone,
    required this.website,
    required this.termsText,
  });

  factory LoyaltyCard.fromJson(Map<String, dynamic> json) {
    return LoyaltyCard(
      memberName: (json['memberName'] ?? '').toString(),
      memberNumber: (json['memberNumber'] ?? '').toString(),
      tier: json['tier'] is Map ? LoyaltyCardTier.fromJson(Map<String, dynamic>.from(json['tier'] as Map)) : null,
      // The '#1A1A1A'/'#D4AF37' fallbacks here are only for a malformed or
      // pre-upgrade server response missing the field entirely - the
      // server itself always resolves a real value (tier or tenant
      // default), so this is defensive, not the source of truth.
      cardPrimaryColor: (json['cardPrimaryColor'] ?? '#1A1A1A').toString(),
      cardAccentColor: (json['cardAccentColor'] ?? '#D4AF37').toString(),
      brandTitle: (json['brandTitle'] ?? 'LOYALTY').toString(),
      brandSubtitle: (json['brandSubtitle'] ?? 'MEMBER').toString(),
      memberLabel: (json['memberLabel'] ?? 'LOYAL MEMBER').toString(),
      thankYouMessage: (json['thankYouMessage'] ?? '').toString(),
      benefits: json['benefits'] is List
          ? (json['benefits'] as List).whereType<Map>().map((e) => LoyaltyCardBenefit.fromJson(Map<String, dynamic>.from(e))).toList()
          : const [],
      supportPhone: (json['supportPhone'] ?? '').toString(),
      website: (json['website'] ?? '').toString(),
      termsText: (json['termsText'] ?? '').toString(),
    );
  }
}
