// lib/data/repositories/address_repository_impl.dart
//
// Implements IAddressRepository over the existing AddressRepository.
//
// The gain is the contract: every method there returned Future<bool>, so a
// validation rejection, an expired session and a dropped connection were all
// the same `false` and the UI could only show one generic message.

import '../../core/error/exceptions.dart';
import '../../core/error/failure_mapper.dart';
import '../../core/result/result.dart';
import '../../domain/entities/customer_address.dart';
import '../../domain/repositories/i_address_repository.dart';
import '../models/address_model.dart';
import 'address_repository.dart';

final class AddressRepositoryImpl implements IAddressRepository {
  final AddressRepository _delegate;

  AddressRepositoryImpl({required AddressRepository delegate})
      : _delegate = delegate;

  @override
  Future<Result<List<CustomerAddress>>> list() => guard(() async {
        final models = await _delegate.getAddresses();
        return models.map((m) => m.toEntity()).toList(growable: false);
      });

  @override
  Future<Result<void>> add(CustomerAddress address) => guard(() async {
        final ok = await _delegate.addAddress(_toModel(address));
        if (!ok) throw const ServerException('Could not save the address');
      });

  @override
  Future<Result<void>> update(CustomerAddress address) => guard(() async {
        final ok = await _delegate.updateAddress(_toModel(address));
        if (!ok) throw const ServerException('Could not update the address');
      });

  @override
  Future<Result<void>> delete(String addressId) => guard(() async {
        final ok = await _delegate.deleteAddress(addressId);
        if (!ok) throw const ServerException('Could not delete the address');
      });

  @override
  Future<Result<void>> setDefault(String addressId) => guard(() async {
        final ok = await _delegate.setDefaultAddress(addressId);
        if (!ok) {
          throw const ServerException('Could not set the default address');
        }
      });

  Address _toModel(CustomerAddress a) => Address(
        id: a.id,
        fullName: a.fullName,
        mobileNumber: a.mobileNumber,
        emailId: a.email,
        deliveryAddrLine1: a.line1,
        deliveryAddrLine2: a.line2,
        deliveryAddrCity: a.city,
        deliveryAddrPincode: a.pincode,
        // The DTO encodes this as a String; the entity carries a bool.
        isDefault: a.isDefault ? '1' : '0',
        areaId: a.areaId,
        landmark: a.landmark,
        state: a.state,
        latitude: a.location?.latitude.toString(),
        longitude: a.location?.longitude.toString(),
      );
}
