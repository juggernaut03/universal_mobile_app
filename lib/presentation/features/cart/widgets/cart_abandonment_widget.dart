// // lib/presentation/features/cart/widgets/cart_abandonment_widget.dart

// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import '../../../../core/constants/app_colors.dart';
// import '../../../providers/cart_provider.dart';
// import '../../../providers/notification_preferences_provider.dart';
// import '../../../providers/auth_providers.dart';

// class CartAbandonmentWidget extends ConsumerStatefulWidget {
//   const CartAbandonmentWidget({Key? key}) : super(key: key);

//   @override
//   ConsumerState<CartAbandonmentWidget> createState() => _CartAbandonmentWidgetState();
// }

// class _CartAbandonmentWidgetState extends ConsumerState<CartAbandonmentWidget> {
//   bool _isVisible = true;
  
//   @override
//   Widget build(BuildContext context) {
//     final cartItems = ref.watch(cartProvider);
//     final isLoggedInAsync = ref.watch(isLoggedInProvider);
//     final preferencesAsync = ref.watch(notificationPreferencesProvider);

//     // Only show if cart has items and user is logged in
//     return isLoggedInAsync.when(
//       data: (isLoggedIn) {
//         if (!isLoggedIn || cartItems.isEmpty || !_isVisible) {
//           return const SizedBox.shrink();
//         }

//         return preferencesAsync.when(
//           data: (preferences) {
//             if (!preferences.cartReminders) {
//               return const SizedBox.shrink();
//             }
//             return _buildWidget(context, cartItems.length);
//           },
//           loading: () => const SizedBox.shrink(),
//           error: (error, stack) => const SizedBox.shrink(),
//         );
//       },
//       loading: () => const SizedBox.shrink(),
//       error: (error, stack) => const SizedBox.shrink(),
//     );
//   }

//   Widget _buildWidget(BuildContext context, int itemCount) {
//     return AnimatedContainer(
//       duration: const Duration(milliseconds: 300),
//       margin: const EdgeInsets.all(16),
//       child: Card(
//         elevation: 4,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//         child: Container(
//           decoration: BoxDecoration(
//             borderRadius: BorderRadius.circular(12),
//             gradient: LinearGradient(
//               colors: [
//                 AppColors.accent.withOpacity(0.1),
//                 AppColors.primaryLight.withOpacity(0.1),
//               ],
//               begin: Alignment.topLeft,
//               end: Alignment.bottomRight,
//             ),
//           ),
//           child: Padding(
//             padding: const EdgeInsets.all(16),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Row(
//                   children: [
//                     Container(
//                       padding: const EdgeInsets.all(8),
//                       decoration: BoxDecoration(
//                         color: AppColors.accent.withOpacity(0.2),
//                         borderRadius: BorderRadius.circular(8),
//                       ),
//                       child: const Icon(
//                         Icons.notifications_active,
//                         color: AppColors.accent,
//                         size: 20,
//                       ),
//                     ),
//                     const SizedBox(width: 8),
//           Text(
//             text,
//             style: const TextStyle(
//               fontSize: 14,
//               color: AppColors.textSecondary,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }(width: 12),
//                     Expanded(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           const Text(
//                             'Smart Reminders Enabled',
//                             style: TextStyle(
//                               fontWeight: FontWeight.w600,
//                               fontSize: 16,
//                               color: AppColors.textPrimary,
//                             ),
//                           ),
//                           Text(
//                             'We\'ll remind you about your $itemCount item${itemCount > 1 ? 's' : ''} if you forget',
//                             style: const TextStyle(
//                               color: AppColors.textSecondary,
//                               fontSize: 14,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                     IconButton(
//                       onPressed: () => setState(() => _isVisible = false),
//                       icon: const Icon(Icons.close, size: 20),
//                       color: AppColors.textSecondary,
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 12),
//                 Row(
//                   children: [
//                     _buildFeatureChip('1 hour reminder', Icons.schedule),
//                     const SizedBox(width: 8),
//                     _buildFeatureChip('24 hour reminder', Icons.event),
//                     const SizedBox(width: 8),
//                     _buildFeatureChip('Smart timing', Icons.psychology),
//                   ],
//                 ),
//                 const SizedBox(height: 12),
//                 Row(
//                   children: [
//                     TextButton.icon(
//                       onPressed: () => _showReminderSettings(context),
//                       icon: const Icon(Icons.settings, size: 16),
//                       label: const Text('Settings'),
//                       style: TextButton.styleFrom(
//                         foregroundColor: AppColors.primary,
//                         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//                       ),
//                     ),
//                     const Spacer(),
//                     TextButton.icon(
//                       onPressed: () => _disableReminders(),
//                       icon: const Icon(Icons.notifications_off, size: 16),
//                       label: const Text('Disable'),
//                       style: TextButton.styleFrom(
//                         foregroundColor: AppColors.error,
//                         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildFeatureChip(String label, IconData icon) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//       decoration: BoxDecoration(
//         color: AppColors.primary.withOpacity(0.1),
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: AppColors.primary.withOpacity(0.3)),
//       ),
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Icon(icon, size: 12, color: AppColors.primary),
//           const SizedBox(width: 4),
//           Text(
//             label,
//             style: const TextStyle(
//               fontSize: 11,
//               color: AppColors.primary,
//               fontWeight: FontWeight.w500,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   void _showReminderSettings(BuildContext context) {
//     showModalBottomSheet(
//       context: context,
//       shape: const RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
//       ),
//       builder: (context) => const CartReminderSettingsSheet(),
//     );
//   }

