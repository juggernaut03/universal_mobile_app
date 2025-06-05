// lib/presentation/features/support/about_us_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:patelmart/core/widgets/back_button_wrapper.dart';
import 'package:patelmart/presentation/providers/launch_flow_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/cached_network_image_widget.dart';

// Provider for about us content
final aboutUsContentProvider = FutureProvider<String>((ref) async {
  final logger = ref.read(loggerProvider);
  try {
    logger.log('Fetching about us content from API');
    final response = await http.get(
      Uri.parse('https://newtech.shalviadvision.com/api/about_us_screen'),
    );
    
    // Consider any 2xx status code as success
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body);
      
      // Check for message field, but also handle other possible formats
      if (data.containsKey('message')) {
        return data['message'] as String;
      } else if (data.containsKey('content')) {
        return data['content'] as String;
      } else if (data is String) {
        return data;
      } else {
        // Handle case where response is valid but doesn't match expected format
        logger.error('Unexpected response format: $data');
        return 'Welcome to Patel\'s Rmart - Your daily partner! Information about our company will be available soon.';
      }
    }
    
    logger.error('Failed to load about us content: ${response.statusCode}');
    throw Exception('Failed to load about us content: ${response.statusCode}');
  } catch (e) {
    logger.error('Error fetching about us content: $e');
    throw Exception('Unable to load content. Please check your connection and try again.');
  }
});

class AboutUsScreen extends ConsumerWidget {
  const AboutUsScreen({Key? key}) : super(key: key);

  // Custom back navigation handler
  Future<bool> _handleBackPress(BuildContext context, WidgetRef ref) async {
    final logger = ref.read(loggerProvider);
    logger.log('Hardware back button pressed on AboutUsScreen - navigating to home');
    
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
    final aboutUsContent = ref.watch(aboutUsContentProvider);
    
    return PopScope(
      canPop: false, // Prevent default pop behavior
      onPopInvoked: (bool didPop) async {
        if (!didPop) {
          final logger = ref.read(loggerProvider);
          logger.log('PopScope: Back navigation intercepted on AboutUsScreen - going to home');
          
          // Navigate to home
          if (context.mounted) {
            context.go('/home');
          }
        }
      },
      child: WillPopScope(
        onWillPop: () => _handleBackPress(context, ref),
        child: Scaffold(
          appBar: AppBar(
            title: const Text('About Us'),
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
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo and tagline
                Container(
                  color: AppColors.neutral100,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      Image.asset(
                        'assets/images/patelLogo.png',
                        height: 60,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Your daily partner!',
                        style: AppTextStyles.h6.copyWith(
                          color: AppColors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // About Us Content from API
                _buildApiContent(aboutUsContent),
                
                // Contact Us section
                _buildSection(
                  title: 'Contact Us',
                  icon: Icons.contact_mail,
                  content: _buildContactContent(context),
                ),
                
                // Version info at bottom
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        'App Version: 5.2.1',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '© 2025 Patel\'s Rmart. All rights reserved.',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  Widget _buildApiContent(AsyncValue<String> contentAsync) {
  return contentAsync.when(
    data: (content) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Html(
          data: content,
          style: {
            "p": Style(
              fontSize: FontSize(16),
              fontWeight: FontWeight.w400,
              color: Colors.black87,
              margin: Margins(bottom: Margin(16)), // Corrected: Using Margin object
            ),
            "h1": Style(
              fontSize: FontSize(24),
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
              margin: Margins(bottom: Margin(16), top: Margin(8)), // Corrected: Using Margin objects
            ),
            "h2": Style(
              fontSize: FontSize(22),
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
              margin: Margins(bottom: Margin(14), top: Margin(8)), // Corrected: Using Margin objects
            ),
          },
        ),
      );
    },
    loading: () => const Center(
      child: Padding(
        padding: EdgeInsets.all(32.0),
        child: CircularProgressIndicator(),
      ),
    ),
    error: (error, stack) => Builder(  // Added Builder to get context
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading content',
              style: AppTextStyles.h6.copyWith(
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: AppTextStyles.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Refresh the provider using context from Builder
                ProviderScope.containerOf(context).refresh(aboutUsContentProvider);
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    ),
  );
}
  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget content,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLighter.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: AppTextStyles.h5.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          content,
        ],
      ),
    );
  }

  Widget _buildContactContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Contact Information
          _buildContactItem(
            icon: Icons.email,
            title: 'Email',
            detail: 'customercare@patelsrmart.com',
          ),
          const SizedBox(height: 12),
          _buildContactItem(
            icon: Icons.phone,
            title: 'Customer Support',
            detail: '+91 8188252372 (9 AM - 7 PM)',
          ),
          const SizedBox(height: 12),
          _buildContactItem(
            icon: Icons.location_on,
            title: 'Corporate Office',
            detail: 'Patel Retail Ltd., Plot No. 23, MIDC Area, Ambarnath East, Thane - 421501',
          ),
          const SizedBox(height: 24),
          
          // Connect With Us section
          Text(
            'Connect With Us',
            style: AppTextStyles.h6.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSocialButton(
                icon: Icons.facebook,
                color: Colors.blue.shade800,
                onPressed: () {
                  // Open Facebook
                },
              ),
              _buildSocialButton(
                icon: Icons.camera_alt,
                color: Colors.pink.shade600,
                onPressed: () {
                  // Open Instagram
                },
              ),
              _buildSocialButton(
                icon: Icons.messenger_outline,
                color: Colors.blue.shade400,
                onPressed: () {
                  // Open Twitter
                },
              ),
              _buildSocialButton(
                icon: Icons.play_arrow,
                color: Colors.red.shade600,
                onPressed: () {
                  // Open YouTube
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Help button
          Center(
            child: ElevatedButton.icon(
              onPressed: () {
                context.push('/help-support');
              },
              icon: const Icon(Icons.help_outline),
              label: const Text('Get Help & Support'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactItem({
    required IconData icon,
    required String title,
    required String detail,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primaryLighter.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: AppColors.primary,
            size: 20,
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
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                detail,
                style: AppTextStyles.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: color,
          size: 24,
        ),
      ),
    );
  }
}