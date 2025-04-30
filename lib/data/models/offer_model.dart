// lib/data/models/offer_model.dart

class OfferModel {
  final String imageUrl;

  OfferModel({
    required this.imageUrl,
  });

  factory OfferModel.fromJson(Map<String, dynamic> json) {
    return OfferModel(
      imageUrl: json['offerimgUrl'] ?? '',
    );
  }
} 