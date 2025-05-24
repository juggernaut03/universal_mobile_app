// lib/presentation/providers/search_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'launch_flow_provider.dart';

// Search history item model
class SearchHistoryItem {
  final String query;
  final DateTime timestamp;
  final String? productId;
  final String? productName;

  SearchHistoryItem({
    required this.query,
    required this.timestamp,
    this.productId,
    this.productName,
  });

  Map<String, dynamic> toJson() {
    return {
      'query': query,
      'timestamp': timestamp.toIso8601String(),
      'productId': productId,
      'productName': productName,
    };
  }

  factory SearchHistoryItem.fromJson(Map<String, dynamic> json) {
    return SearchHistoryItem(
      query: json['query'] ?? '',
      timestamp: DateTime.parse(json['timestamp']),
      productId: json['productId'],
      productName: json['productName'],
    );
  }
}

// Search history notifier
class SearchHistoryNotifier extends StateNotifier<List<SearchHistoryItem>> {
  final SharedPreferences _prefs;
  static const String _historyKey = 'search_history';
  static const int _maxHistoryItems = 20;

  SearchHistoryNotifier(this._prefs) : super([]) {
    _loadHistory();
  }

  void _loadHistory() {
    try {
      final historyJson = _prefs.getStringList(_historyKey) ?? [];
      final history = historyJson
          .map((item) {
            try {
              return SearchHistoryItem.fromJson(jsonDecode(item));
            } catch (e) {
              return null;
            }
          })
          .where((item) => item != null)
          .cast<SearchHistoryItem>()
          .toList();
      
      // Sort by timestamp (most recent first)
      history.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      state = history;
    } catch (e) {
      state = [];
    }
  }

  Future<void> addSearchQuery(String query, {String? productId, String? productName}) async {
    if (query.trim().isEmpty) return;

    final newItem = SearchHistoryItem(
      query: query.trim(),
      timestamp: DateTime.now(),
      productId: productId,
      productName: productName,
    );

    // Remove any existing entry with the same query
    final updatedHistory = state
        .where((item) => item.query.toLowerCase() != query.trim().toLowerCase())
        .toList();

    // Add new item at the beginning
    updatedHistory.insert(0, newItem);

    // Limit history size
    if (updatedHistory.length > _maxHistoryItems) {
      updatedHistory.removeRange(_maxHistoryItems, updatedHistory.length);
    }

    state = updatedHistory;
    await _saveHistory();
  }

  Future<void> removeHistoryItem(SearchHistoryItem item) async {
    state = state.where((historyItem) => historyItem != item).toList();
    await _saveHistory();
  }

  Future<void> clearHistory() async {
    state = [];
    await _prefs.remove(_historyKey);
  }

  Future<void> _saveHistory() async {
    try {
      final historyJson = state.map((item) => jsonEncode(item.toJson())).toList();
      await _prefs.setStringList(_historyKey, historyJson);
    } catch (e) {
      // Handle error silently
    }
  }

  List<SearchHistoryItem> getRecentSearches([int limit = 5]) {
    return state.take(limit).toList();
  }

  List<String> getSearchSuggestions(String query, [int limit = 5]) {
    if (query.isEmpty) return [];
    
    final suggestions = state
        .where((item) => 
            item.query.toLowerCase().contains(query.toLowerCase()) &&
            item.query.toLowerCase() != query.toLowerCase())
        .map((item) => item.query)
        .toSet() // Remove duplicates
        .take(limit)
        .toList();
    
    return suggestions;
  }
}

// Search history provider
final searchHistoryProvider = StateNotifierProvider<SearchHistoryNotifier, List<SearchHistoryItem>>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SearchHistoryNotifier(prefs);
});

// Recent searches provider (limited list)
final recentSearchesProvider = Provider<List<SearchHistoryItem>>((ref) {
  final history = ref.watch(searchHistoryProvider);
  return history.take(5).toList();
});

// Search suggestions provider based on history
final searchSuggestionsProvider = Provider.family<List<String>, String>((ref, query) {
  final notifier = ref.read(searchHistoryProvider.notifier);
  return notifier.getSearchSuggestions(query);
});

// Popular searches provider (most frequent searches)
final popularSearchesProvider = Provider<List<String>>((ref) {
  final history = ref.watch(searchHistoryProvider);
  
  // Count frequency of each query
  final queryCount = <String, int>{};
  for (final item in history) {
    final query = item.query.toLowerCase();
    queryCount[query] = (queryCount[query] ?? 0) + 1;
  }
  
  // Sort by frequency and return top queries
  final sortedQueries = queryCount.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  
  return sortedQueries
      .take(10)
      .map((entry) => entry.key)
      .toList();
});