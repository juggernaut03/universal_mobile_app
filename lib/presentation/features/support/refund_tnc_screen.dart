import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:patelmart/core/widgets/back_button_wrapper.dart';
import 'package:patelmart/data/services/content_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../providers/launch_flow_provider.dart';

// Provider for refund policy content (GET /api/content/refund-policy)
final refundPolicyContentProvider = FutureProvider<String>((ref) async {
  final logger = ref.read(loggerProvider);
  try {
    logger.log('Fetching refund policy content from API');
    return await ContentService().fetchContentPage('refund-policy');
  } catch (e) {
    logger.error('Error fetching refund policy content: $e');
    throw Exception('Unable to load content. Please check your connection and try again.');
  }
});

// Provider for terms and conditions content (GET /api/content/terms)
final termsConditionsContentProvider = FutureProvider<String>((ref) async {
  final logger = ref.read(loggerProvider);
  try {
    logger.log('Fetching terms and conditions content from API');
    return await ContentService().fetchContentPage('terms');
  } catch (e) {
    logger.error('Error fetching terms and conditions content: $e');
    throw Exception('Unable to load content. Please check your connection and try again.');
  }
});

// Provider for privacy policy content (GET /api/content/privacy-policy)
final privacyPolicyContentProvider = FutureProvider<String>((ref) async {
  final logger = ref.read(loggerProvider);
  try {
    logger.log('Fetching privacy policy content from API');
    return await ContentService().fetchContentPage('privacy-policy');
  } catch (e) {
    logger.error('Error fetching privacy policy content: $e');
    throw Exception('Unable to load content. Please check your connection and try again.');
  }
});

class RefundTncScreen extends ConsumerStatefulWidget {
  const RefundTncScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<RefundTncScreen> createState() => _RefundTncScreenState();
}

class _RefundTncScreenState extends ConsumerState<RefundTncScreen> {
  // Track expanded items
  bool _isTermsExpanded = false;
  bool _isRefundExpanded = false;
  bool _isPrivacyExpanded = false;

