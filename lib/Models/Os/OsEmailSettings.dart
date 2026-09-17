/// Agency email hub preferences (sender profile for Resend delivery).

class OsEmailSettings {
  const OsEmailSettings({
    this.senderName = '',
    this.senderEmail = '',
    this.replyToEmail = '',
    this.signatureText = '',
    this.enableAutoBcc = true,
    this.autoBccEmail = '',
    this.companyAddress = '',
    this.companyPhone = '',
    this.companyWebsite = '',
  });
  final String senderName;
  final String senderEmail;
  final String replyToEmail;
  final String signatureText;
  final bool enableAutoBcc;
  final String autoBccEmail;
  final String companyAddress;
  final String companyPhone;
  final String companyWebsite;

  factory OsEmailSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return OsEmailSettings.defaults();

    return OsEmailSettings(
      senderName: _str(json['senderName'], ''),
      senderEmail: _str(json['senderEmail'], ''),
      replyToEmail: _str(json['replyToEmail'], ''),
      signatureText: _str(json['signatureText'], ''),
      enableAutoBcc: json['enableAutoBcc'] as bool? ?? true,
      autoBccEmail: _str(json['autoBccEmail'], ''),
      companyAddress: _str(json['companyAddress'], ''),
      companyPhone: _str(json['companyPhone'], ''),
      companyWebsite: _str(json['companyWebsite'], ''),
    );
  }

  /// Missing keys use [fallback]; explicit empty strings are preserved.

  static String _str(dynamic v, String fallback) {
    if (v == null) return fallback;

    return (v as String?)?.trim() ?? '';
  }

  Map<String, dynamic> toJson() => {
    'senderName': senderName,
    'senderEmail': senderEmail,
    'replyToEmail': replyToEmail,
    'signatureText': signatureText,
    'enableAutoBcc': enableAutoBcc,
    'autoBccEmail': autoBccEmail,
    'companyAddress': companyAddress,
    'companyPhone': companyPhone,
    'companyWebsite': companyWebsite,
  };

  OsEmailSettings copyWith({
    String? senderName,
    String? senderEmail,
    String? replyToEmail,
    String? signatureText,
    bool? enableAutoBcc,
    String? autoBccEmail,
    String? companyAddress,
    String? companyPhone,
    String? companyWebsite,
  }) {
    return OsEmailSettings(
      senderName: senderName ?? this.senderName,
      senderEmail: senderEmail ?? this.senderEmail,
      replyToEmail: replyToEmail ?? this.replyToEmail,
      signatureText: signatureText ?? this.signatureText,
      enableAutoBcc: enableAutoBcc ?? this.enableAutoBcc,
      autoBccEmail: autoBccEmail ?? this.autoBccEmail,
      companyAddress: companyAddress ?? this.companyAddress,
      companyPhone: companyPhone ?? this.companyPhone,
      companyWebsite: companyWebsite ?? this.companyWebsite,
    );
  }

  static OsEmailSettings defaults() => const OsEmailSettings();
}
