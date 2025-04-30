// lib/presentation/features/support/help_support_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:patelmart/core/widgets/back_button_wrapper.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/launch_flow_provider.dart';

class HelpSupportScreen extends ConsumerStatefulWidget {
  const HelpSupportScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends ConsumerState<HelpSupportScreen> {
  final _issueController = TextEditingController();
  String? _selectedIssueType;
  final List<String> _issueTypes = [
    'Order Issue',
    'Payment Problem',
    'Delivery Delay',
    'Product Quality',
    'Return/Refund',
    'App Problem',
    'Other',
  ];

  @override
  void dispose() {
    _issueController.dispose();
    super.dispose();
  }

  @override
@override
Widget build(BuildContext context) {
  final logger = ref.read(loggerProvider);

  return Scaffold(
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
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header section with headphones icon
            Container(
              color: AppColors.primary,
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const CircleAvatar(
                    backgroundColor: Colors.white30,
                    radius: 36,
                    child: Icon(
                      Icons.headset_mic,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'How can we help you?',
                    style: AppTextStyles.h4.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'We\'re here to assist you with any issues',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            
            // Form section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Issue Type Dropdown
                  Text(
                    'Select Issue Type',
                    style: AppTextStyles.h6.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.neutral300),
                    ),
                    child: DropdownButtonFormField<String>(
                      value: _selectedIssueType,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(horizontal: 16),
                        border: InputBorder.none,
                        hintText: 'Select an issue',
                      ),
                      icon: const Icon(Icons.keyboard_arrow_down),
                      items: _issueTypes.map((String type) {
                        return DropdownMenuItem<String>(
                          value: type,
                          child: Text(type),
                        );
                      }).toList(),
                      onChanged: (String? value) {
                        setState(() {
                          _selectedIssueType = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Description Text Area
                  Text(
                    'Describe Your Issue',
                    style: AppTextStyles.h6.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 160,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.neutral300),
                    ),
                    child: TextField(
                      controller: _issueController,
                      maxLines: null,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(16),
                        hintText: 'Please provide details about your issue...',
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Photo Upload Section
                  Text(
                    'Add Photos (Optional)',
                    style: AppTextStyles.h6.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Add up to 3 photos to help us better understand your issue',
                    style: AppTextStyles.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildPhotoUploadButton(),
                        const SizedBox(width: 12),
                        _buildPhotoUploadButton(),
                        const SizedBox(width: 12),
                        _buildPhotoUploadButton(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Submit Button
                  ElevatedButton(
                    onPressed: () {
                      _submitIssue();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.send, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'SUBMIT ISSUE',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Urgent Assistance Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.support_agent,
                          color: Colors.blue.shade700,
                          size: 32,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Need urgent assistance?',
                                style: AppTextStyles.labelLarge.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Call us at +91 8188252372',
                                style: AppTextStyles.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.phone,
                            color: AppColors.primary,
                          ),
                          onPressed: () {
                            // Implement phone call functionality
                            logger.log('Initiating phone call to support');
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
   
  );
}

  Widget _buildPhotoUploadButton() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.neutral300,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          // Implement photo selection
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate,
              color: AppColors.primary,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              'Add Photo',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submitIssue() {
    if (_selectedIssueType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an issue type'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_issueController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please describe your issue'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Your issue has been submitted successfully. We\'ll get back to you soon.'),
        backgroundColor: Colors.green,
      ),
    );

    // Reset form
    setState(() {
      _selectedIssueType = null;
      _issueController.clear();
    });
  }
}