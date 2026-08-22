// lib/core/widgets/cached_network_image_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constants/app_constants.dart';

class CachedNetworkImageWidget extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final String? cacheKey;
  final Widget? placeholder;
  final Widget? errorWidget;
  final Widget? loadingWidget;
  
  const CachedNetworkImageWidget({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.cacheKey,
    this.placeholder,
    this.errorWidget,
    this.loadingWidget,
  });

  @override
  Widget build(BuildContext context) {
    // If the URL is empty, immediately show fallback
    if (imageUrl.isEmpty) {
      return _buildErrorWidget();
    }
    
    return CachedNetworkImage(
      imageUrl: imageUrl,
      cacheKey: cacheKey,
      width: width,
      height: height,
      fit: fit,
      // Max cache age: 20 hours in seconds
      cacheManager: CacheManager(
        Config(
          'cached_image_manager',
          stalePeriod: const Duration(hours: 20),
          maxNrOfCacheObjects: 200,
        ),
      ),
      placeholder: (context, url) => _buildPlaceholder(),
      errorWidget: (context, url, error) => _buildErrorWidget(),
    );
  }
  
  Widget _buildPlaceholder() {
    // Use custom loadingWidget if provided
    if (loadingWidget != null) return loadingWidget!;
    
    // Use custom placeholder if provided
    if (placeholder != null) return placeholder!;
    
    // Default loading widget
    return Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
  
  Widget _buildErrorWidget() {
    if (errorWidget != null) return errorWidget!;

    final tenantFallback = ApiConstants.fallbackImageUrl;

    // No tenant logo configured (Mobile App > Branding in the admin panel) —
    // go straight to the local icon rather than falling through to another
    // hardcoded remote image.
    if (tenantFallback.isEmpty) {
      return _buildLocalPlaceholder();
    }

    return Image.network(
      tenantFallback,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, __, ___) => _buildLocalPlaceholder(),
    );
  }

  Widget _buildLocalPlaceholder() {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: const Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: Colors.grey,
        ),
      ),
    );
  }
}