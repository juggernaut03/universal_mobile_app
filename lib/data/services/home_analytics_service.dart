// lib/data/services/home_analytics_service.dart
//
// Counts home-section impressions and taps so "which section sells" is
// answerable. Without it, an editable home is a layout you cannot evaluate.
//
// Batched and best-effort by design: reporting must never slow down or break a
// shopping session, so counts are buffered in memory, flushed on a timer, and
// every failure is swallowed. Losing a batch is an acceptable cost; blocking a
// tap is not.

import 'dart:async';

import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/logger.dart';

class _SectionCounts {
  final String sectionType;
  int impressions = 0;
  int clicks = 0;

  _SectionCounts(this.sectionType);
}

class HomeAnalyticsService {
  final ApiClient _apiClient;
  final Logger _logger;
  final Duration _flushInterval;

  final Map<String, _SectionCounts> _pending = {};
  Timer? _flushTimer;
  String _storeCode = '';

  /// Sections already counted this session, so a section scrolling in and out
  /// of view does not inflate its own impression count.
  final Set<String> _seen = {};

  HomeAnalyticsService({
    required ApiClient apiClient,
    Logger? logger,
    Duration flushInterval = const Duration(seconds: 20),
  })  : _apiClient = apiClient,
        _logger = logger ?? Logger(),
        _flushInterval = flushInterval;

  /// The store the counts belong to. A method rather than a setter because a
  /// write-only setter reads like state the caller can also query.
  void setStoreCode(String value) => _storeCode = value;

  void recordImpression({required String sectionId, required String sectionType}) {
    if (sectionId.isEmpty) return;
    if (!_seen.add(sectionId)) return;

    _counts(sectionId, sectionType).impressions += 1;
    _scheduleFlush();
  }

  void recordClick({required String sectionId, required String sectionType}) {
    if (sectionId.isEmpty) return;
    _counts(sectionId, sectionType).clicks += 1;
    _scheduleFlush();
  }

  _SectionCounts _counts(String sectionId, String sectionType) =>
      _pending.putIfAbsent(sectionId, () => _SectionCounts(sectionType));

  void _scheduleFlush() {
    _flushTimer ??= Timer(_flushInterval, () {
      _flushTimer = null;
      unawaited(flush());
    });
  }

  /// Sends whatever has accumulated. Safe to call at any time.
  Future<void> flush() async {
    if (_pending.isEmpty) return;

    final batch = _pending.entries
        .map((entry) => {
              'section_id': entry.key,
              'section_type': entry.value.sectionType,
              'impressions': entry.value.impressions,
              'clicks': entry.value.clicks,
            })
        .toList();
    _pending.clear();

    try {
      await _apiClient.post(
        ApiConstants.homeEvents,
        body: {'store_code': _storeCode, 'events': batch},
      );
    } catch (e) {
      // Deliberately not retried: a retry queue that grows during an outage is
      // a worse failure than losing a few counts.
      _logger.log('Home analytics batch dropped: $e');
    }
  }

  void dispose() {
    _flushTimer?.cancel();
    _flushTimer = null;
  }
}
