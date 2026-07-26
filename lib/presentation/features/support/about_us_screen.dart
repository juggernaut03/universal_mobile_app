// lib/presentation/features/support/about_us_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import 'package:patelmart/core/widgets/brand_logo.dart';
import '../../providers/support_content_providers.dart';
import '../../../di/infrastructure_providers.dart';


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

  // Method to launch URLs
  Future<void> _launchUrl(String url, WidgetRef ref) async {
    final logger = ref.read(loggerProvider);
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        logger.log('Successfully launched URL: $url');
      } else {
        logger.error('Could not launch URL: $url');
        throw Exception('Could not launch $url');
      }
    } catch (e) {
      logger.error('Error launching URL $url: $e');
      // Show error to user
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
          backgroundColor: Colors.white, // Added white background color
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
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      const BrandLogo(height: 60),
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
                  content: _buildContactContent(context, ref),
                ),
                
                // Developer credit section
                _buildDeveloperCredit(ref),
                
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
                margin: Margins(bottom: Margin(16)),
              ),
              "h1": Style(
                fontSize: FontSize(24),
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
                margin: Margins(bottom: Margin(16), top: Margin(8)),
              ),
              "h2": Style(
                fontSize: FontSize(22),
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
                margin: Margins(bottom: Margin(14), top: Margin(8)),
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
      error: (error, stack) => Builder(
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
                    color: Colors.white,
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

  Widget _buildContactContent(BuildContext context, WidgetRef ref) {
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
          
          // Connect With Us section - Only Facebook and Instagram
          Text(
            'Connect With Us',
            style: AppTextStyles.h6.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Facebook
              _buildSocialButton(
                icon: Icons.facebook,
                color: Colors.blue.shade800,
                label: 'Facebook',
                onPressed: () async {
                  await _launchUrl(
                    'https://www.facebook.com/patelsrmart?mibextid=ZbWKwL',
                    ref,
                  );
                },
              ),
              const SizedBox(width: 32),
              // Instagram
              _buildSocialButton(
                icon: Icons.camera_alt,
                color: Colors.pink.shade600,
                label: 'Instagram',
                onPressed: () async {
                  await _launchUrl(
                    'https://www.instagram.com/patelsrmart?igsh=MWluczZnNjVzejVrYw==',
                    ref,
                  );
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
    required String label,
    required VoidCallback onPressed,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: color,
              size: 28,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildDeveloperCredit(WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            'Developed by',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () async {
              await _launchUrl('https://shalviadvision.com/', ref);
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.web,
                    color: AppColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Shalvi Advision',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}