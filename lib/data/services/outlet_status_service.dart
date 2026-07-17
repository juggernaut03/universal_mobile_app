import 'package:http/http.dart' as http;
import '../../core/utils/logger.dart';
import '../models/outlet_status_model.dart';

class OutletStatusService {
  final Logger _logger;

  OutletStatusService({
    http.Client? client,
    Logger? logger,
  }) : _logger = logger ?? Logger();

  /// Check the operational status of a specific outlet.
  /// The universal backend has no real-time outlet-status endpoint — the
  /// store's is_enabled flag is checked at store selection instead. Returning
  /// null keeps the consumers' fail-safe behavior (cart enabled, both
  /// delivery methods offered).
  Future<OutletStatus?> checkOutletStatus({
    required String storeCode,
  }) async {
    _logger.log(
        'Outlet status check skipped for $storeCode — no universal endpoint (assuming operational)');
    return null;
  }

  /// Check multiple outlets status (if needed in the future)
  Future<Map<String, OutletStatus>> checkMultipleOutletsStatus({
    required List<String> storeCodes,
  }) async {
    final Map<String, OutletStatus> statusMap = {};
    
    // For now, we'll check them sequentially
    // In the future, this could be optimized with a batch API
    for (final storeCode in storeCodes) {
      final status = await checkOutletStatus(storeCode: storeCode);
      if (status != null) {
        statusMap[storeCode] = status;
      }
    }
    
    return statusMap;
  }
}
