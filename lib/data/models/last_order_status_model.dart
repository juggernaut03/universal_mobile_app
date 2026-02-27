import 'order_model.dart';

class LastOrderStatus {
  final String orderStatusTxt;
  final String actualOrderNo;
  final String orderStatusImg;
  final bool isVisible;
  final Order? lastOrder; // parsed from last_order_details[0]

  LastOrderStatus({
    required this.orderStatusTxt,
    required this.actualOrderNo,
    required this.orderStatusImg,
    this.isVisible = false,
    this.lastOrder,
  });

  factory LastOrderStatus.fromJson(Map<String, dynamic> json) {
    bool visible = false;
    if (json.containsKey('visible')) {
      if (json['visible'] is bool) {
        visible = json['visible'] as bool;
      } else if (json['visible'] is String) {
        visible = json['visible'].toString().toLowerCase() == 'true';
      } else if (json['visible'] is int) {
        visible = json['visible'] == 1;
      }
    }

    // actual_order_no can be int or String from the API
    final actualOrderNoRaw = json['actual_order_no'];
    final String actualOrderNo = actualOrderNoRaw != null
        ? actualOrderNoRaw.toString()
        : '';

    // Parse first order from last_order_details if available
    Order? lastOrder;
    final lastOrderDetails = json['last_order_details'];
    if (lastOrderDetails is List && lastOrderDetails.isNotEmpty) {
      try {
        final rawItem = lastOrderDetails[0];
        if (rawItem is Map<String, dynamic>) {
          lastOrder = Order.fromJson(rawItem);
        } else if (rawItem is Map) {
          final converted = Map<String, dynamic>.from(rawItem);
          lastOrder = Order.fromJson(converted);
        }
      } catch (e) {
        print('Error parsing last_order_details: $e');
      }
    }

    return LastOrderStatus(
      orderStatusTxt: json['order_status_txt'] as String? ?? '',
      actualOrderNo: actualOrderNo,
      orderStatusImg: json['order_status_img'] as String? ?? '',
      isVisible: visible,
      lastOrder: lastOrder,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'order_status_txt': orderStatusTxt,
      'actual_order_no': actualOrderNo,
      'order_status_img': orderStatusImg,
      'visible': isVisible,
    };
  }
}
