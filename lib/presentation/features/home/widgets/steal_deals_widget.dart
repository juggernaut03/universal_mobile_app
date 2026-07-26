import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/steal_deals_provider.dart';
import 'single_offer_section_widget.dart';

/// Renders all offers as separate sections.
/// Used by cart screen to show all offers in one block.
class StealDealsWidget extends ConsumerWidget {
  const StealDealsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offersAsync = ref.watch(stealDealsOffersProvider);

    final offers = offersAsync.whenOrNull(data: (data) => data);
    final previousOffers = offersAsync.valueOrNull;
    final displayOffers = offers ?? previousOffers;

    if (displayOffers == null || displayOffers.isEmpty) {
      if (offersAsync.isLoading && previousOffers == null) {
        return const SizedBox.shrink();
      }
      if (offersAsync.hasError && previousOffers == null) {
        return const SizedBox.shrink();
      }
      if (displayOffers != null && displayOffers.isEmpty) {
        return const SizedBox.shrink();
      }
      return const SizedBox.shrink();
    }

    return Column(
      children: displayOffers
          .map((offer) => SingleOfferSectionWidget(offer: offer))
          .toList(),
    );
  }
}
