class LastOrderStatus {
  final String orderStatusTxt;
  final String actualOrderNo;
  final String orderStatusImg;
  final bool isVisible;

  LastOrderStatus({
    required this.orderStatusTxt,
    required this.actualOrderNo,
    required this.orderStatusImg,
    this.isVisible = false,
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

    return LastOrderStatus(
      orderStatusTxt: json['order_status_txt'] as String? ?? '',
      actualOrderNo: json['actual_order_no'] as String? ?? '',
      orderStatusImg: json['order_status_img'] as String? ?? '',
      isVisible: visible,
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
