// // lib/presentation/features/product/widgets/product_notification_widget.dart

// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import '../../../../core/constants/app_colors.dart';
// import '../../../../data/models/product_model.dart';
// import '../../../providers/notification_preferences_provider.dart';
// import '../../../providers/auth_providers.dart';

// class ProductNotificationWidget extends ConsumerWidget {
//   final ProductModel product;
//   final bool showAsButton;
//   final EdgeInsetsGeometry? padding;

//   const ProductNotificationWidget({
//     Key? key,
//     required this.product,
//     this.showAsButton = false,
//     this.padding,
//   }) : super(key: key);

//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     final isLoggedInAsync = ref.watch(isLoggedInProvider);
//     final subscriptionAsync = ref.watch(productSubscriptionProvider(product.pCode));

//     return isLoggedInAsync.when(
//       data: (isLoggedIn) {
//         if (!isLoggedIn) {
//           return _buildLoginPrompt(context);
//         }

//         return subscriptionAsync.when(
//           data: (isSubscribed) => _buildSubscriptionWidget(
//             context,
//             ref,
//             isSubscribed,
//           ),
//           loading: () => _buildLoadingWidget(),
//           error: (error, stack) => _buildErrorWidget(context, ref),
//         );
//       },
//       loading: () => _buildLoadingWidget(),
//       error: (error, stack) => _buildLoginPrompt(context),
//     );
//   }

//   Widget _buildSubscriptionWidget(
//     BuildContext context,
//     WidgetRef ref,
//     bool isSubscribed,
//   ) {
//     if (showAsButton) {
//       return _buildSubscriptionButton(context, ref, isSubscribed);
//     } else {
//       return _buildSubscriptionRow(context, ref, isSubscribed);
//     }
//   }

//   Widget _buildSubscriptionButton(
//     BuildContext context,
//     WidgetRef ref,
//     bool isSubscribed,
//   ) {
//     return Padding(
//       padding: padding ?? const EdgeInsets.all(8.0),
//       child: OutlinedButton.icon(
//         onPressed: () => _toggleSubscription(ref, isSubscribed),
//         icon: Icon(
//           isSubscribed ? Icons.notifications_active : Icons.notifications_none,
//           size: 18,
//         ),
//         label: Text(
//           isSubscribed ? 'Subscribed' : 'Get Alerts',
//           style: const TextStyle(fontSize: 12),
//         ),
//         style: OutlinedButton.styleFrom(
//           foregroundColor: isSubscribed ? AppColors.success : AppColors.primary,
//           side: BorderSide(
//             color: isSubscribed ? AppColors.success : AppColors.primary,
//           ),
//           padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//           minimumSize: const Size(0, 32),
//         ),
//       ),
//     );
//   }

//   Widget _buildSubscriptionRow(
//     BuildContext context,
//     WidgetRef ref,
//     bool isSubscribed,
//   ) {
//     return Container(
//       padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//       decoration: BoxDecoration(
//         color: isSubscribed 
//             ? AppColors.successLight.withOpacity(0.1)
//             : AppColors.primaryLighter.withOpacity(0.1),
//         borderRadius: BorderRadius.circular(8),
//         border: Border.all(
//           color: isSubscribed ? AppColors.success : AppColors.primary,
//           width: 1,
//         ),
//       ),
//       child: Row(
//         children: [
//           Icon(
//             isSubscribed ? Icons.notifications_active : Icons.notifications_none,
//             color: isSubscribed ? AppColors.success : AppColors.primary,
//             size: 20,
//           ),
//           const SizedBox(width: 12),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   isSubscribed ? 'You\'ll get notified' : 'Get notifications',
//                   style: TextStyle(
//                     fontWeight: FontWeight.w500,
//                     color: isSubscribed ? AppColors.success : AppColors.primary,
//                     fontSize: 14,
//                   ),
//                 ),
//                 Text(
//                   isSubscribed 
//                       ? 'Price drops & restock alerts enabled'
//                       : 'For price drops & when back in stock',
//                   style: const TextStyle(
//                     color: AppColors.textSecondary,
//                     fontSize: 12,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           Switch.adaptive(
//             value: isSubscribed,
//             onChanged: (_) => _toggleSubscription(ref, isSubscribed),
//             activeColor: AppColors.success,
//             materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildLoginPrompt(BuildContext context) {
//     if (showAsButton) {
//       return Padding(
//         padding: padding ?? const EdgeInsets.all(8.0),
//         child: OutlinedButton.icon(
//           onPressed: () => _navigateToLogin(context),
//           icon: const Icon(Icons.login, size: 18),
//           label: const Text('Login for Alerts', style: TextStyle(fontSize: 12)),
//           style: OutlinedButton.styleFrom(
//             foregroundColor: AppColors.primary,
//             side: const BorderSide(color: AppColors.primary),
//             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//             minimumSize: const Size(0, 32),
//           ),
//         ),
//       );
//     }

