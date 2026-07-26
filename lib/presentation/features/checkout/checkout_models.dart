// Shared checkout types, split out of checkout_flow_screen.dart.
//
// NOTE: this file declares its own CheckoutStep enum, distinct from
// domain/entities/checkout_step.dart. Reconciling them is a behaviour
// change and is deliberately not part of this move.
// lib/presentation/features/checkout/checkout_flow_screen.dart

import 'dart:convert';
import 'package:patelmart/data/models/address_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
// FACEBOOK PIXEL IMPORTS

// Checkout step enum to track progress

enum CheckoutStep {
  delivery,
  address,
  time,
  payment,
}

// Delivery method enum
enum DeliveryMethod {
  homeDelivery,
  selfPickup,
}

// Checkout data model to store user selections
class CheckoutData {
  DeliveryMethod? deliveryMethod;
  Address? selectedAddress;
  DateTime? deliveryDate;
  String? deliveryTimeSlot;
  // Universal backend needs the numeric iddelivery_slot, not the display text
  int? deliverySlotId;
  String? specialInstructions;
  String? paymentMethod;
  String? pickupName;

  CheckoutData({
    this.deliveryMethod,
    this.selectedAddress,
    this.deliveryDate,
    this.deliveryTimeSlot,
    this.deliverySlotId,
    this.specialInstructions,
    this.paymentMethod,
    this.pickupName,
  });

  Map<String, dynamic> toJson() {
    return {
      'deliveryMethod': deliveryMethod?.index,
      'selectedAddress': selectedAddress?.toJson(),
      'deliveryDate': deliveryDate?.toIso8601String(),
      'deliveryTimeSlot': deliveryTimeSlot,
      'deliverySlotId': deliverySlotId,
      'specialInstructions': specialInstructions,
      'paymentMethod': paymentMethod,
      'pickupName': pickupName,
    };
  }

  factory CheckoutData.fromJson(Map<String, dynamic> json) {
    return CheckoutData(
      deliveryMethod: json['deliveryMethod'] != null
          ? DeliveryMethod.values[json['deliveryMethod']]
          : null,
      selectedAddress: json['selectedAddress'] != null
          ? Address.fromJson(json['selectedAddress'])
          : null,
      deliveryDate: json['deliveryDate'] != null
          ? DateTime.parse(json['deliveryDate'])
          : null,
      deliveryTimeSlot: json['deliveryTimeSlot'],
      deliverySlotId: json['deliverySlotId'] is int
          ? json['deliverySlotId']
          : int.tryParse(json['deliverySlotId']?.toString() ?? ''),
      specialInstructions: json['specialInstructions'],
      paymentMethod: json['paymentMethod'],
      pickupName: json['pickupName'],
    );
  }

  // Save checkout data to SharedPreferences
  Future<void> saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonData = jsonEncode(toJson());
    await prefs.setString('checkout_data', jsonData);
  }

  // Load checkout data from SharedPreferences
  static Future<CheckoutData> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonData = prefs.getString('checkout_data');
    if (jsonData != null) {
      return CheckoutData.fromJson(jsonDecode(jsonData));
    }
    return CheckoutData();
  }

  // Clear checkout data from SharedPreferences
  static Future<void> clearFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('checkout_data');
  }
}

// Main checkout flow screen that handles all steps
