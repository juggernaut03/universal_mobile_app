import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../providers/steal_deals_provider.dart';
import '../../home/widgets/single_offer_section_widget.dart';

/// Tabbed version of offers for the cart review screen.
/// Each offer becomes a tab instead of being stacked vertically.
/// Auto-advances through tabs on a 4-second timer.
class TabbedOffersWidget extends ConsumerStatefulWidget {
  const TabbedOffersWidget({Key? key}) : super(key: key);

  @override
  ConsumerState<TabbedOffersWidget> createState() => _TabbedOffersWidgetState();
}

class _TabbedOffersWidgetState extends ConsumerState<TabbedOffersWidget>
    with TickerProviderStateMixin {
  TabController? _tabController;
  int _lastLength = 0;
  Timer? _autoSwitchTimer;
  bool _userInteracted = false;

  @override
  void dispose() {
    _autoSwitchTimer?.cancel();
    _tabController?.dispose();
    super.dispose();
  }

  void _ensureController(int length) {
    if (_tabController == null || _lastLength != length) {
      _tabController?.removeListener(_onTabChanged);
      _tabController?.dispose();
      _tabController = TabController(length: length, vsync: this);
      _tabController!.addListener(_onTabChanged);
      _lastLength = length;
      _startAutoSwitch();
    }
  }

  void _onTabChanged() {
    if (_tabController!.indexIsChanging) {
      // User tap — pause auto switch
      _userInteracted = true;
      _autoSwitchTimer?.cancel();
    }
  }

  void _startAutoSwitch() {
    _autoSwitchTimer?.cancel();
    if (_userInteracted) return;
    _autoSwitchTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || _tabController == null) return;
      final length = _tabController!.length;
      if (length <= 1) return;
      final next = (_tabController!.index + 1) % length;
      _tabController!.animateTo(next);
    });
  }

  @override
  Widget build(BuildContext context) {
    final offersAsync = ref.watch(stealDealsOffersProvider);

    final offers = offersAsync.whenOrNull(data: (data) => data);
    final previousOffers = offersAsync.valueOrNull;
    final displayOffers = offers ?? previousOffers;

    if (displayOffers == null || displayOffers.isEmpty) {
      return const SizedBox.shrink();
    }

    _ensureController(displayOffers.length);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tab bar — one tab per offer
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicator: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.neutral700,
              labelStyle: AppTextStyles.labelMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: AppTextStyles.labelMedium,
              padding: const EdgeInsets.all(4),
              labelPadding: const EdgeInsets.symmetric(horizontal: 12),
              tabs: displayOffers
                  .map((offer) => Tab(
                        height: 36,
                        text: offer.offerHeadingText.isNotEmpty
                            ? offer.offerHeadingText
                            : 'Offer',
                      ))
                  .toList(),
            ),
          ),
        ),

        // Tab content with slide transition — the selected offer section
        AnimatedBuilder(
          animation: _tabController!,
          builder: (context, _) {
            final index = _tabController!.index;
            if (index < 0 || index >= displayOffers.length) {
              return const SizedBox.shrink();
            }
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              switchInCurve: Curves.easeInOut,
              switchOutCurve: Curves.easeInOut,
              transitionBuilder: (child, animation) {
                final slide = Tween<Offset>(
                  begin: const Offset(0.1, 0),
                  end: Offset.zero,
                ).animate(animation);
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(position: slide, child: child),
                );
              },
              child: SingleOfferSectionWidget(
                key: ValueKey('tabbed_offer_$index'),
                offer: displayOffers[index],
              ),
            );
          },
        ),
      ],
    );
  }
}
