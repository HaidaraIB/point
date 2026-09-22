import 'package:flutter/material.dart';
import 'package:point/Utils/whatsapp_phone.dart';

/// Displays a phone number left-to-right regardless of app locale.
class PhoneNumberText extends StatelessWidget {
  const PhoneNumberText(
    this.phone, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign = TextAlign.start,
  });

  final String phone;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return Text(
      formatWhatsappPhoneDisplay(phone),
      style: style,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
      textDirection: TextDirection.ltr,
    );
  }
}