//   void _disableReminders() {
//     ref.read(notificationPreferencesProvider.notifier).toggleCartReminders();
//     setState(() => _isVisible = false);
    
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: const Text('Cart reminders disabled'),
//         action: SnackBarAction(
//           label: 'Undo',
//           onPressed: () {
//             ref.read(notificationPreferencesProvider.notifier).toggleCartReminders();
//             setState(() => _isVisible = true);
//           },
//         ),
//       ),
//     );
//   }
// }

// class CartReminderSettingsSheet extends ConsumerWidget {
//   const CartReminderSettingsSheet({Key? key}) : super(key: key);

//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     final preferencesAsync = ref.watch(notificationPreferencesProvider);

//     return Container(
//       padding: const EdgeInsets.all(24),
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               const Icon(Icons.shopping_cart_outlined, color: AppColors.primary),
//               const SizedBox(width: 12),
//               const Expanded(
//                 child: Text(
//                   'Cart Reminder Settings',
//                   style: TextStyle(
//                     fontSize: 20,
//                     fontWeight: FontWeight.bold,
//                     color: AppColors.textPrimary,
//                   ),
//                 ),
//               ),
//               IconButton(
//                 onPressed: () => Navigator.of(context).pop(),
//                 icon: const Icon(Icons.close),
//               ),
//             ],
//           ),
//           const SizedBox(height: 24),
          
//           preferencesAsync.when(
//             data: (preferences) => Column(
//               children: [
//                 SwitchListTile(
//                   title: const Text('Enable Cart Reminders'),
//                   subtitle: const Text('Get notified about items left in your cart'),
//                   value: preferences.cartReminders,
//                   onChanged: (_) => ref.read(notificationPreferencesProvider.notifier)
//                       .toggleCartReminders(),
//                   activeColor: AppColors.primary,
//                 ),
//                 const Divider(),
                
//                 if (preferences.cartReminders) ...[
//                   const ListTile(
//                     leading: Icon(Icons.schedule, color: AppColors.accent),
//                     title: Text('Reminder Schedule'),
//                     subtitle: Text('Optimized timing for best results'),
//                   ),
//                   Padding(
//                     padding: const EdgeInsets.symmetric(horizontal: 16),
//                     child: Column(
//                       children: [
//                         _buildScheduleItem('1 hour after adding items'),
//                         _buildScheduleItem('24 hours if cart not updated'),
//                         _buildScheduleItem('Smart timing based on your activity'),
//                       ],
//                     ),
//                   ),
//                   const SizedBox(height: 16),
                  
//                   Container(
//                     padding: const EdgeInsets.all(16),
//                     decoration: BoxDecoration(
//                       color: AppColors.infoLight,
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                     child: Row(
//                       children: [
//                         Icon(Icons.info_outline, color: AppColors.info),
//                         const SizedBox(width: 12),
//                         const Expanded(
//                           child: Text(
//                             'Reminders are sent only when you\'re likely to be available, and never more than once per day.',
//                             style: TextStyle(
//                               fontSize: 14,
//                               color: AppColors.textSecondary,
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ],
//               ],
//             ),
//             loading: () => const Center(child: CircularProgressIndicator()),
//             error: (error, stack) => const Center(
//               child: Text('Error loading settings'),
//             ),
//           ),
          
//           const SizedBox(height: 24),
//           SizedBox(
//             width: double.infinity,
//             child: ElevatedButton(
//               onPressed: () => Navigator.of(context).pop(),
//               child: const Text('Done'),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // Widget _buildScheduleItem(String text) {
//   //   return Padding(
//   //     padding: const EdgeInsets.symmetric(vertical: 4),
//   //     child: Row(
//   //       children: [
//   //         const Icon(Icons.check_circle, size: 16, color: AppColors.success),
//   //         const SizedBox