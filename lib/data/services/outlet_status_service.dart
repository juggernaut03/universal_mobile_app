import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';
import '../../core/utils/logger.dart';
import '../models/outlet_status_model.dart';

class OutletStatusService {
  final http.Client _client;
  final Logger _logger;
  
  static const String _checkOutletStatusUrl = '${ApiConstants.baseUrl}/check_outlet_status';

  OutletStatusService({
    http.Client? client,
    Logger? logger,
  }) : 
    _client = client ?? http.Client(),
    _logger = logger ?? Logger();

  /// Check the operational status of a specific outlet
  Future<OutletStatus?> checkOutletStatus({
    required String storeCode,
  }) async {
    try {
      _logger.log('Checking outlet status for store: $storeCode');
      
      final response = await _client.post(
        Uri.parse(_checkOutletStatusUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'store_code': storeCode,
        }),
      ).timeout(const Duration(seconds: 15));
      
      _logger.log('Outlet status API response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        
        if (data.isNotEmpty) {
          final outletStatus = OutletStatus.fromJson(data[0]);
          _logger.log('Outlet status retrieved: $outletStatus');
          return outletStatus;
        } else {
          _logger.error('Empty response from outlet status API');
          return null;
        }
      } else {
        _logger.error('Failed to check outlet status: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      _logger.error('Error checking outlet status: $e');
      return null;
    }
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
