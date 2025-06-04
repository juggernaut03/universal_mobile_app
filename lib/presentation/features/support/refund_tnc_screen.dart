import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Add this import for ConsumerStatefulWidget
import 'package:go_router/go_router.dart';
import 'package:patelmart/core/widgets/back_button_wrapper.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../providers/launch_flow_provider.dart'; // Add this import for loggerProvider

class RefundTncScreen extends ConsumerStatefulWidget { // Changed to ConsumerStatefulWidget
  const RefundTncScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<RefundTncScreen> createState() => _RefundTncScreenState();
}

class _RefundTncScreenState extends ConsumerState<RefundTncScreen> { // Changed to ConsumerState
  // Track expanded items
  bool _isPricingExpanded = false;
  bool _isTermsExpanded = false;
  bool _isPrivacyExpanded = false;
  bool _isDisclaimerExpanded = false;

  // Custom back navigation handler
  Future<bool> _handleBackPress() async {
    final logger = ref.read(loggerProvider);
    logger.log('Hardware back button pressed on RefundTncScreen - navigating to home');
    
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
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevent default pop behavior
      onPopInvoked: (bool didPop) async {
        if (!didPop) {
          final logger = ref.read(loggerProvider);
          logger.log('PopScope: Back navigation intercepted on RefundTncScreen - going to home');
          
          // Navigate to home
          if (context.mounted) {
            context.go('/home');
          }
        }
      },
      child: WillPopScope(
        onWillPop: _handleBackPress,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Refund, Terms and Policies'),
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
                _buildExpandableSection(
                  title: 'Pricing, Delivery, Return and Refund ',
                  isExpanded: _isPricingExpanded,
                  onToggle: () {
                    setState(() {
                      _isPricingExpanded = !_isPricingExpanded;
                    });
                  },
                  content: _buildPricingAndRefundPolicy(),
                ),
                const Divider(height: 1),
                
                _buildExpandableSection(
                  title: 'Terms & Conditions',
                  isExpanded: _isTermsExpanded,
                  onToggle: () {
                    setState(() {
                      _isTermsExpanded = !_isTermsExpanded;
                    });
                  },
                  content: _buildTermsAndConditions(),
                ),
                const Divider(height: 1),
                
                _buildExpandableSection(
                  title: 'Privacy Policy',
                  isExpanded: _isPrivacyExpanded,
                  onToggle: () {
                    setState(() {
                      _isPrivacyExpanded = !_isPrivacyExpanded;
                    });
                  },
                  content: _buildPrivacyPolicy(),
                ),
                const Divider(height: 1),
                
                _buildExpandableSection(
                  title: 'Disclaimer',
                  isExpanded: _isDisclaimerExpanded,
                  onToggle: () {
                    setState(() {
                      _isDisclaimerExpanded = !_isDisclaimerExpanded;
                    });
                  },
                  content: _buildDisclaimer(),
                ),
                const Divider(height: 1),
                
                // Last updated section
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Last Updated: April 15, 2025',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

  Widget _buildExpandableSection({
    required String title,
    required bool isExpanded,
    required VoidCallback onToggle,
    required Widget content,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: AppTextStyles.h6.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Icon(
                  isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
        ),
        if (isExpanded) content,
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildPricingAndRefundPolicy() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'When you use our Services, you will also be subject to the terms set out in this Pricing, Delivery, Return, and Refund Policy along with the Terms and Conditions, and the Privacy Policy.',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 16),
          
          Text(
            'Pricing and Availability:',
            style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'The prices mentioned for all the products listed on the Website and/or the Mobile App at the time of ordering will be the prices charged on the date of the delivery. We may at our sole discretion also offer products at a reduced price for a limited period on the Services. All prices are inclusive of GST unless stated otherwise.',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 16),
          
          Text(
            'We list availability information for products sold by us on the Website and/or the Mobile App, including on each product information page. However, there may be circumstances where any of the products you order turns out unavailable. We will inform you by email or SMS at the time of processing your order if any products you order turn out to be unavailable.',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 16),
          
          Text(
            'Delivery Policy:',
            style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'We deliver orders within the promised delivery time, which may vary based on your location and the selected delivery slot. In case of any delay, we will notify you promptly. Delivery is subject to availability of products and manpower. We reserve the right to cancel or delay deliveries in case of unforeseen circumstances.',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 16),
          
          Text(
            'Return Policy:',
            style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'You can return products within 7 days of delivery if they are:',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 8),
          _buildBulletPoint('Damaged or defective'),
          _buildBulletPoint('Expired or near expiry'),
          _buildBulletPoint('Not as described on the app'),
          _buildBulletPoint('Wrong product delivered'),
          const SizedBox(height: 16),
          
          Text(
            'For fresh produce and perishable items, returns must be reported within 24 hours of delivery. Returns are subject to verification by our team. We reserve the right to decline returns that don\'t meet our policy criteria.',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 16),
          
          Text(
            'Refund Policy:',
            style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Refunds will be processed within 5-7 business days after the return is verified. The refund will be issued to the original payment method used during purchase. For cash on delivery orders, refunds will be processed via bank transfer or as store credit, as per your preference.',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Please note that shipping charges, if any, are non-refundable except in cases where the return is due to our error.',
            style: AppTextStyles.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildTermsAndConditions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Detailed terms and conditions will be displayed here.',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 16),
          
          Text(
            '1. Acceptance of Terms',
            style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'By accessing or using Patel\'s Rmart services, including our mobile application, website, and delivery services, you agree to be bound by these Terms and Conditions. If you do not agree to these terms, please refrain from using our services.',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 16),
          
          Text(
            '2. Account Registration',
            style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'You must register an account to use certain features of our services. You agree to provide accurate, current, and complete information during registration and to update such information to keep it accurate, current, and complete. You are responsible for safeguarding your account credentials and for all activities that occur under your account.',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 16),
          
          Text(
            '3. Products and Services',
            style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'We strive to provide accurate product information, including descriptions, pricing, and availability. However, errors may occur. We reserve the right to correct any errors and to change or update information at any time without prior notice.',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 16),
          
          Text(
            '4. Intellectual Property',
            style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'All content, including text, graphics, logos, and software, is the property of Patel\'s Rmart and is protected by intellectual property laws. You may not reproduce, distribute, or create derivative works from this content without express written permission.',
            style: AppTextStyles.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyPolicy() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '1. Information We Collect',
            style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'We collect information you provide directly, such as name, address, email, phone number, and payment information. We also collect data about your usage of our services, device information, and location data (with your permission).',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 16),
          
          Text(
            '2. How We Use Your Information',
            style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'We use your information to process orders, provide customer service, improve our services, send promotional communications (if you opt in), and comply with legal obligations. We may use anonymized data for business analytics and market research.',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 16),
          
          Text(
            '3. Information Sharing',
            style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'We may share your information with delivery partners, payment processors, and service providers who help us operate our business. We do not sell your personal information to third parties. We may disclose information if required by law or to protect our rights or the safety of others.',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 16),
          
          Text(
            '4. Data Security',
            style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'We implement appropriate technical and organizational measures to protect your personal information. However, no method of transmission over the Internet or electronic storage is 100% secure. We cannot guarantee absolute security.',
            style: AppTextStyles.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Disclaimer of Warranties:',
            style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'OUR SERVICES ARE PROVIDED ON AN "AS IS" AND "AS AVAILABLE" BASIS. PATEL\'S RMART MAKES NO REPRESENTATIONS OR WARRANTIES OF ANY KIND, EXPRESS OR IMPLIED, REGARDING THE OPERATION OF OUR SERVICES OR THE INFORMATION, CONTENT, MATERIALS, OR PRODUCTS INCLUDED.',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 16),
          
          Text(
            'TO THE FULLEST EXTENT PERMISSIBLE BY APPLICABLE LAW, PATEL\'S RMART DISCLAIMS ALL WARRANTIES, EXPRESS OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. PATEL\'S RMART DOES NOT WARRANT THAT THE SERVICES, INFORMATION, CONTENT, MATERIALS, OR PRODUCTS INCLUDED WILL BE UNINTERRUPTED OR ERROR-FREE.',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 16),
          
          Text(
            'Limitation of Liability:',
            style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'PATEL\'S RMART SHALL NOT BE LIABLE FOR ANY DAMAGES OF ANY KIND ARISING FROM THE USE OF OUR SERVICES, INCLUDING, BUT NOT LIMITED TO, DIRECT, INDIRECT, INCIDENTAL, PUNITIVE, AND CONSEQUENTIAL DAMAGES, EVEN IF PATEL\'S RMART HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 16),
          
          Text(
            'Indemnification:',
            style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'You agree to indemnify, defend, and hold harmless Patel\'s Rmart, its affiliates, and their respective officers, directors, employees, agents, and representatives from and against any and all claims, damages, costs, and expenses, including attorneys\' fees, arising from or related to your use of our services or your violation of these Terms and Conditions.',
            style: AppTextStyles.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
