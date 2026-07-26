// lib/domain/repositories/i_cart_repository.dart

import '../../core/result/result.dart';
import '../entities/cart.dart';

/// Cart persistence and server-side reconciliation.
abstract interface class ICartRepository {
  /// Loads the stored cart for a store.
  ///
  /// An absent cart is an empty one, not a failure — a first-time user has no
  /// stored cart and that is normal.
  Future<Result<Cart>> load(String storeCode);

  /// Persists [cart] locally.
  Future<Result<void>> save(Cart cart);

  /// Clears the stored cart for a store.
  Future<Result<void>> clear(String storeCode);

  /// Re-reads prices and stock from the server and returns the cart updated to
  /// match.
  ///
  /// Prices and availability drift while a cart sits idle, so this runs before
  /// checkout. The returned cart may have lines whose product is now out of
  /// stock — trimming is the caller's decision, not this method's.
  Future<Result<Cart>> refreshFromServer(Cart cart);
}
