// lib/domain/entities/outlet.dart
//
// Pure Dart. The wire format — `store_name` vs `mobile_outlet_name`,
// `is_enabled: "Enabled"`, `home_delivery: "yes"`, coordinates as strings —
// stops at OutletModel.

import 'package:meta/meta.dart';

/// Ways an order can reach the customer.
enum FulfilmentMethod {
  homeDelivery,
  selfPickup;

  String get label => switch (this) {
        FulfilmentMethod.homeDelivery => 'Home Delivery',
        FulfilmentMethod.selfPickup => 'Store Pickup',
      };
}

/// A geographic point.
///
/// `OutletModel` carries latitude and longitude as **Strings**, so every
/// consumer had to parse them at the point of use. Parsing happens once, in the
/// data layer, and an unparseable coordinate becomes null rather than 0,0 —
/// which is a real location in the Gulf of Guinea.
@immutable
final class GeoPoint {
  final double latitude;
  final double longitude;

  const GeoPoint({required this.latitude, required this.longitude});

  /// Parses a coordinate pair, returning null when either value is missing or
  /// malformed.
  static GeoPoint? tryParse(String? latitude, String? longitude) {
    final lat = double.tryParse(latitude?.trim() ?? '');
    final lng = double.tryParse(longitude?.trim() ?? '');
    if (lat == null || lng == null) return null;
    if (lat.abs() > 90 || lng.abs() > 180) return null;
    return GeoPoint(latitude: lat, longitude: lng);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GeoPoint &&
          other.latitude == latitude &&
          other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => 'GeoPoint($latitude, $longitude)';
}

/// A store the customer can order from.
@immutable
final class Outlet {
  final String id;

  /// Business identifier used across catalogue, cart and orders.
  final String storeCode;

  final String name;
  final String address;

  /// Coordinates, or null when the backend supplied none or supplied garbage.
  final GeoPoint? location;

  /// Minimum order value in rupees. Zero means no minimum.
  final int minOrderAmount;

  final String openTime;
  final String deliveryTime;

  /// Which day delivery slots start being offered on, relative to today -
  /// 0 = same day, 1 = next day only, 2 = day after tomorrow, etc. Admin
  /// > Outlet > Stores. Distinct from [deliveryTime], which is free-text
  /// display copy the app never parses.
  final int deliveryStartOffsetDays;

  final String offerName;
  final String contactPhone;

  /// Operator-authored message shown when the store is closed or restricted.
  final String storeMessage;

  /// Whether the outlet is trading at all.
  final bool isEnabled;

  /// Fulfilment methods currently on offer.
  ///
  /// Replaces the pair of `homeDelivery` / `selfPickup` booleans that every
  /// consumer had to combine by hand, and the parallel `hasDeliveryOnly` /
  /// `hasPickupOnly` / `hasBothServices` getters on OutletStatus.
  final Set<FulfilmentMethod> fulfilmentMethods;

  /// Whether this outlet charges a packing fee on self-pickup orders. Purely
  /// informational — the authoritative amount and enablement at order time
  /// come from POST /delivery-charges/calculate (fulfillment_type: 'pickup')
  /// and ultimately from placeOrder itself, not from this cached flag.
  final bool packingFeeEnabledForPickup;

  const Outlet({
    required this.id,
    required this.storeCode,
    required this.name,
    required this.address,
    required this.minOrderAmount,
    this.location,
    this.openTime = '',
    this.deliveryTime = '',
    this.deliveryStartOffsetDays = 0,
    this.offerName = '',
    this.contactPhone = '',
    this.storeMessage = '',
    this.isEnabled = true,
    this.fulfilmentMethods = const {FulfilmentMethod.homeDelivery},
    this.packingFeeEnabledForPickup = false,
  });

  // ---- business rules ----

  bool get offersHomeDelivery =>
      fulfilmentMethods.contains(FulfilmentMethod.homeDelivery);

  bool get offersSelfPickup =>
      fulfilmentMethods.contains(FulfilmentMethod.selfPickup);

  /// Whether the outlet can accept an order right now: trading, and with at
  /// least one way to fulfil it.
  bool get canAcceptOrders => isEnabled && fulfilmentMethods.isNotEmpty;

  /// Whether [orderTotal] clears the outlet's minimum.
  bool meetsMinimumOrder(double orderTotal) => orderTotal >= minOrderAmount;

  /// Shortfall against the minimum order value; zero when already met.
  double amountBelowMinimum(double orderTotal) {
    final shortfall = minOrderAmount - orderTotal;
    return shortfall > 0 ? shortfall : 0;
  }

  /// Message explaining the outlet's current state, preferring the operator's
  /// own wording when they supplied one.
  String get statusMessage {
    if (!isEnabled) {
      return storeMessage.isNotEmpty
          ? storeMessage
          : 'This outlet is temporarily closed';
    }
    if (fulfilmentMethods.isEmpty) {
      return storeMessage.isNotEmpty
          ? storeMessage
          : 'No delivery services currently available';
    }
    if (fulfilmentMethods.length == 1) {
      return 'Only ${fulfilmentMethods.first.label} is available';
    }
    return 'All services are available';
  }

  Outlet copyWith({
    String? id,
    String? storeCode,
    String? name,
    String? address,
    GeoPoint? location,
    int? minOrderAmount,
    String? openTime,
    String? deliveryTime,
    int? deliveryStartOffsetDays,
    String? offerName,
    String? contactPhone,
    String? storeMessage,
    bool? isEnabled,
    Set<FulfilmentMethod>? fulfilmentMethods,
    bool? packingFeeEnabledForPickup,
  }) =>
      Outlet(
        id: id ?? this.id,
        storeCode: storeCode ?? this.storeCode,
        name: name ?? this.name,
        address: address ?? this.address,
        location: location ?? this.location,
        minOrderAmount: minOrderAmount ?? this.minOrderAmount,
        openTime: openTime ?? this.openTime,
        deliveryTime: deliveryTime ?? this.deliveryTime,
        deliveryStartOffsetDays: deliveryStartOffsetDays ?? this.deliveryStartOffsetDays,
        offerName: offerName ?? this.offerName,
        contactPhone: contactPhone ?? this.contactPhone,
        storeMessage: storeMessage ?? this.storeMessage,
        isEnabled: isEnabled ?? this.isEnabled,
        fulfilmentMethods: fulfilmentMethods ?? this.fulfilmentMethods,
        packingFeeEnabledForPickup:
            packingFeeEnabledForPickup ?? this.packingFeeEnabledForPickup,
      );

  /// Identity is the store code — the stable business key.
  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Outlet && other.storeCode == storeCode;

  @override
  int get hashCode => storeCode.hashCode;

  @override
  String toString() => 'Outlet($storeCode, $name, enabled: $isEnabled)';
}
