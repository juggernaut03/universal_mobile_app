// lib/core/widgets/brand_logo.dart
//
// Tenant logo widget: renders the admin-managed logo_url (or
// splash_logo_url) from project-config, falling back to the bundled asset
// so the app still shows something offline / for unconfigured tenants.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../branding/app_branding.dart';
import '../constants/app_colors.dart';

class BrandLogo extends StatelessWidget {
  final double height;
  final BoxFit fit;

  /// Prefer the splash logo when set (falls back to the regular logo).
  final bool splash;

  /// Color for the fallback icon when neither URL nor asset can render.
  final Color? fallbackColor;

  const BrandLogo({
    super.key,
    required this.height,
    this.fit = BoxFit.contain,
    this.splash = false,
    this.fallbackColor,
  });

  @override
  Widget build(BuildContext context) {
    final branding = AppBranding.instance;
    final url = splash && branding.splashLogoUrl.isNotEmpty
        ? branding.splashLogoUrl
        : branding.logoUrl;

    final assetFallback = Image.asset(
      'assets/images/patelLogo.png',
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => Icon(
        Icons.store,
        size: height,
        color: fallbackColor ?? AppColors.primary,
      ),
    );

    if (url.isEmpty) return assetFallback;

    return CachedNetworkImage(
      imageUrl: url,
      height: height,
      fit: fit,
      placeholder: (context, _) => SizedBox(height: height),
      errorWidget: (context, _, __) => assetFallback,
    );
  }
}
