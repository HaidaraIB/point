import 'dart:developer';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart'
    show Firebase, FirebaseException;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Bindings/AppBindings.dart';
import 'package:point/Localization/AppTranslations.dart';
import 'package:point/Routing/AppRouting.dart';
import 'package:point/Services/FcmServices.dart';
import 'package:point/Services/FireStoreServices.dart';
import 'package:point/Services/FirebaseStorageService.dart';
import 'package:point/Services/AutoLoginService.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/config/app_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  final supabaseUrl = AppConfig.supabaseUrl;
  final supabaseKey = StorageKeys.supabaseKey;
  if (supabaseUrl.isEmpty || supabaseKey.isEmpty) {
    throw StateError(
      'Supabase config missing. Pass --dart-define=SUPABASE_URL=... and --dart-define=SUPABASE_ANON_KEY=...',
    );
  }
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
  if (Firebase.apps.isEmpty) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } on FirebaseException catch (e) {
      if (!e.code.contains('duplicate-app')) rethrow;
    }
  }
  if (!kIsWeb) {
    await FirebaseMessaging.instance.requestPermission();
  }
  if (kDebugMode) {
    await FirestoreServices().ensureAccountholderTestUser();
    final storageOk = await FirebaseStorageService.checkConnection();
    log(
      storageOk
          ? '✅ Firebase Storage متصل'
          : '⚠️ تحقق من إعداد Firebase Storage (.env و Storage rules)',
    );
  }
  // await html.Notification.requestPermission();
  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    await NotificationService().init();
    //   // html.Notification(title, body: body);
  });

  runApp(App());
}

Future<void> onUserLogin(String userId) async {
  // FCM token is updated in HomeController/ClientController setupFCM.
}

/// Legacy auto-login entrypoint (kept for compatibility).
///
/// This no longer performs navigation directly to avoid double-routing flashes.
Future<String?> checkLogin() async {
  SharedPreferences pref = await SharedPreferences.getInstance();
  var islogin = await pref.get('isLoggedIn') ?? false;
  var email = await pref.get('email') ?? '';
  if (islogin == true && email != '') {
    return await attemptSilentLogin();
  }
  return null;
}

class App extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      key: navigatorKey,

      title: 'Point',
      debugShowCheckedModeBanner: false,
      initialBinding: AppBindings(),
      theme: ThemeData(
        fontFamily: 'IBM',
        scaffoldBackgroundColor: Colors.white,
        progressIndicatorTheme: ProgressIndicatorThemeData(color: Colors.white),
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: AppColors.primaryfontColor),
          bodyMedium: TextStyle(color: AppColors.primaryfontColor),
          bodySmall: TextStyle(color: AppColors.primaryfontColor),
        ),
        // primarySwatch: Colors.blue,
      ),
      initialRoute: AppRouting.initailPage,
      // home: MyHomePage(),
      locale: Locale('ar'),
      translations: AppTranslations(),
      popGesture: true,
      getPages: AppRouting.routing,
      // theme: ThemeData(primarySwatch: Colors.blue),
    );
  }
}
