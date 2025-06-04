// // lib/presentation/features/account/notification_preferences_screen.dart

// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import '../../../core/constants/app_colors.dart';
// import '../../../data/services/advanced_notification_service.dart';
// import '../../providers/notification_preferences_provider.dart';

// class NotificationPreferencesScreen extends ConsumerWidget {
//   const NotificationPreferencesScreen({Key? key}) : super(key: key);

//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     final preferencesAsync = ref.watch(notificationPreferencesProvider);

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Notification Settings'),
//         backgroundColor: AppColors.primary,
//         foregroundColor: AppColors.white,
//       ),
//       body: preferencesAsync.when(
//         data: (preferences) => _buildPreferencesContent(context, ref, preferences),
//         loading: () => const Center(child: CircularProgressIndicator()),
//         error: (error, stack) => Center(
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               const Icon(Icons.error_outline, size: 64, color: AppColors.error),
//               const SizedBox(height: 16),
//               Text('Error loading preferences: $error'),
//               const SizedBox(height: 16),
//               ElevatedButton(
//                 onPressed: () => ref.refresh(notificationPreferencesProvider),
//                 child: const Text('Retry'),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildPreferencesContent(
//     BuildContext context,
//     WidgetRef ref,
//     NotificationPreferences preferences,
//   ) {
//     return SingleChildScrollView(
//       padding: const EdgeInsets.all(16),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // Header Section
//           _buildSectionHeader(
//             'Stay updated with your shopping',
//             'Choose what notifications you want to receive',
//           ),
//           const SizedBox(height: 24),

//           // Product Notifications Section
//           _buildSection(
//             'Product Notifications',
//             [
//               _buildSwitchTile(
//                 'Product Back in Stock',
//                 'Get notified when wishlisted products are restocked',
//                 preferences.productRestocked,
//                 Icons.inventory_2_outlined,
//                 () => ref.read(notificationPreferencesProvider.notifier).toggleProductRestocked(),
//               ),
//               _buildSwitchTile(
//                 'Price Drops',
//                 'Get alerts when prices drop on your favorite items',
//                 preferences.priceDrops,
//                 Icons.trending_down,
//                 () => ref.read(notificationPreferencesProvider.notifier).togglePriceDrops(),
//               ),
//             ],
//           ),

//           // Shopping Notifications Section
//           _buildSection(
//             'Shopping Notifications',
//             [
//               _buildSwitchTile(
//                 'Category Updates',
//                 'New products and offers in categories you follow',
//                 preferences.categoryUpdates,
//                 Icons.category_outlined,
//                 () => ref.read(notificationPreferencesProvider.notifier).toggleCategoryUpdates(),
//               ),
//               _buildSwitchTile(
//                 'Cart Reminders',
//                 'Friendly reminders about items left in your cart',
//                 preferences.cartReminders,
//                 Icons.shopping_cart_outlined,
//                 () => ref.read(notificationPreferencesProvider.notifier).toggleCartReminders(),
//               ),
//               _buildSwitchTile(
//                 'Flash Sales',
//                 'Limited-time offers and flash sales',
//                 preferences.flashSales,
//                 Icons.flash_on,
//                 () => ref.read(notificationPreferencesProvider.notifier).toggleFlashSales(),
//               ),
//             ],
//           ),

//           // Personal Notifications Section
//           _buildSection(
//             'Personal Notifications',
//             [
//               _buildSwitchTile(
//                 'Personalized Offers',
//                 'Curated deals based on your shopping habits',
//                 preferences.personalizedOffers,
//                 Icons.star_outline,
//                 () => ref.read(notificationPreferencesProvider.notifier).togglePersonalizedOffers(),
//               ),
//               _buildSwitchTile(
//                 'Order Updates',
//                 'Track your orders from confirmation to delivery',
//                 preferences.orderUpdates,
//                 Icons.local_shipping_outlined,
//                 () => ref.read(notificationPreferencesProvider.notifier).toggleOrderUpdates(),
//               ),
//             ],
//           ),

//           // Subscribed Categories Section
//           if (preferences.subscribedCategories.isNotEmpty) ...[
//             _buildSection(
//               'Subscribed Categories',
//               [
//                 _buildSubscribedCategoriesList(context, ref, preferences.subscribedCategories),
//               ],
//             ),
//           ],

//           // Wishlisted Products Section
//           if (preferences.wishlistedProducts.isNotEmpty) ...[
//             _buildSection(
//               'Product Alerts',
//               [
//                 _buildWishlistedProductsList(context, ref, preferences.wishlistedProducts),
//               ],
//             ),
//           ],

//           // Test Section (Debug mode only)
//           if (kDebugMode) ...[
//             _buildSection(
//               'Testing (Debug Mode)',
//               [
//                 _buildTestButtons(ref),
//               ],
//             ),
//           ],

//           const SizedBox(height: 24),
//           _buildInfoCard(),
//         ],
//       ),
//     );
//   }

//   Widget _buildSectionHeader(String title, String subtitle) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           title,
//           style: const TextStyle(
//             fontSize: 24,
//             fontWeight: FontWeight.bold,
//             color: AppColors.textPrimary,
//           ),
//         ),
//         const SizedBox(height: 8),
//         Text(
//           subtitle,
//           style: const TextStyle(
//             fontSize: 16,
//             color: AppColors.textSecondary,
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildSection(String title, List<Widget> children) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           title,
//           style: const TextStyle(
//             fontSize: 18,
//             fontWeight: FontWeight.w600,
//             color: AppColors.textPrimary,
//           ),
//         ),
//         const SizedBox(height: 12),
//         Card(
//           elevation: 2,
//           child: Column(
//             children: children,
//           ),
//         ),
//         const SizedBox(height: 24),
//       ],
//     );
//   }

