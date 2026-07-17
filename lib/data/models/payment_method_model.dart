
class PaymentMethod {
  final String id;
  final int idPaymentMode;
  final String paymentModeName;

  PaymentMethod({
    required this.id,
    required this.idPaymentMode,
    required this.paymentModeName,
  });

  factory PaymentMethod.fromJson(Map<String, dynamic> json) {
    return PaymentMethod(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      idPaymentMode: json['idpayment_mode'] is int
          ? json['idpayment_mode']
          : int.tryParse(json['idpayment_mode']?.toString() ?? '') ?? 0,
      paymentModeName: json['payment_mode_name'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'idpayment_mode': idPaymentMode,
      'payment_mode_name': paymentModeName,
    };
  }

  // Helper method to get display name
  String get displayName {
    switch (paymentModeName.toLowerCase()) {
      case 'pod':
        return 'Pay on Delivery';
      case 'online payment':
        return 'Online Payment';
      default:
        return paymentModeName;
    }
  }

  // Helper method to get subtitle
  String get subtitle {
    switch (paymentModeName.toLowerCase()) {
      case 'pod':
        return 'Pay when your order is delivered';
      case 'online payment':
        return 'Pay securely with card, UPI or net banking';
      default:
        return 'Secure payment option';
    }
  }

  // Helper method to get icon
  String get iconName {
    switch (paymentModeName.toLowerCase()) {
      case 'pod':
        return 'money';
      case 'online payment':
        return 'credit_card';
      default:
        return 'payment';
    }
  }
}
