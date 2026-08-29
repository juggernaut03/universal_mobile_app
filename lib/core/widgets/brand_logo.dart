// lib/core/widgets/brand_logo.dart
//
// Tenant logo widget: renders the admin-managed logo_url (or
// splash_logo_url) from project-config, falling back to a generic store
// icon so the app still shows something offline / for unconfigured tenants
// — not a bundled brand-specific image, since the same asset ships in every
// tenant's build and would show one tenant's real logo to every other one.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../branding/app_branding.dart';
import '../constants/app_colors.dart';

class BrandLogo extends StatelessWidget {
  final double height;
  final BoxFit fit;

  /// Prefer the splash logo when set (falls back to the regular logo).
  final bool splash;

  /// Color for the fallback icon when no URL is configured or it fails to load.
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

    final iconFallback = Icon(
      Icons.store,
      size: height,
      color: fallbackColor ?? AppColors.primary,
    );

    if (url.isEmpty) return iconFallback;

    return CachedNetworkImage(
      imageUrl: url,
      height: height,
      fit: fit,
      placeholder: (context, _) => SizedBox(height: height),
      errorWidget: (context, _, __) => iconFallback,
    );
  }
}
