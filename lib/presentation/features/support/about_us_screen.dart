// lib/presentation/features/support/about_us_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:patelmart/core/widgets/back_button_wrapper.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/cached_network_image_widget.dart';

class AboutUsScreen extends ConsumerWidget {
  const AboutUsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
   return Scaffold(
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
            
            // Our Story section
            _buildSection(
              title: 'Our Story',
              icon: Icons.history,
              content: _buildStoryContent(),
            ),
            
            // Founders section
            _buildSection(
              title: 'Founders',
              icon: Icons.people,
              content: _buildFoundersContent(),
            ),
            
            // Vision & Mission section
            _buildSection(
              title: 'Vision & Mission',
              icon: Icons.visibility,
              content: _buildVisionMissionContent(),
            ),
            
            // Our Stores section
            _buildSection(
              title: 'Our Stores',
              icon: Icons.store,
              content: _buildStoresContent(),
            ),
            
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

  Widget _buildStoryContent() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'In the quaint town of Ambarnath, nestled 65 km from the bustling city of Mumbai, a story of resilience, ambition, and success unfolded. It all began in 1984 when Mr. Dhanji Patel, a man with dreams as vast as the fields of his village Dudhai in Kutch district of Gujarat, migrated to Ambarnath. He joined forces with his elder brother, Mr. Bechar Patel, who was already immersed in the grocery business.',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 16),
          Text(
            'The journey that started with a small grocery store beneath a grand banyan tree has evolved into a thriving saga of Patel Retail. With a dedicated team, a commitment to quality, and an ever-expanding vision, Patel Retail stands as a testament to the belief that dreams, when nurtured with perseverance, can grow into remarkable success stories.',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 16),
          Text(
            'Today, Patel\'s Rmart has grown to 32 stores across Maharashtra, serving over 50,000 customers daily with a commitment to quality, affordability, and exceptional service.',
            style: AppTextStyles.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildFoundersContent() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildFounderItem(
            name: 'Mr. Dhanji Patel',
            role: 'Co-Founder',
            bio: 'With a vision for retail excellence, Mr. Dhanji Patel transformed a small grocery store into a retail chain that serves thousands of families daily. His commitment to customer satisfaction and quality remains the cornerstone of Patel\'s Rmart.',
            imageUrl: 'assets/images/patelLogo.png',
          ),
          const SizedBox(height: 24),
          _buildFounderItem(
            name: 'Mr. Bechar Patel',
            role: 'Co-Founder',
            bio: 'An expert in retail operations, Mr. Bechar Patel\'s deep understanding of grocery business and supply chain management helped establish Patel\'s Rmart as a trusted name in the community. His legacy of fair pricing and ethical business practices continues to guide the company.',
            imageUrl: 'assets/images/patelLogo.png',
          ),
          const SizedBox(height: 24),
          _buildFounderItem(
            name: 'Mr. Rajesh Patel',
            role: 'Managing Director',
            bio: 'Leading the company into the digital age, Mr. Rajesh Patel has been instrumental in modernizing operations and expanding the Patel\'s Rmart footprint across Maharashtra. His innovative approach combines traditional values with modern retail strategies.',
            imageUrl: 'assets/images/patelLogo.png',
          ),
        ],
      ),
    );
  }

  Widget _buildFounderItem({
    required String name,
    required String role,
    required String bio,
    required String imageUrl,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(50),
          child: Container(
            width: 80,
            height: 80,
            color: AppColors.neutral200,
            child: Center(
              child: Icon(
                Icons.person,
                size: 40,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: AppTextStyles.h6.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                role,
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                bio,
                style: AppTextStyles.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVisionMissionContent() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Vision
          Text(
            'Our Vision',
            style: AppTextStyles.h6.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryLighter.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.primaryLighter,
                width: 1,
              ),
            ),
            child: Text(
              'To be the most trusted neighborhood retail chain that enhances the quality of life for families by providing quality products at affordable prices.',
              style: AppTextStyles.bodyMedium,
            ),
          ),
          const SizedBox(height: 24),
          
          // Mission
          Text(
            'Our Mission',
            style: AppTextStyles.h6.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.secondaryLight.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.secondaryLight,
                width: 1,
              ),
            ),
            child: Text(
              'To provide an exceptional shopping experience through:',
              style: AppTextStyles.bodyMedium,
            ),
          ),
          const SizedBox(height: 8),
          _buildMissionPoint(
            'Offering a wide range of quality products at competitive prices',
          ),
          _buildMissionPoint(
            'Providing excellent customer service that exceeds expectations',
          ),
          _buildMissionPoint(
            'Creating a pleasant shopping environment for our customers',
          ),
          _buildMissionPoint(
            'Fostering a positive work environment for our employees',
          ),
          _buildMissionPoint(
            'Contributing positively to the communities we serve',
          ),
        ],
      ),
    );
  }

  Widget _buildMissionPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle,
            color: AppColors.secondary,
            size: 18,
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

  Widget _buildStoresContent() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Patel\'s Rmart currently operates 32 stores across Maharashtra, with flagship locations in:',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 16),
          _buildStoreLocation(
            area: 'Ambarnath (Headquarters)',
            address: 'Plot No. 23, MIDC Area, Ambarnath East, Thane - 421501',
            phone: '+91 8188252372',
          ),
          const SizedBox(height: 12),
          _buildStoreLocation(
            area: 'Kalyan',
            address: 'Shop No. 3, Shivaji Chowk, Kalyan West, Thane - 421301',
            phone: '+91 8188252373',
          ),
          const SizedBox(height: 12),
          _buildStoreLocation(
            area: 'Ulhasnagar',
            address: 'Plot No. 52, Section 17, Ulhasnagar - 421004',
            phone: '+91 8188252374',
          ),
          const SizedBox(height: 12),
          _buildStoreLocation(
            area: 'Badlapur',
            address: 'Shop No. 7, Station Road, Badlapur East - 421503',
            phone: '+91 8188252375',
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton.icon(
              onPressed: () {
                // Navigate to store locator
              },
              icon: Icon(
                Icons.location_on,
                color: AppColors.primary,
              ),
              label: Text(
                'Find a store near you',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreLocation({
    required String area,
    required String address,
    required String phone,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.neutral300,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            area,
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.location_on,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  address,
                  style: AppTextStyles.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.phone,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                phone,
                style: AppTextStyles.bodySmall,
              ),
            ],
          ),
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