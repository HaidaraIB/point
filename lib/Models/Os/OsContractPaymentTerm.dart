class OsContractPaymentTerm {
  const OsContractPaymentTerm({
    required this.milestone,
    required this.percentage,
    required this.amount,
    required this.dueDateDescription,
    this.isPaid = false,
  });

  final String milestone;
  final double percentage;
  final double amount;
  final String dueDateDescription;
  final bool isPaid;

  factory OsContractPaymentTerm.fromJson(Map<String, dynamic> json) {
    return OsContractPaymentTerm(
      milestone: json['milestone'] as String? ?? '',
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      dueDateDescription: json['dueDateDescription'] as String? ?? '',
      isPaid: json['isPaid'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'milestone': milestone,
        'percentage': percentage,
        'amount': amount,
        'dueDateDescription': dueDateDescription,
        'isPaid': isPaid,
      };

  OsContractPaymentTerm copyWith({
    String? milestone,
    double? percentage,
    double? amount,
    String? dueDateDescription,
    bool? isPaid,
  }) {
    return OsContractPaymentTerm(
      milestone: milestone ?? this.milestone,
      percentage: percentage ?? this.percentage,
      amount: amount ?? this.amount,
      dueDateDescription: dueDateDescription ?? this.dueDateDescription,
      isPaid: isPaid ?? this.isPaid,
    );
  }

  static List<OsContractPaymentTerm> listFromJson(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => OsContractPaymentTerm.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static List<OsContractPaymentTerm> defaultClientSchedule(double totalValue) {
    return [
      OsContractPaymentTerm(
        milestone: 'الدفعة الأولى (مقدمة تعاقد)',
        percentage: 50,
        amount: (totalValue * 0.5).roundToDouble(),
        dueDateDescription: 'فور توقيع العقد',
        isPaid: true,
      ),
      OsContractPaymentTerm(
        milestone: 'الدفعة الثانية (مرحلية)',
        percentage: 30,
        amount: (totalValue * 0.3).roundToDouble(),
        dueDateDescription: 'منتصف مدة التنفيذ',
      ),
      OsContractPaymentTerm(
        milestone: 'الدفعة الثالثة (تسليم نهائي)',
        percentage: 20,
        amount: (totalValue * 0.2).roundToDouble(),
        dueDateDescription: 'عند التسليم النهائي المعتمد',
      ),
    ];
  }
}
