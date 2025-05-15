// lib/presentation/providers/address_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../core/utils/logger.dart';
import '../../data/models/address_model.dart';
import '../../data/repositories/address_repository.dart';
import 'launch_flow_provider.dart';

// Provider for the AddressRepository
final addressRepositoryProvider = Provider<AddressRepository>((ref) {
  final logger = ref.watch(loggerProvider);
  return AddressRepository(
    client: http.Client(),
    logger: logger,
  );
});

// Provider for the list of addresses
final addressesProvider = FutureProvider<List<Address>>((ref) async {
  final repository = ref.watch(addressRepositoryProvider);
  return repository.getAddresses();
});

// Provider for address operations
final addressOperationsProvider = Provider<AddressOperations>((ref) {
  final repository = ref.watch(addressRepositoryProvider);
  return AddressOperations(repository: repository);
});

// Class for address operations
class AddressOperations {
  final AddressRepository repository;

  AddressOperations({required this.repository});

  Future<bool> addAddress(Address address) async {
    return await repository.addAddress(address);
  }

  Future<bool> updateAddress(Address address) async {
    return await repository.updateAddress(address);
  }

  Future<bool> deleteAddress(String addressId) async {
    return await repository.deleteAddress(addressId);
  }
}

// Provider for the selected address
final selectedAddressProvider = StateProvider<Address?>((ref) => null);