import 'package:get/get_utils/src/extensions/internacionalization.dart';

String? validatePasswordStrong(String? value) {
  if (value == null || value.isEmpty) return 'password_required'.tr;
  if (value.length < 8) return 'password_min_8'.tr;

  final pattern =
      r"""^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[!@#\$&*~%^()_\-+=\[\]{}|:;"'<>,.?/]).{8,}$""";
  final regExp = RegExp(pattern);

  if (!regExp.hasMatch(value)) return 'password_requirements'.tr;
  return null;
}