//     return Container(
//       padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//       decoration: BoxDecoration(
//         color: AppColors.primaryLighter.withOpacity(0.1),
//         borderRadius: BorderRadius.circular(8),
//         border: Border.all(color: AppColors.primary, width: 1),
//       ),
//       child: Row(
//         children: [
//           const Icon(Icons.login, color: AppColors.primary, size: 20),
//           const SizedBox(width: 12),
//           const Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   'Login to get alerts',
//                   style: TextStyle(
//                     fontWeight: FontWeight.w500,
//                     color: AppColors.primary,
//                     fontSize: 14,
//                   ),
//                 ),
//                 Text(
//                   'Get notified of price drops & restocks',
//                   style: TextStyle(
//                     color: AppColors.textSecondary,
//                     fontSize: 12,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           TextButton(
//             onPressed: () => _navigateToLogin(context),
//             child: const Text('Login'),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildLoadingWidget() {
//     return Container(
//       padding: padding ?? const EdgeInsets.all(16),
//       child: Row(
//         children: [
//           SizedBox(
//             width: 16,
//             height: 16,
//             child: CircularProgressIndicator(
//               strokeWidth: 2,
//               valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
//             ),
//           ),
//           const SizedBox(width: 12),
//           const Text(
//             'Loading notification settings...',
//             style: TextStyle(
//               color: AppColors.textSecondary,
//               fontSize: 12,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildErrorWidget(BuildContext context, WidgetRef ref) {
//     return Container(
//       padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//       decoration: BoxDecoration(
//         color: AppColors.errorLight.withOpacity(0.1),
//         borderRadius: BorderRadius.circular(8),
//         border: Border.all(color: AppColors.error, width: 1),
//       ),
//       child: Row(
//         children: [
//           const Icon(Icons.error_outline, color: AppColors.error, size: 20),
//           const SizedBox(width: 12),
//           const Expanded(
//             child: Text(
//               'Unable to load notification settings',
//               style: TextStyle(
//                 color: AppColors.error,
//                 fontSize: 12,
//               ),
//             ),
//           ),
//           TextButton(
//             onPressed: () => ref.refresh(productSubscriptionProvider(product.pCode)),
//             child: const Text('Retry', style: TextStyle(fontSize: 12)),
//           ),
//         ],
//       ),
//     );
//   }

//   void _toggleSubscription(WidgetRef ref, bool isCurrentlySubscribed) {
//     final notifier = ref.read(notificationPreferencesProvider.notifier);
//     if (isCurrentlySubscribed) {
//       notifier.unsubscribeFromProduct(product.pCode);
//     } else {
//       notifier.subscribeToProduct(product.pCode);
//     }
//   }

//   void _navigateToLogin(BuildContext context) {
//     // Navigate to login screen
//     // You can implement this based on your routing setup
//     Navigator.pushNamed(context, '/auth/login');
//   }
// }

// // Helper widget for quick product notification toggle
// class QuickNotificationToggle extends ConsumerWidget {
//   final String productCode;
//   final String productName;

//   const QuickNotificationToggle({
//     Key? key,
//     required this.productCode,
//     required this.productName,
//   }) : super(key: key);

//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     final subscriptionAsync = ref.watch(productSubscriptionProvider(productCode));

//     return subscriptionAsync.when(
//       data: (isSubscribed) => InkWell(
//         onTap: () => _toggleSubscription(ref, isSubscribed),
//         borderRadius: BorderRadius.circular(20),
//         child: Container(
//           padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//           decoration: BoxDecoration(
//             color: isSubscribed 
//                 ? AppColors.success.withOpacity(0.1)
//                 : Colors.transparent,
//             borderRadius: BorderRadius.circular(20),
//             border: Border.all(
//               color: isSubscribed ? AppColors.success : AppColors.neutral400,
//             ),
//           ),
//           child: Row(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Icon(
//                 isSubscribed ? Icons.notifications_active : Icons.notifications_none,
//                 size: 16,
//                 color: isSubscribed ? AppColors.success : AppColors.textSecondary,
//               ),
//               const SizedBox(width: 6),
//               Text(
//                 isSubscribed ? 'Subscribed' : 'Notify me',
//                 style: TextStyle(
//                   fontSize: 12,
//                   color: isSubscribed ? AppColors.success : AppColors.textSecondary,
//                   fontWeight: FontWeight.w500,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//       loading: () => const SizedBox(
//         width: 16,
//         height: 16,
//         child: CircularProgressIndicator(strokeWidth: 2),
//       ),
//       error: (error, stack) => const Icon(
//         Icons.error_outline,
//         size: 16,
//         color: AppColors.error,
//       ),
//     );
//   }

//   void _toggleSubscription(WidgetRef ref, bool isCurrentlySubscribed) {
//     final notifier = ref.read(notificationPreferencesProvider.notifier);
//     if (isCurrentlySubscribed) {
//       notifier.unsubscribeFromProduct(productCode);
//     } else {
//       notifier.subscribeToProduct(productCode);
//     }
//   }
// }