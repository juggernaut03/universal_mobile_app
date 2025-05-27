// lib/core/utils/scroll_performance_utils.dart

import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Utility class for optimizing scroll performance
class ScrollPerformanceUtils {
  
  /// Creates an optimized scroll controller with performance settings
  static ScrollController createOptimizedScrollController({
    double initialScrollOffset = 0.0,
    bool keepScrollOffset = true,
    String? debugLabel,
  }) {
    return ScrollController(
      initialScrollOffset: initialScrollOffset,
      keepScrollOffset: keepScrollOffset,
      debugLabel: debugLabel,
    );
  }

  /// Debounces scroll events to prevent excessive rebuilds
  static void addDebouncedScrollListener(
    ScrollController controller,
    VoidCallback callback, {
    Duration debounceTime = const Duration(milliseconds: 16), // ~60fps
  }) {
    DateTime? lastCallTime;
    
    controller.addListener(() {
      final now = DateTime.now();
      if (lastCallTime == null || 
          now.difference(lastCallTime!) > debounceTime) {
        lastCallTime = now;
        callback();
      }
    });
  }

  /// Calculates if a widget should be rebuilt based on scroll position
  static bool shouldRebuildOnScroll(
    double currentOffset,
    double previousOffset,
    double threshold,
  ) {
    return (currentOffset - previousOffset).abs() > threshold;
  }

  /// Optimized scroll animation with better performance
  static Future<void> animateToOffset(
    ScrollController controller,
    double offset, {
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.fastOutSlowIn,
  }) async {
    if (!controller.hasClients) return;
    
    await controller.animateTo(
      math.max(0, math.min(offset, controller.position.maxScrollExtent)),
      duration: duration,
      curve: curve,
    );
  }

  /// Creates a performance-optimized sliver list
  static Widget createOptimizedSliverList({
    required int itemCount,
    required Widget Function(BuildContext, int) itemBuilder,
    double? itemExtent,
    bool addSemanticIndexes = true,
    int? semanticChildCount,
  }) {
    if (itemExtent != null) {
      return SliverFixedExtentList(
        itemExtent: itemExtent,
        delegate: SliverChildBuilderDelegate(
          itemBuilder,
          childCount: itemCount,
          addSemanticIndexes: addSemanticIndexes,
          semanticIndexOffset: 0,
        ),
      );
    }
    
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        itemBuilder,
        childCount: itemCount,
        addSemanticIndexes: addSemanticIndexes,
        semanticIndexOffset: 0,
      ),
    );
  }
}

/// Widget that wraps content with performance optimizations
class PerformanceOptimizedWidget extends StatelessWidget {
  final Widget child;
  final bool repaintBoundary;
  final bool keepAlive;
  final String? debugLabel;

  const PerformanceOptimizedWidget({
    Key? key,
    required this.child,
    this.repaintBoundary = true,
    this.keepAlive = false,
    this.debugLabel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget result = child;

    if (repaintBoundary) {
      result = RepaintBoundary(child: result);
    }

    if (keepAlive) {
      result = _KeepAliveWrapper(child: result);
    }

    return result;
  }
}

class _KeepAliveWrapper extends StatefulWidget {
  final Widget child;

  const _KeepAliveWrapper({required this.child});

  @override
  State<_KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<_KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

/// Optimized scroll physics for better performance
class OptimizedScrollPhysics extends ClampingScrollPhysics {
  const OptimizedScrollPhysics({ScrollPhysics? parent}) : super(parent: parent);

  @override
  OptimizedScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return OptimizedScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double get dragStartDistanceMotionThreshold => 3.5;

  @override
  double get minFlingVelocity => 50.0;

  @override
  double get maxFlingVelocity => 8000.0;
}

/// Memory-efficient image loading for lists
class OptimizedImageWidget extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  const OptimizedImageWidget({
    Key? key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: fit,
      // Optimize for memory
      cacheWidth: width?.round(),
      cacheHeight: height?.round(),
      // Reduce memory usage
      filterQuality: FilterQuality.low,
      // Performance settings
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return placeholder ?? 
          SizedBox(
            width: width,
            height: height,
            child: const Center(child: CircularProgressIndicator()),
          );
      },
      errorBuilder: (context, error, stackTrace) {
        return errorWidget ?? 
          Container(
            width: width,
            height: height,
            color: Colors.grey[300],
            child: const Icon(Icons.error),
          );
      },
    );
  }
}

/// Viewport-aware widget builder for better performance
class ViewportAwareBuilder extends StatefulWidget {
  final Widget Function(BuildContext context, bool isInViewport) builder;
  final double threshold;

  const ViewportAwareBuilder({
    Key? key,
    required this.builder,
    this.threshold = 0.1,
  }) : super(key: key);

  @override
  State<ViewportAwareBuilder> createState() => _ViewportAwareBuilderState();
}

