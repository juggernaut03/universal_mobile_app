class PopupResponse {
  final String offerImageUrl;

  const PopupResponse({required this.offerImageUrl});

  factory PopupResponse.fromJson(Map<String, dynamic> json) {
    return PopupResponse(
      offerImageUrl: json['offerimgUrl'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'offerimgUrl': offerImageUrl,
    };
  }
}