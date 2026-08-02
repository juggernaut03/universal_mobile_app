// lib/presentation/features/support/help_support_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../providers/support_content_providers.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../di/infrastructure_providers.dart';
import '../../providers/store_details_providers.dart';



class HelpSupportScreen extends ConsumerWidget {
  const HelpSupportScreen({super.key});

  // Custom back navigation handler
  Future<bool> _handleBackPress(BuildContext context, WidgetRef ref) async {
    final logger = ref.read(loggerProvider);
    logger.log('Hardware back button pressed on HelpSupportScreen - navigating to home');
    
    try {
      // Navigate to home using go
      context.go('/home');
      
      // Return false to prevent default back navigation
      return false;
    } catch (e) {
      logger.error('Error handling back navigation: $e');
      // If go fails, try push as fallback
      if (context.mounted) {
        context.pushReplacement('/home');
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storeDetailsAsync = ref.watch(storeDetailsProvider);
    // Tenant-authored guidance, edited in the admin panel. Rendered above the
    // store's contact details, which stay as they are — the two answer
    // different questions ("what do I do?" vs "who do I call?").
    final helpContent = ref.watch(helpSupportContentProvider);

    return PopScope(
      canPop: false, // Prevent default pop behavior
      onPopInvoked: (bool didPop) async {
        if (!didPop) {
          final logger = ref.read(loggerProvider);
          logger.log('PopScope: Back navigation intercepted on HelpSupportScreen - going to home');
          
          // Navigate to home
          if (context.mounted) {
            context.go('/home');
          }
        }
      },
      child: WillPopScope(
        onWillPop: () => _handleBackPress(context, ref),
        child: Scaffold(
          backgroundColor: Colors.white, // Added white background color
          appBar: AppBar(
            title: const Text('Help & Support'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                if (Navigator.canPop(context)) {
                  context.pop();
                } else {
                  context.go('/home');
                }
              },
            ),
          ),
          body: storeDetailsAsync.when(
            data: (storeDetails) {
              if (storeDetails == null) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.store_outlined,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Store information not available',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                );
              }
              
              return SingleChildScrollView(
                child: Column(
                  children: [
                    _buildHelpContent(helpContent),
                    // Header section
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          const CircleAvatar(
                            backgroundColor: Colors.white30,
                            radius: 36,
                            child: Icon(
                              Icons.support_agent,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Need Help?',
                            style: AppTextStyles.h4.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Contact us directly for assistance',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Store Information Card
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Card(
                        color: Colors.white,
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Store Name and Address
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.store,
                                      color: AppColors.primary,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          storeDetails.mobileOutletName,
                                          style: AppTextStyles.h6.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          storeDetails.storeAddress,
                                          style: AppTextStyles.bodyMedium.copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 24),
                              
                              // Store Hours
                              _buildInfoRow(
                                Icons.access_time,
                                'Store Hours',
                                storeDetails.storeOpenTime,
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // Delivery Time
                              _buildInfoRow(
                                Icons.delivery_dining,
                                'Delivery Time',
                                storeDetails.storeDeliveryTime,
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // Minimum Order
                              _buildInfoRow(
                                Icons.shopping_cart,
                                'Minimum Order',
                                '₹${storeDetails.minOrderAmount}',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Contact Options
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Contact Us',
                            style: AppTextStyles.h5.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Phone Contact Card
                          _buildContactCard(
                            icon: Icons.phone,
                            title: 'Call Us',
                            subtitle: storeDetails.contactNumber,
                            color: Colors.green,
                            onTap: () => _makePhoneCall(storeDetails.contactNumber),
                          ),
                          
                          const SizedBox(height: 12),
                          
                          // WhatsApp Contact Card
                          _buildContactCard(
                            icon: Icons.chat,
                            title: 'WhatsApp',
                            subtitle: 'Chat with us on WhatsApp',
                            color: Colors.green.shade600,
                            onTap: () => _openWhatsApp(storeDetails.contactNumber),
                          ),
                          
                          const SizedBox(height: 12),
                          
                          // Email Contact Card
                          _buildContactCard(
                            icon: Icons.email,
                            title: 'Email Us',
                            subtitle: storeDetails.email,
                            color: Colors.blue,
                            onTap: () => _sendEmail(storeDetails.email),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                  ],
                ),
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (error, stack) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Unable to load store information',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => ref.refresh(storeDetailsProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildInfoRow(IconData icon, String title, String value) {
    return Row(
      children: [
        Icon(
          icon,
          color: AppColors.primary,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                value,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      color: Colors.white, // Added white background color for contact cards
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.labelLarge.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: AppColors.textSecondary,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    }
  }

  Future<void> _openWhatsApp(String phoneNumber) async {
    // Remove any non-digit characters and ensure it starts with country code
    String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    if (!cleanNumber.startsWith('91')) {
      cleanNumber = '91$cleanNumber';
    }
    
    final Uri whatsappUri = Uri.parse('https://wa.me/$cleanNumber');
    if (await canLaunchUrl(whatsappUri)) {
      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _sendEmail(String email) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {
        'subject': 'Support Request - PatelMart',
      },
    );
    
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    }
  }

  /// The tenant's Help & Support page, or nothing at all.
  ///
  /// Deliberately renders an empty box while loading and on failure: the store
  /// contact details below are the part a stuck shopper actually needs, and a
  /// spinner or error banner sitting on top of them would get in the way of it.
  Widget _buildHelpContent(AsyncValue<String> contentAsync) {
    return contentAsync.maybeWhen(
      data: (html) => html.trim().isEmpty
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Html(
                data: html,
                style: {
                  'p': Style(
                    fontSize: FontSize(15),
                    color: Colors.black87,
                    margin: Margins(bottom: Margin(12)),
                  ),
                  'h2': Style(
                    fontSize: FontSize(20),
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                    margin: Margins(bottom: Margin(10), top: Margin(4)),
                  ),
                  'li': Style(
                    fontSize: FontSize(15),
                    color: Colors.black87,
                    margin: Margins(bottom: Margin(6)),
                  ),
                },
              ),
            ),
      orElse: () => const SizedBox.shrink(),
    );
  }
}