class _ViewportAwareBuilderState extends State<ViewportAwareBuilder> {
  bool _isInViewport = false;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        final renderObject = context.findRenderObject() as RenderBox?;
        if (renderObject == null) return false;

        final viewport = notification.metrics.viewportDimension;
        final position = renderObject.localToGlobal(Offset.zero);
        final size = renderObject.size;

        final isVisible = position.dy < viewport && 
                         position.dy + size.height > 0;

        if (isVisible != _isInViewport) {
          setState(() {
            _isInViewport = isVisible;
          });
        }

        return false;
      },
      child: widget.builder(context, _isInViewport),
    );
  }
}

/// Lazy loading widget for better scroll performance
class LazyLoadingWidget extends StatefulWidget {
  final Widget child;
  final Widget placeholder;
  final double triggerOffset;

  const LazyLoadingWidget({
    Key? key,
    required this.child,
    required this.placeholder,
    this.triggerOffset = 200.0,
  }) : super(key: key);

  @override
  State<LazyLoadingWidget> createState() => _LazyLoadingWidgetState();
}

class _LazyLoadingWidgetState extends State<LazyLoadingWidget> {
  bool _hasBeenVisible = false;

  @override
  Widget build(BuildContext context) {
    return ViewportAwareBuilder(
      builder: (context, isInViewport) {
        if (isInViewport && !_hasBeenVisible) {
          _hasBeenVisible = true;
        }
        
        return _hasBeenVisible ? widget.child : widget.placeholder;
      },
    );
  }
}

/// Smart refresh indicator that prevents excessive API calls
class SmartRefreshIndicator extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  final Duration minRefreshInterval;
  final Color? color;

  const SmartRefreshIndicator({
    Key? key,
    required this.child,
    required this.onRefresh,
    this.minRefreshInterval = const Duration(seconds: 5),
    this.color,
  }) : super(key: key);

  @override
  State<SmartRefreshIndicator> createState() => _SmartRefreshIndicatorState();
}

class _SmartRefreshIndicatorState extends State<SmartRefreshIndicator> {
  DateTime? _lastRefreshTime;
  bool _isRefreshing = false;

  Future<void> _handleRefresh() async {
    final now = DateTime.now();
    
    if (_lastRefreshTime != null && 
        now.difference(_lastRefreshTime!) < widget.minRefreshInterval) {
      return;
    }

    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      await widget.onRefresh();
      _lastRefreshTime = now;
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: widget.color,
      child: widget.child,
    );
  }
}

/// Optimized list tile for better scroll performance
class OptimizedListTile extends StatelessWidget {
  final Widget? leading;
  final Widget? title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? contentPadding;
  final bool dense;

  const OptimizedListTile({
    Key? key,
    this.leading,
    this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.contentPadding,
    this.dense = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: contentPadding ?? 
                     (dense ? const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
                            : const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
            child: Row(
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: 16),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (title != null) title!,
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        subtitle!,
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 16),
                  trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Extension methods for scroll optimization
extension ScrollControllerExtensions on ScrollController {
  /// Smooth scroll to top with performance optimization
  Future<void> smoothScrollToTop({
    Duration duration = const Duration(milliseconds: 500),
    Curve curve = Curves.fastOutSlowIn,
  }) async {
    if (!hasClients) return;
    
    await animateTo(
      0,
      duration: duration,
      curve: curve,
    );
  }

  /// Check if user is near the top
  bool get isNearTop => offset < 100;

  /// Check if user is near the bottom
  bool get isNearBottom {
    if (!hasClients) return false;
    final maxScroll = position.maxScrollExtent;
    final currentScroll = offset;
    return currentScroll >= (maxScroll - 100);
  }
}

/// Performance monitoring for scroll
class ScrollPerformanceMonitor {
  static final Map<String, List<double>> _frameRates = {};
  static final Map<String, DateTime> _lastMeasurement = {};

  static void startMonitoring(String identifier) {
    _frameRates[identifier] = [];
    _lastMeasurement[identifier] = DateTime.now();
  }

  static void recordFrame(String identifier) {
    final now = DateTime.now();
    final last = _lastMeasurement[identifier];
    
    if (last != null) {
      final frameTime = now.difference(last).inMicroseconds / 1000.0;
      final fps = 1000.0 / frameTime;
      
      _frameRates[identifier]?.add(fps);
      
      // Keep only last 60 measurements
      if (_frameRates[identifier]!.length > 60) {
        _frameRates[identifier]!.removeAt(0);
      }
    }
    
    _lastMeasurement[identifier] = now;
  }

  static double getAverageFPS(String identifier) {
    final rates = _frameRates[identifier];
    if (rates == null || rates.isEmpty) return 0.0;
    
    return rates.reduce((a, b) => a + b) / rates.length;
  }

  static void stopMonitoring(String identifier) {
    _frameRates.remove(identifier);
    _lastMeasurement.remove(identifier);
  }
}