// lib/domain/entities/customer_address.dart

import 'package:meta/meta.dart';

import 'outlet.dart' show GeoPoint;

/// A delivery address saved by the customer.
///
/// Named CustomerAddress rather than Address to avoid colliding with the
/// existing data-layer `Address` DTO during the migration.
@immutable
final class CustomerAddress {
  final String id;
  final String fullName;
  final String mobileNumber;
  final String email;

  final String line1;
  final String line2;
  final String landmark;
  final String city;
  final String pincode;

  /// Whether this is the customer's default delivery address.
  ///
  /// The DTO stores this as a String ('1'/'0'/'true'), so every consumer had to
  /// know the encoding. Parsed once at the boundary.
  final bool isDefault;

  /// Serviceable-area id the backend associates with this address.
  final String areaId;

  /// Coordinates, when the address was pinned on a map. Null when it was typed.
  final GeoPoint? location;

  const CustomerAddress({
    required this.id,
    required this.fullName,
    required this.mobileNumber,
    required this.line1,
    required this.city,
    required this.pincode,
    this.email = '',
    this.line2 = '',
    this.landmark = '',
    this.isDefault = false,
    this.areaId = '',
    this.location,
  });

  /// Whether the address has everything needed to deliver to it.
  bool get isDeliverable =>
      fullName.trim().isNotEmpty &&
      mobileNumber.trim().isNotEmpty &&
      line1.trim().isNotEmpty &&
      pincode.trim().isNotEmpty;

  /// Single-line form for confirmation screens.
  String get singleLine => [
        line1,
        line2,
        landmark,
        city,
        pincode,
      ].where((part) => part.trim().isNotEmpty).join(', ');

  CustomerAddress copyWith({
    String? id,
    String? fullName,
    String? mobileNumber,
    String? email,
    String? line1,
    String? line2,
    String? landmark,
    String? city,
    String? pincode,
    bool? isDefault,
    String? areaId,
    GeoPoint? location,
  }) =>
      CustomerAddress(
        id: id ?? this.id,
        fullName: fullName ?? this.fullName,
        mobileNumber: mobileNumber ?? this.mobileNumber,
        email: email ?? this.email,
        line1: line1 ?? this.line1,
        line2: line2 ?? this.line2,
        landmark: landmark ?? this.landmark,
        city: city ?? this.city,
        pincode: pincode ?? this.pincode,
        isDefault: isDefault ?? this.isDefault,
        areaId: areaId ?? this.areaId,
        location: location ?? this.location,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is CustomerAddress && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'CustomerAddress($id, $city $pincode)';
}
