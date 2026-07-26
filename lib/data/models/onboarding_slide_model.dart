// lib/data/models/onboarding_slide_model.dart

/// One slide of the first-launch carousel.
///
/// [imageUrl] is a remote URL for admin-managed slides and an asset path for
/// the app's built-in fallback set; [isAsset] tells the widget which loader to
/// use so both kinds render through the same code path.
class OnboardingSlideModel {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final bool isAsset;

  const OnboardingSlideModel({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    this.isAsset = false,
  });

  factory OnboardingSlideModel.fromJson(Map<String, dynamic> json) {
    return OnboardingSlideModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      imageUrl: (json['image_url'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'image_url': imageUrl,
      };

  /// A slide with no image or no title would render as a blank page.
  bool get isDisplayable => title.trim().isNotEmpty && imageUrl.trim().isNotEmpty;

  /// Shown when the tenant has not configured any slides, so onboarding never
  /// comes up empty on a fresh install with no network.
  static const List<OnboardingSlideModel> bundledDefaults = [
    OnboardingSlideModel(
      id: 'bundled-1',
      title: 'Shop with Ease',
      description:
          'Browse and add your favorite products to the cart effortlessly. Your next purchase is just a few taps away!',
      imageUrl: 'assets/images/cart.webp',
      isAsset: true,
    ),
    OnboardingSlideModel(
      id: 'bundled-2',
      title: 'Fast & Reliable Delivery',
      description:
          'Get your orders delivered quickly and safely right to your doorstep.',
      imageUrl: 'assets/images/delivery.webp',
      isAsset: true,
    ),
    OnboardingSlideModel(
      id: 'bundled-3',
      title: 'Reorder with Just One Tap',
      description:
          'Loved your last purchase? Quickly reorder your favorite items anytime without the hassle of searching again.',
      imageUrl: 'assets/images/reorder.webp',
      isAsset: true,
    ),
  ];
}
