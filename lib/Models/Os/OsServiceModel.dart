import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:point/Localization/AppLocaleKeys.dart';

/// Stable category codes for Point OS services (bilingual via .tr).
class OsServiceCategory {
  OsServiceCategory._();

  static const artisticProduction = 'artistic_production';
  static const visualProduction = 'visual_production';
  static const postProduction = 'post_production';
  static const digitalMarketing = 'digital_marketing';
  static const creativeDesign = 'creative_design';

  static const all = [
    artisticProduction,
    visualProduction,
    postProduction,
    digitalMarketing,
    creativeDesign,
  ];

  static String labelKey(String category) {
    switch (category) {
      case visualProduction:
        return AppLocaleKeys.osServicesCatVisual;
      case postProduction:
        return AppLocaleKeys.osServicesCatPost;
      case digitalMarketing:
        return AppLocaleKeys.osServicesCatDigital;
      case creativeDesign:
        return AppLocaleKeys.osServicesCatCreative;
      case artisticProduction:
      default:
        return AppLocaleKeys.osServicesCatArtistic;
    }
  }
}

class OsServicePriceType {
  OsServicePriceType._();

  static const fixed = 'FIXED';
  static const hourly = 'HOURLY';
  static const package = 'PACKAGE';

  static const all = [fixed, hourly, package];

  static String labelKey(String type) {
    switch (type) {
      case hourly:
        return AppLocaleKeys.osServicesPriceHourly;
      case package:
        return AppLocaleKeys.osServicesPricePackage;
      case fixed:
      default:
        return AppLocaleKeys.osServicesPriceFixed;
    }
  }
}

class OsServiceModel {
  final String? id;
  final String name;
  final String category;
  final double basePrice;
  final String priceType;
  final DateTime createdAt;

  const OsServiceModel({
    this.id,
    required this.name,
    required this.category,
    required this.basePrice,
    this.priceType = OsServicePriceType.fixed,
    required this.createdAt,
  });

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    return null;
  }

  factory OsServiceModel.fromJson(
    Map<String, dynamic> json,
    String docId,
  ) {
    return OsServiceModel(
      id: json['id'] as String? ?? docId,
      name: json['name'] as String? ?? '',
      category: json['category'] as String? ??
          OsServiceCategory.artisticProduction,
      basePrice: (json['basePrice'] as num?)?.toDouble() ?? 0,
      priceType: json['priceType'] as String? ?? OsServicePriceType.fixed,
      createdAt: _parseDateTime(json['createdAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'basePrice': basePrice,
        'priceType': priceType,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  OsServiceModel copyWith({
    String? id,
    String? name,
    String? category,
    double? basePrice,
    String? priceType,
    DateTime? createdAt,
  }) {
    return OsServiceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      basePrice: basePrice ?? this.basePrice,
      priceType: priceType ?? this.priceType,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
