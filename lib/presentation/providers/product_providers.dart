import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:patelmart/data/models/product_model.dart';
import 'package:patelmart/presentation/providers/launch_flow_provider.dart';
import 'package:patelmart/presentation/providers/outlet_provider.dart';
import 'package:patelmart/presentation/providers/subcategory_providers.dart';

final productsByCodesProvider = FutureProvider.family<List<ProductModel>, List<String>>((ref, productCodes) async {
  if (productCodes.isEmpty) {
    return [];
  }
  
  // Get the repository and store code
  final productRepository = ref.watch(productRepositoryProvider);
  final selectedOutlet = ref.watch(selectedOutletProvider).valueOrNull;
  final storeCode = selectedOutlet?.storeCode ?? 'KLK'; // Use your default store code
  
  // Fetch products for each product code
  List<ProductModel> products = [];
  for (final pCode in productCodes) {
    try {
      final product = await productRepository.getProductByCode(pCode, storeCode);
      if (product != null) {
        products.add(product);
      }
    } catch (e) {
      ref.read(loggerProvider).error('Error fetching product $pCode: $e');
    }
  }
  
  return products;
});