// lib/presentation/providers/address_provider.dart
//
// Saved delivery addresses, as domain entities.
//
// Previously imported data/repositories/address_repository.dart directly and
// exposed `Future<bool>` operations, so a validation rejection, an expired
// session and a dropped connection were all the same `false`.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error/failure.dart';
import '../../core/result/result.dart';
import '../../di/order_providers.dart';
import '../../domain/entities/customer_address.dart';
import '../../domain/repositories/i_address_repository.dart';
import '../../domain/usecases/address/save_address.dart';
import '../../data/models/address_model.dart';

/// Bumped to force the address list to refetch.
final addressRefreshProvider = StateProvider<int>((ref) => 0);

/// The customer's saved addresses.
final addressesProvider = FutureProvider<List<CustomerAddress>>((ref) async {
  ref.watch(addressRefreshProvider);

  final result = await ref.watch(addressRepositoryDomainProvider).list();
  return switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw Exception(failure.userMessage),
  };
});

/// The same list, typed to the Address DTO.
///
/// Was declared separately in address_book_screen as its own
/// `FutureProvider.autoDispose` hitting the repository again — two providers
/// fetching the same data. Derived from [addressesProvider] now, so there is
/// one fetch and one cache.
final addressListProvider = FutureProvider<List<Address>>((ref) async {
  final addresses = await ref.watch(addressesProvider.future);
  return addresses.map(Address.fromEntity).toList(growable: false);
});

/// Refreshes the address list.
final refreshAddressListProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    ref.read(addressRefreshProvider.notifier).state++;
    await ref.read(addressListProvider.future);
  };
});

/// Address create/update/delete, refreshing the list on success.
final addressOperationsProvider = Provider<AddressOperations>((ref) {
  return AddressOperations(
    saveAddress: ref.watch(saveAddressUseCaseProvider),
    repository: ref.watch(addressRepositoryDomainProvider),
    onAddressChanged: () => ref.read(addressRefreshProvider.notifier).state++,
  );
});

/// Address mutations.
///
/// Returns `Failure?` rather than `bool` — null means success, and a failure
/// carries why. A `ValidationFailure` even names the offending fields, which
/// the add/edit screens previously re-derived with their own duplicate checks.
class AddressOperations {
  final SaveAddress _saveAddress;
  final IAddressRepository _repository;
  final void Function()? onAddressChanged;

  AddressOperations({
    required SaveAddress saveAddress,
    required IAddressRepository repository,
    this.onAddressChanged,
  })  : _saveAddress = saveAddress,
        _repository = repository;

  /// Adds an address. Null on success.
  Future<Failure?> add(CustomerAddress address) => _save(address, isNew: true);

  /// Updates an address. Null on success.
  Future<Failure?> update(CustomerAddress address) =>
      _save(address, isNew: false);

  /// Deletes an address. Null on success.
  Future<Failure?> delete(String addressId) async {
    final result = await _repository.delete(addressId);
    return switch (result) {
      Ok() => _notifyChanged(),
      Err(:final failure) => failure,
    };
  }

  /// Marks an address as the default. Null on success.
  Future<Failure?> setDefault(String addressId) async {
    final result = await _repository.setDefault(addressId);
    return switch (result) {
      Ok() => _notifyChanged(),
      Err(:final failure) => failure,
    };
  }

  Future<Failure?> _save(CustomerAddress address, {required bool isNew}) async {
    final result =
        await _saveAddress(SaveAddressParams(address: address, isNew: isNew));
    return switch (result) {
      Ok() => _notifyChanged(),
      Err(:final failure) => failure,
    };
  }

  Failure? _notifyChanged() {
    onAddressChanged?.call();
    return null;
  }
}