//   Widget _buildSwitchTile(
//     String title,
//     String subtitle,
//     bool value,
//     IconData icon,
//     VoidCallback onChanged,
//   ) {
//     return ListTile(
//       leading: Icon(icon, color: AppColors.primary),
//       title: Text(
//         title,
//         style: const TextStyle(
//           fontWeight: FontWeight.w500,
//           color: AppColors.textPrimary,
//         ),
//       ),
//       subtitle: Text(
//         subtitle,
//         style: const TextStyle(
//           color: AppColors.textSecondary,
//           fontSize: 14,
//         ),
//       ),
//       trailing: Switch.adaptive(
//         value: value,
//         onChanged: (_) => onChanged(),
//         activeColor: AppColors.primary,
//       ),
//       contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//     );
//   }

//   Widget _buildSubscribedCategoriesList(
//     BuildContext context,
//     WidgetRef ref,
//     List<String> categories,
//   ) {
//     return Column(
//       children: [
//         for (int i = 0; i < categories.length; i++) ...[
//           ListTile(
//             leading: const Icon(Icons.category, color: AppColors.primary),
//             title: Text('Category ${categories[i]}'),
//             trailing: IconButton(
//               icon: const Icon(Icons.close, color: AppColors.error),
//               onPressed: () => _showUnsubscribeDialog(
//                 context,
//                 'Unsubscribe from Category',
//                 'Are you sure you want to stop receiving notifications for this category?',
//                 () => ref.read(notificationPreferencesProvider.notifier)
//                     .unsubscribeFromCategory(categories[i]),
//               ),
//             ),
//           ),
//           if (i < categories.length - 1) const Divider(height: 1),
//         ],
//       ],
//     );
//   }

//   Widget _buildWishlistedProductsList(
//     BuildContext context,
//     WidgetRef ref,
//     List<String> products,
//   ) {
//     return Column(
//       children: [
//         for (int i = 0; i < products.length; i++) ...[
//           ListTile(
//             leading: const Icon(Icons.favorite, color: AppColors.error),
//             title: Text('Product ${products[i]}'),
//             subtitle: const Text('Price drops & restock alerts'),
//             trailing: IconButton(
//               icon: const Icon(Icons.close, color: AppColors.error),
//               onPressed: () => _showUnsubscribeDialog(
//                 context,
//                 'Remove Product Alert',
//                 'Stop receiving notifications for this product?',
//                 () => ref.read(notificationPreferencesProvider.notifier)
//                     .unsubscribeFromProduct(products[i]),
//               ),
//             ),
//           ),
//           if (i < products.length - 1) const Divider(height: 1),
//         ],
//       ],
//     );
//   }

//   Widget _buildTestButtons(WidgetRef ref) {
//     return Column(
//       children: [
//         ListTile(
//           leading: const Icon(Icons.bug_report, color: AppColors.accent),
//           title: const Text('Test Cart Abandonment'),
//           subtitle: const Text('Send a test cart reminder notification'),
//           trailing: ElevatedButton(
//             onPressed: () async {
//               final service = ref.read(advancedNotificationServiceProvider);
//               await service.sendTestNotification(
//                 NotificationType.cartAbandonment,
//                 data: {'test': true},
//               );
//             },
//             child: const Text('Test'),
//           ),
//         ),
//         const Divider(height: 1),
//         ListTile(
//           leading: const Icon(Icons.local_offer, color: AppColors.accent),
//           title: const Text('Test Price Drop'),
//           subtitle: const Text('Send a test price drop notification'),
//           trailing: ElevatedButton(
//             onPressed: () async {
//               final service = ref.read(advancedNotificationServiceProvider);
//               await service.sendTestNotification(
//                 NotificationType.productPriceDrop,
//                 data: {'product': 'TEST123', 'oldPrice': 100, 'newPrice': 80},
//               );
//             },
//             child: const Text('Test'),
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildInfoCard() {
//     return Card(
//       color: AppColors.primaryLighter.withOpacity(0.1),
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               children: [
//                 Icon(Icons.info_outline, color: AppColors.primary),
//                 const SizedBox(width: 12),
//                 const Text(
//                   'About Notifications',
//                   style: TextStyle(
//                     fontWeight: FontWeight.w600,
//                     fontSize: 16,
//                     color: AppColors.textPrimary,
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 12),
//             const Text(
//               '• Notifications help you stay updated with your shopping\n'
//               '• You can change these settings anytime\n'
//               '• We respect your privacy and won\'t spam you\n'
//               '• Critical order updates will always be sent',
//               style: TextStyle(
//                 color: AppColors.textSecondary,
//                 height: 1.5,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   void _showUnsubscribeDialog(
//     BuildContext context,
//     String title,
//     String message,
//     VoidCallback onConfirm,
//   ) {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: Text(title),
//           content: Text(message),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.of(context).pop(),
//               child: const Text('Cancel'),
//             ),
//             ElevatedButton(
//               onPressed: () {
//                 Navigator.of(context).pop();
//                 onConfirm();
//               },
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: AppColors.error,
//               ),
//               child: const Text('Unsubscribe'),
//             ),
//           ],
//         );
//       },
//     );
//   }
// }