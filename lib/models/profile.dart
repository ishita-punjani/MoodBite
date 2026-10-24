import 'json.dart';

class Profile {
  const Profile({
    required this.id,
    this.fullName,
    this.phone,
    this.isVeg,
    this.likedCuisines = const [],
    this.defaultMaxPrice,
  });

  static const columns =
      'id, full_name, phone, is_veg, liked_cuisines, default_max_price';

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String,
        fullName: json['full_name'] as String?,
        phone: json['phone'] as String?,
        isVeg: json['is_veg'] as bool?,
        likedCuisines: readStringList(json['liked_cuisines']),
        defaultMaxPrice: readIntOrNull(json['default_max_price']),
      );

  final String id;
  final String? fullName;
  final String? phone;

  /// `null` means the user has not said.
  final bool? isVeg;
  final List<String> likedCuisines;
  final int? defaultMaxPrice;

  /// Name and phone are required before using the app.
  bool get isComplete =>
      (fullName?.trim().isNotEmpty ?? false) &&
      (phone?.trim().isNotEmpty ?? false);
}
