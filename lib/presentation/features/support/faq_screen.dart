// lib/presentation/features/support/faq_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:patelmart/core/widgets/back_button_wrapper.dart';
import 'package:patelmart/presentation/providers/launch_flow_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class FAQScreen extends ConsumerStatefulWidget {
  const FAQScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<FAQScreen> createState() => _FAQScreenState();
}

class _FAQScreenState extends ConsumerState<FAQScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<FAQCategory> allCategories = [];
  List<FAQCategory> filteredCategories = [];

  @override
  void initState() {
    super.initState();
    _initFAQData();
    filteredCategories = allCategories;
    _searchController.addListener(_filterFAQs);
  }

  // Custom back navigation handler - matches the pattern from category and cart screens
  Future<bool> _handleBackPress() async {
    final logger = ref.read(loggerProvider);
    logger.log('Hardware back button pressed on FAQScreen - navigating to home');
    
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

  void _initFAQData() {
    allCategories = [
      FAQCategory(
        title: 'Patel Rmart',
        faqs: [
          FAQ(
            question: 'What is Patel Rmart?',
            answer:
                'Patel Rmart is a retail chain offering groceries, personal care items, household essentials, and more at competitive prices. Founded in 1990, we aim to provide quality products with excellent customer service.',
          ),
          FAQ(
            question: 'What are Patel Rmart\'s operating hours?',
            answer:
                'Most Patel Rmart stores operate from 8:00 AM to 10:00 PM, seven days a week. However, hours may vary by location. You can check specific store hours in the Store Information section.',
          ),
        ],
      ),
      FAQCategory(
        title: 'PRODUCT',
        faqs: [
          FAQ(
            question: 'I am not able to find a product that I want.',
            answer:
                'If you can\'t find a product, you can use the search feature at the top of the app. If the product still doesn\'t appear, it may be temporarily out of stock or not available at your selected store. You can request the product by contacting our customer support.',
          ),
          FAQ(
            question: 'Product I received differs from the one displayed on the site, what do I do?',
            answer:
                'We\'re sorry for the inconvenience. Please take a photo of the product you received and raise a support ticket in the Help & Support section. Our team will review your case and provide a solution within 24-48 hours. You may be eligible for a return or replacement.',
          ),
          FAQ(
            question: 'How can I check if a product is in stock?',
            answer:
                'Product availability is shown on each product page. If a product is out of stock, it will be marked as "Out of Stock" or you may not be able to add it to your cart. Stock information is updated regularly but may occasionally differ from actual store inventory.',
          ),
        ],
      ),
      FAQCategory(
        title: 'ORDERING',
        faqs: [
          FAQ(
            question: 'Is there a way I can re-order from my previous order?',
            answer:
                'Yes! You can easily reorder items from your order history. Go to My Account > My Orders, find the order you want to repeat, and tap "Reorder". You can add all items to your cart with one click and proceed to checkout.',
          ),
          FAQ(
            question: 'What payment methods are accepted?',
            answer:
                'We accept multiple payment methods including credit/debit cards, UPI payments (BHIM, Google Pay, PhonePe), net banking, and cash on delivery. All online payments are secure and processed through verified payment gateways.',
          ),
          FAQ(
            question: 'Is there a minimum order value?',
            answer:
                'Yes, there is a minimum order value that varies by location. The minimum order amount will be displayed during checkout. Orders below the minimum value may incur an additional delivery fee.',
          ),
        ],
      ),
      FAQCategory(
        title: 'DELIVERY',
        faqs: [
          FAQ(
            question: 'How long will it take to deliver my order?',
            answer:
                'Delivery times vary based on your location and the selected store. Typically, orders are delivered within 2-3 hours for same-day delivery if placed before 6 PM. You can see the estimated delivery time during checkout.',
          ),
          FAQ(
            question: 'Do you deliver to my area?',
            answer:
                'Our delivery service is available in select areas. You can check if we deliver to your location by entering your pincode in the location section. We are continuously expanding our delivery network to serve more areas.',
          ),
          FAQ(
            question: 'Can I change my delivery address after placing an order?',
            answer:
                'Address changes can only be accommodated if the order hasn\'t been processed for delivery yet. Please contact our customer support immediately if you need to change your delivery address.',
          ),
        ],
      ),
      FAQCategory(
        title: 'RETURNS & REFUNDS',
        faqs: [
          FAQ(
            question: 'What is your return policy?',
            answer:
                'You can return products within 7 days of delivery if they are damaged, expired, or not as described. Fresh produce and perishable items must be reported within 24 hours of delivery. For detailed information, please refer to our Return and Refund Policy.',
          ),
          FAQ(
            question: 'How do I return a product?',
            answer:
                'To return a product, go to My Account > My Orders > Select the order > Choose the item to return > Select return reason > Request Return. Our delivery personnel will pick up the item, or you can drop it at the store. After verification, your refund will be processed.',
          ),
          FAQ(
            question: 'How long does it take to get a refund?',
            answer:
                'Refunds are typically processed within 5-7 business days after the returned product is received and verified. The time for the refund to appear in your account depends on your payment method and bank processing times.',
          ),
        ],
      ),
      FAQCategory(
        title: 'ACCOUNT & PROFILE',
        faqs: [
          FAQ(
            question: 'How do I create an account?',
            answer:
                'You can create an account by clicking on the "Login" button and selecting "Register". Enter your mobile number, verify with OTP, and complete your profile information. You can also sign up during checkout if you don\'t have an account.',
          ),
          FAQ(
            question: 'I forgot my password. How can I reset it?',
            answer:
                'On the login screen, click "Forgot Password". Enter your registered mobile number to receive an OTP. Use the OTP to verify your identity and set a new password.',
          ),
        ],
      ),
    ];
  }

  void _filterFAQs() {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      setState(() {
        filteredCategories = allCategories;
      });
      return;
    }

    final filtered = allCategories.map((category) {
      final filteredFaqs = category.faqs.where((faq) {
        return faq.question.toLowerCase().contains(query) ||
            faq.answer.toLowerCase().contains(query);
      }).toList();

      return FAQCategory(
        title: category.title,
        faqs: filteredFaqs,
      );
    }).where((category) => category.faqs.isNotEmpty).toList();

    setState(() {
      filteredCategories = filtered;
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterFAQs);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevent default pop behavior
      onPopInvoked: (bool didPop) async {
        if (!didPop) {
          final logger = ref.read(loggerProvider);
          logger.log('PopScope: Back navigation intercepted on FAQScreen - going to home');
          
          // Navigate to home
          if (context.mounted) {
            context.go('/home');
          }
        }
      },
      child: WillPopScope(
        onWillPop: _handleBackPress,
        child: BackButtonWrapper(
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Frequently Asked Questions'),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  final logger = ref.read(loggerProvider);
                  logger.log('FAQ back button pressed');
                  // Use the same navigation logic as the hardware back button
                  _handleBackPress();
                },
              ),
            ),
            body: Column(
              children: [
                // Search Bar
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search FAQs',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.neutral300),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                              },
                            )
                          : null,
                    ),
                  ),
                ),

                // FAQ sections
                Expanded(
                  child: filteredCategories.isEmpty
                      ? _buildNoResultsFound()
                      : ListView.builder(
                          itemCount: filteredCategories.length,
                          itemBuilder: (context, categoryIndex) {
                            final category = filteredCategories[categoryIndex];
                            if (category.faqs.isEmpty) return const SizedBox.shrink();
                            
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 16,
                                    right: 16,
                                    top: 16,
                                    bottom: 8,
                                  ),
                                  child: Text(
                                    category.title,
                                    style: AppTextStyles.h6.copyWith(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: category.faqs.length,
                                  itemBuilder: (context, faqIndex) {
                                    final faq = category.faqs[faqIndex];
                                    return _buildFAQItem(faq);
                                  },
                                ),
                              ],
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFAQItem(FAQ faq) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.pink.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        leading: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.green,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        title: Text(
          faq.question,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        iconColor: AppColors.primary,
        childrenPadding: const EdgeInsets.fromLTRB(48, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            faq.answer,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsFound() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: AppColors.neutral400,
          ),
          const SizedBox(height: 16),
          Text(
            'No FAQs found',
            style: AppTextStyles.h5,
          ),
          const SizedBox(height: 8),
          Text(
            'Try a different search term',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              _searchController.clear();
            },
            child: const Text('Clear Search'),
          ),
        ],
      ),
    );
  }
}

class FAQCategory {
  final String title;
  final List<FAQ> faqs;

  FAQCategory({
    required this.title,
    required this.faqs,
  });
}

class FAQ {
  final String question;
  final String answer;

  FAQ({
    required this.question,
    required this.answer,
  });
}