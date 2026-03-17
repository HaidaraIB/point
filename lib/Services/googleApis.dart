import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:googleapis_auth/auth_io.dart';

class googleApis {
  static const String _firebaseMessageScope =
      'https://www.googleapis.com/auth/firebase.messaging';

  Future<String> getAcssesToken() async {
    final jsonStr = dotenv.env['FIREBASE_SERVICE_ACCOUNT_JSON'];
    if (jsonStr == null || jsonStr.isEmpty) {
      throw StateError(
        'FIREBASE_SERVICE_ACCOUNT_JSON غير معرّف في .env. '
        'أضف محتوى ملف service account كسطر واحد (مع \\n داخل private_key).',
      );
    }
    final Map<String, dynamic> credentialsJson =
        jsonDecode(jsonStr) as Map<String, dynamic>;
    final client = await clientViaServiceAccount(
      ServiceAccountCredentials.fromJson(credentialsJson),
      [_firebaseMessageScope],
    );
    return client.credentials.accessToken.data;
  }
}
