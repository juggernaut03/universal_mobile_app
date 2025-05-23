// lib/presentation/providers/address_provider.dart

import 'dart:ui';

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

// Provider for tracking refresh state
final addressRefreshProvider = StateProvider<int>((ref) => 0);

// Updated provider for the list of addresses with auto-refresh capability
final addressesProvider = FutureProvider<List<Address>>((ref) async {
  // Watch the refresh counter to trigger refresh when it changes
  ref.watch(addressRefreshProvider);
  
  final repository = ref.watch(addressRepositoryProvider);
  return repository.getAddresses();
});

// Direct address list provider that bypasses caching (for immediate updates)
final directAddressListProvider = FutureProvider<List<Address>>((ref) async {
  final repository = ref.watch(addressRepositoryProvider);
  return repository.getAddresses();
});

// Provider for address operations with auto-refresh
final addressOperationsProvider = Provider<AddressOperations>((ref) {
  final repository = ref.watch(addressRepositoryProvider);
  return AddressOperations(
    repository: repository,
    onAddressChanged: () {
      // Trigger refresh of address list
      ref.read(addressRefreshProvider.notifier).state++;
      // Also refresh the direct provider
      ref.refresh(directAddressListProvider);
    },
  );
});

// Enhanced class for address operations with callback support
class AddressOperations {
  final AddressRepository repository;
  final VoidCallback? onAddressChanged;

  AddressOperations({
    required this.repository,
    this.onAddressChanged,
  });

  Future<bool> addAddress(Address address) async {
    final result = await repository.addAddress(address);
    if (result && onAddressChanged != null) {
      onAddressChanged!();
    }
    return result;
  }

  Future<bool> updateAddress(Address address) async {
    final result = await repository.updateAddress(address);
    if (result && onAddressChanged != null) {
      onAddressChanged!();
    }
    return result;
  }

  Future<bool> deleteAddress(String addressId) async {
    final result = await repository.deleteAddress(addressId);
    if (result && onAddressChanged != null) {
      onAddressChanged!();
    }
    return result;
  }
}

// Provider for the selected address
final selectedAddressProvider = StateProvider<Address?>((ref) => null);

// Helper provider for refreshing addresses manually
final refreshAddressesProvider = Provider<void Function()>((ref) {
  return () {
    ref.read(addressRefreshProvider.notifier).state++;
    ref.refresh(directAddressListProvider);
    ref.refresh(addressesProvider);
  };
});
