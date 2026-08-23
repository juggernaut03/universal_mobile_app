// lib/presentation/features/loyalty/widgets/loyalty_membership_card.dart
//
// The physical-style membership card - front (identity) and back
// (benefits/support/terms), flippable on tap. Everything about its content
// and color comes from the backend (GET /api/loyalty/card, itself sourced
// from LoyaltyTier's cardPrimaryColor/cardAccentColor and the admin's
// Loyalty Card settings) - nothing here is hardcoded except the layout
// itself. Deliberately has no QR code.

import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../data/models/loyalty_card_model.dart';

Color _parseHex(String hex, {Color fallback = Colors.black}) {
  var value = hex.trim();
  if (value.isEmpty) return fallback;
  if (value.startsWith('#')) value = value.substring(1);
  if (value.length == 6) value = 'FF$value';
  final parsed = int.tryParse(value, radix: 16);
  return parsed != null ? Color(parsed) : fallback;
}

IconData _iconFor(String name) => switch (name) {
      'card_giftcard' => Icons.card_giftcard_rounded,
      'star' => Icons.star_rounded,
      'local_offer' => Icons.local_offer_rounded,
      'favorite' => Icons.favorite_rounded,
      'bolt' => Icons.bolt_rounded,
      'verified' => Icons.verified_rounded,
      'local_shipping' => Icons.local_shipping_rounded,
      'redeem' => Icons.redeem_rounded,
      'diamond' => Icons.diamond_rounded,
      'workspace_premium' => Icons.workspace_premium_rounded,
      _ => Icons.card_giftcard_rounded,
    };

class LoyaltyMembershipCard extends StatefulWidget {
  final LoyaltyCard card;
  const LoyaltyMembershipCard({super.key, required this.card});

  @override
  State<LoyaltyMembershipCard> createState() => _LoyaltyMembershipCardState();
}

class _LoyaltyMembershipCardState extends State<LoyaltyMembershipCard> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _showingFront = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _flip() {
    if (_controller.isAnimating) return;
    if (_showingFront) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    setState(() => _showingFront = !_showingFront);
  }

  @override
  Widget build(BuildContext context) {
    final primary = _parseHex(widget.card.tier?.cardPrimaryColor ?? '#1A1A1A', fallback: const Color(0xFF1A1A1A));
    final accent = _parseHex(widget.card.tier?.cardAccentColor ?? '#D4AF37', fallback: const Color(0xFFD4AF37));

    return GestureDetector(
      onTap: _flip,
      child: AspectRatio(
        aspectRatio: 1.65,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final angle = _controller.value * math.pi;
            final isBack = angle > math.pi / 2;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0012)
                ..rotateY(angle),
              child: isBack
                  ? Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()..rotateY(math.pi),
                      child: _CardBack(card: widget.card, primary: primary, accent: accent),
                    )
                  : _CardFront(card: widget.card, primary: primary, accent: accent),
            );
          },
        ),
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  final Color primary;
  final Widget child;
  const _CardShell({required this.primary, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primary, Color.lerp(primary, Colors.black, 0.35)!],
        ),
        boxShadow: [BoxShadow(color: primary.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 8))],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _CardFront extends StatelessWidget {
  final LoyaltyCard card;
  final Color primary;
  final Color accent;
  const _CardFront({required this.card, required this.primary, required this.accent});

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      primary: primary,
      child: Stack(
        children: [
          // Diagonal accent sweep, evoking the reference design's gold
          // ribbon without needing an image asset.
          Positioned(
            right: -40,
            top: -40,
            bottom: -40,
            width: 160,
            child: Transform.rotate(
              angle: -0.35,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [accent.withOpacity(0), accent.withOpacity(0.9), accent.withOpacity(0)],
                    stops: const [0.3, 0.5, 0.7],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 14,
            right: 16,
            child: Transform.rotate(
              angle: math.pi / 2,
              child: Icon(Icons.wifi_rounded, color: accent.withOpacity(0.7), size: 22),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.workspace_premium_rounded, color: accent, size: 22),
                    const SizedBox(width: 6),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          card.brandTitle,
                          style: TextStyle(color: accent, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                        ),
                        Text(
                          card.brandSubtitle,
                          style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 9, letterSpacing: 3),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            card.memberName.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                          ),
                          Text(
                            card.memberLabel,
                            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10, letterSpacing: 1),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            card.memberNumber,
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 1.5),
                          ),
                        ],
                      ),
                    ),
                    if (card.tier != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            card.tier!.name.toUpperCase(),
                            style: TextStyle(color: accent, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1),
                          ),
                          Text(
                            'TIER',
                            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 9, letterSpacing: 3),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CardBack extends StatelessWidget {
  final LoyaltyCard card;
  final Color primary;
  final Color accent;
  const _CardBack({required this.card, required this.primary, required this.accent});

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      primary: primary,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (card.thankYouMessage.isNotEmpty)
              Text(
                card.thankYouMessage.toUpperCase(),
                style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1),
              ),
            Divider(color: Colors.white.withOpacity(0.15), height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...card.benefits.map((b) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Icon(_iconFor(b.icon), color: accent, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: '${b.title}  ',
                                        style: TextStyle(color: accent, fontSize: 11.5, fontWeight: FontWeight.w700),
                                      ),
                                      TextSpan(
                                        text: b.subtitle,
                                        style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11),
                                      ),
                                    ],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        )),
                    if (card.supportPhone.isNotEmpty) ...[
                      Divider(color: Colors.white.withOpacity(0.15), height: 8),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.headset_mic_rounded, color: Colors.white.withOpacity(0.8), size: 16),
                          const SizedBox(width: 8),
                          Text(
                            card.supportPhone,
                            style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 11.5),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (card.website.isNotEmpty || card.termsText.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (card.website.isNotEmpty)
                      Flexible(
                        child: Text(
                          card.website,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: primary, fontSize: 10.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                    if (card.termsText.isNotEmpty)
                      Flexible(
                        child: Text(
                          card.termsText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: TextStyle(color: primary.withOpacity(0.85), fontSize: 9.5),
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
}
