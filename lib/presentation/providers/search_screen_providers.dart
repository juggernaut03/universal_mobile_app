// lib/presentation/providers/search_screen_providers.dart
//
// Product search state, moved out of search_screen.dart.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../di/infrastructure_providers.dart';
import 'outlet_provider.dart';

// Search state model
class SearchState {
  final List<dynamic> results;
  final String query;
  final bool isLoading;
  final String? error;
  final bool hasSearched;

  const SearchState({
    this.results = const [],
    this.query = '',
    this.isLoading = false,
    this.error,
    this.hasSearched = false,
  });

  SearchState copyWith({
    List<dynamic>? results,
    String? query,
    bool? isLoading,
    String? error,
    bool? hasSearched,
  }) {
    return SearchState(
      results: results ?? this.results,
      query: query ?? this.query,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      hasSearched: hasSearched ?? this.hasSearched,
    );
  }
}

class SearchNotifier extends StateNotifier<SearchState> {
  final Ref _ref;
  Timer? _debounceTimer;
  
  // Debounce duration for auto-complete
  static const Duration _debounceDuration = Duration(milliseconds: 500);
  
  // Minimum characters to trigger search
  static const int _minSearchLength = 3;

  SearchNotifier(this._ref) : super(const SearchState());

  void setQuery(String query) {
    state = state.copyWith(query: query);
    
    // Cancel previous timer
    _debounceTimer?.cancel();
    
    if (query.length >= _minSearchLength) {
      // Set loading state immediately for visual feedback
      state = state.copyWith(isLoading: true, error: null);
      
      // Start debounce timer
      _debounceTimer = Timer(_debounceDuration, () {
        _performSearch(query);
      });
    } else {
      // Clear results if query is too short
      state = state.copyWith(
        results: [],
        isLoading: false,
        error: null,
        hasSearched: false,
      );
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.length < _minSearchLength) return;
    
    final logger = _ref.read(loggerProvider);
    logger.log('Auto-searching for: $query');
    
    try {
      // Get selected outlet store code. Searching another tenant's store would
      // return products this shopper cannot buy, so without an outlet there is
      // nothing to search.
      final selectedOutlet = _ref.read(selectedOutletProvider).valueOrNull;
      final storeCode = selectedOutlet?.storeCode;
      if (storeCode == null || storeCode.isEmpty) {
        logger.log('Search skipped: no outlet selected');
        // setQuery already switched on the spinner, so this must land the state
        // rather than just return, or the field spins forever.
        state = state.copyWith(
          results: [],
          isLoading: false,
          error: 'Choose a store to search products',
          hasSearched: true,
        );
        return;
      }

      // Use the API client
      final apiClient = _ref.read(apiClientProvider);
      
      // Make the API call (universal backend product search)
      final response = await apiClient.post(
        ApiConstants.searchProducts,
        body: {
          'search_term': query,
          'store_code': storeCode,
        },
      );

      // Process the response based on its format
      List<dynamic> results = [];
      if (response is Map && response['data'] is List) {
        results = response['data'] as List;
      } else if (response is List) {
        results = response;
      }

      // No stock/price filtering here — the backend already scopes matches to
      // this store and pcode_status: 'Y' (see routes/products.js), and no
      // other listing in the app (category, home sections) hides zero-stock
      // items either. This used to also drop every product whose
      // store_quantity happened to be the schema's own default of 0
      // (ProductMaster.js), silently returning "No Results Found" for
      // products the backend had actually found.

      // Only update state if this search is still current
      if (state.query == query) {
        state = state.copyWith(
          results: results,
          isLoading: false,
          error: null,
          hasSearched: true,
        );
      }
    } catch (e) {
      logger.error('Search error: $e');
      
      // Only update state if this search is still current
      if (state.query == query) {
        state = state.copyWith(
          error: 'Failed to load search results',
          isLoading: false,
          hasSearched: true,
        );
      }
    }
  }

  void clearSearch() {
    _debounceTimer?.cancel();
    state = const SearchState();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}

final searchProvider = StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  return SearchNotifier(ref);
});