  // Custom back navigation handler
  Future<bool> _handleBackPress() async {
    final logger = ref.read(loggerProvider);
    logger.log('Hardware back button pressed on RefundTncScreen - navigating to home');
    
    try {
      context.go('/home');
      return false;
    } catch (e) {
      logger.error('Error handling back navigation: $e');
      if (context.mounted) {
        context.pushReplacement('/home');
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final termsContent = ref.watch(termsConditionsContentProvider);
    final refundContent = ref.watch(refundPolicyContentProvider);
    final privacyContent = ref.watch(privacyPolicyContentProvider);
    
    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) async {
        if (!didPop) {
          final logger = ref.read(loggerProvider);
          logger.log('PopScope: Back navigation intercepted on RefundTncScreen - going to home');
          
          if (context.mounted) {
            context.go('/home');
          }
        }
      },
      child: WillPopScope(
        onWillPop: _handleBackPress,
        child: Scaffold(
          backgroundColor: Colors.white, // Added white background color
          appBar: AppBar(
            title: const Text('Terms & Policies'),
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
              children: [
                // Terms & Conditions Section
                _buildExpandableSection(
                  title: 'Terms & Conditions',
                  subtitle: 'Legal terms and user agreements',
                  isExpanded: _isTermsExpanded,
                  onToggle: () {
                    setState(() {
                      _isTermsExpanded = !_isTermsExpanded;
                    });
                  },
                  content: _buildApiContent(
                    termsContent, 
                    'Terms & Conditions',
                    termsConditionsContentProvider,
                  ),
                ),
                const Divider(height: 1),
                
                // Refund Policy Section
                _buildExpandableSection(
                  title: 'Refund & Return Policy',
                  subtitle: 'Return, refund and delivery policies',
                  isExpanded: _isRefundExpanded,
                  onToggle: () {
                    setState(() {
                      _isRefundExpanded = !_isRefundExpanded;
                    });
                  },
                  content: _buildApiContent(
                    refundContent, 
                    'Refund Policy',
                    refundPolicyContentProvider,
                  ),
                ),
                const Divider(height: 1),
                
                // Privacy Policy Section
                _buildExpandableSection(
                  title: 'Privacy Policy',
                  subtitle: 'Data collection and usage policies',
                  isExpanded: _isPrivacyExpanded,
                  onToggle: () {
                    setState(() {
                      _isPrivacyExpanded = !_isPrivacyExpanded;
                    });
                  },
                  content: _buildApiContent(
                    privacyContent, 
                    'Privacy Policy',
                    privacyPolicyContentProvider,
                  ),
                ),
                const Divider(height: 1),
                
                // Quick Actions Section
                _buildQuickActionsSection(),
                
                // Contact Information Section
                _buildContactSection(),
                
                // Footer
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandableSection({
    required String title,
    required String subtitle,
    required bool isExpanded,
    required VoidCallback onToggle,
    required Widget content,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onToggle,
          child: Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: isExpanded 
                  ? AppColors.primary.withOpacity(0.05)
                  : Colors.white, // Changed to white
              border: Border(
                left: BorderSide(
                  color: isExpanded ? AppColors.primary : Colors.transparent,
                  width: 4,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.h6.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isExpanded ? AppColors.primary : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
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
                  isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: isExpanded ? AppColors.primary : AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
        if (isExpanded) content,
      ],
    );
  }

  Widget _buildApiContent(
    AsyncValue<String> contentAsync, 
    String contentType,
    FutureProvider<String> provider,
  ) {
    return contentAsync.when(
      data: (content) {
        return Container(
          color: Colors.white, // Changed to white
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Html(
              data: content,
              style: {
                "p": Style(
                  fontSize: FontSize(15),
                  fontWeight: FontWeight.w400,
                  color: Colors.black87,
                  margin: Margins(bottom: Margin(14)),
                  lineHeight: LineHeight(1.6),
                ),
                "strong": Style(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
                "h1": Style(
                  fontSize: FontSize(22),
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                  margin: Margins(bottom: Margin(16), top: Margin(20)),
                ),
                "h2": Style(
                  fontSize: FontSize(20),
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                  margin: Margins(bottom: Margin(14), top: Margin(16)),
                ),
                "h3": Style(
                  fontSize: FontSize(18),
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                  margin: Margins(bottom: Margin(12), top: Margin(14)),
                ),
                "br": Style(
                  margin: Margins(bottom: Margin(8)),
                ),
                "ul": Style(
                  margin: Margins(bottom: Margin(16), left: Margin(20)),
                ),
                "ol": Style(
                  margin: Margins(bottom: Margin(16), left: Margin(20)),
                ),
                "li": Style(
                  margin: Margins(bottom: Margin(6)),
                  fontSize: FontSize(15),
                  lineHeight: LineHeight(1.5),
                ),
                "blockquote": Style(
                  backgroundColor: AppColors.primaryLighter.withOpacity(0.1),
                  padding: HtmlPaddings.all(12),
                  margin: Margins(bottom: Margin(16)),
                  border: Border(
                    left: BorderSide(
                      color: AppColors.primary,
                      width: 4,
                    ),
                  ),
                ),
                "table": Style(
                  border: Border.all(color: AppColors.neutral300),
                  margin: Margins(bottom: Margin(16)),
                ),
                "th": Style(
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  padding: HtmlPaddings.all(8),
                  fontWeight: FontWeight.bold,
                ),
                "td": Style(
                  padding: HtmlPaddings.all(8),
                  border: Border.all(color: AppColors.neutral300),
                ),
              },
            ),
          ),
        );
      },
      loading: () => Container(
        color: Colors.white, // Changed to white
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading $contentType...',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
      error: (error, stack) => Builder(
        builder: (context) => Container(
          color: Colors.white, // Changed to white
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.error.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: AppColors.error,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Unable to Load $contentType',
                      style: AppTextStyles.h6.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please check your internet connection and try again.',
                      style: AppTextStyles.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        ProviderScope.containerOf(context).refresh(provider);
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Fallback info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white, // Changed to white
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.neutral300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, 
                             size: 16, 
                             color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Need Immediate Help?',
                          style: AppTextStyles.bodyLarge.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Contact our support team for assistance with $contentType:',
                      style: AppTextStyles.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.phone, size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          '+91 8188252372',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionsSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, // Changed to white
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Actions',
              style: AppTextStyles.h6.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildQuickActionButton(
                    icon: Icons.help_outline,
                    title: 'Get Help',
                    onTap: () => context.push('/help-support'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickActionButton(
                    icon: Icons.info_outline,
                    title: 'About Us',
                    onTap: () => context.push('/about-us'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.neutral300),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w500,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLighter.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.support_agent,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Customer Support',
                  style: AppTextStyles.h5.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Have questions about our policies? We\'re here to help!',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            
            _buildContactItem(
              icon: Icons.phone,
              title: 'Phone Support',
              detail: '+91 8188252372',
              subtitle: 'Available 9 AM - 7 PM',
            ),
            const SizedBox(height: 12),
            _buildContactItem(
              icon: Icons.email,
              title: 'Email Support',
              detail: 'customercare@patelsrmart.com',
              subtitle: 'Get response within 24 hours',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactItem({
    required IconData icon,
    required String title,
    required String detail,
    String? subtitle,
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
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, // Changed to white
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            'Last Updated: December 2024',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '© 2025 Patel\'s Rmart. All rights reserved.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'These terms are governed by Indian law and subject to the jurisdiction of courts in Maharashtra, India. Developed By Shalvi Advision',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}