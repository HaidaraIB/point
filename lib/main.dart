import 'dart:developer';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart' show Firebase, FirebaseException, FirebaseOptions;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:point/Bindings/AppBindings.dart';
import 'package:point/Controller/ClientController.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Localization/AppTranslations.dart';
import 'package:point/Routing/AppRouting.dart';
import 'package:point/Services/FcmServices.dart';
import 'package:point/Services/FireStoreServices.dart';
import 'package:point/Services/FirebaseStorageService.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

FirebaseOptions _firebaseOptionsFromEnv() {
  if (kIsWeb) {
    return FirebaseOptions(
      apiKey: dotenv.env['FIREBASE_WEB_API_KEY'] ?? '',
      appId: dotenv.env['FIREBASE_WEB_APP_ID'] ?? '',
      messagingSenderId: dotenv.env['FIREBASE_WEB_MESSAGING_SENDER_ID'] ?? '',
      projectId: dotenv.env['FIREBASE_WEB_PROJECT_ID'] ?? '',
      authDomain: dotenv.env['FIREBASE_WEB_AUTH_DOMAIN'],
      storageBucket: dotenv.env['FIREBASE_WEB_STORAGE_BUCKET'],
      measurementId: dotenv.env['FIREBASE_WEB_MEASUREMENT_ID'],
    );
  }
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return FirebaseOptions(
        apiKey: dotenv.env['FIREBASE_ANDROID_API_KEY'] ?? '',
        appId: dotenv.env['FIREBASE_ANDROID_APP_ID'] ?? '',
        messagingSenderId: dotenv.env['FIREBASE_ANDROID_MESSAGING_SENDER_ID'] ?? '',
        projectId: dotenv.env['FIREBASE_ANDROID_PROJECT_ID'] ?? '',
        storageBucket: dotenv.env['FIREBASE_ANDROID_STORAGE_BUCKET'],
      );
    case TargetPlatform.iOS:
      return FirebaseOptions(
        apiKey: dotenv.env['FIREBASE_IOS_API_KEY'] ?? '',
        appId: dotenv.env['FIREBASE_IOS_APP_ID'] ?? '',
        messagingSenderId: dotenv.env['FIREBASE_IOS_MESSAGING_SENDER_ID'] ?? '',
        projectId: dotenv.env['FIREBASE_IOS_PROJECT_ID'] ?? '',
        storageBucket: dotenv.env['FIREBASE_IOS_STORAGE_BUCKET'],
        iosBundleId: dotenv.env['FIREBASE_IOS_BUNDLE_ID'],
      );
    default:
      throw UnsupportedError(
        'Firebase options from .env are only configured for web, Android, and iOS.',
      );
  }
}

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
  final supabaseKey = StorageKeys.supabaseKey;
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
  if (Firebase.apps.isEmpty) {
    try {
      await Firebase.initializeApp(options: _firebaseOptionsFromEnv());
    } on FirebaseException catch (e) {
      if (!e.code.contains('duplicate-app')) rethrow;
    }
  }
  await FirebaseMessaging.instance.requestPermission();
  if (kDebugMode) {
    await FirestoreServices().ensureAccountholderTestUser();
    final storageOk = await FirebaseStorageService.checkConnection();
    log(storageOk ? '✅ Firebase Storage متصل' : '⚠️ تحقق من إعداد Firebase Storage (.env و Storage rules)');
  }
  Get.put(HomeController());
  // await html.Notification.requestPermission();
  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    await NotificationService().init();
    //   // html.Notification(title, body: body);
  });
  await checkLogin();

  runApp(App());
}

Future<void> onUserLogin(String userId) async {
  // FCM token is updated in HomeController/ClientController setupFCM.
}

checkLogin() async {
  SharedPreferences pref = await SharedPreferences.getInstance();
  var islogin = await pref.get('isLoggedIn') ?? false;
  var email = await pref.get('email') ?? '';
  var password = await pref.get('password') ?? '';
  if (islogin == true && email != '' && password != '') {
    final FirebaseMessaging _fcm = FirebaseMessaging.instance;

    Get.find<HomeController>()
        .loginClient(email.toString(), password.toString())
        .then((v) async {
          if (v != null) {
            await onUserLogin(v.id.toString());

            log("✅ تم تسجيل دخول الموظف: ${v.email}");
            log(v.status.toString());
            if (v.status == 'active') {
              if (!kIsWeb) {
                try {
                  await _fcm.subscribeToTopic('all');
                  if (v.role == 'supervisor') {
                    await _fcm.unsubscribeFromTopic('clients');
                    await _fcm.subscribeToTopic('employees');
                  } else if (v.role == 'employee') {
                    await _fcm.unsubscribeFromTopic('clients');
                    await _fcm.subscribeToTopic('employees');
                  }
                } catch (e) {
                  log('FCM subscribe (employee): $e');
                }
              }
              Get.find<HomeController>().fetchnotification(v.id);

              Get.find<HomeController>().listenToClient(v.id!);
              if (v.role == 'supervisor') {
                WidgetsBinding.instance.addPostFrameCallback((_) => Get.toNamed('/'));
              } else if (v.role == 'admin') {
                WidgetsBinding.instance.addPostFrameCallback((_) => Get.toNamed('/'));
              } else if (v.role == 'employee') {
                WidgetsBinding.instance.addPostFrameCallback((_) => Get.toNamed('/employeeDashboard'));
              } else if (v.role == 'accountholder') {
                WidgetsBinding.instance.addPostFrameCallback((_) => Get.toNamed('/'));
              } else {}
              try {
                await Get.find<HomeController>().setupFCM(v.id);
              } catch (e) {
                log('FCM setup: $e');
              }
            }
          } else {
            await Get.find<ClientController>()
                .loginclient(
                  email.toString().trim().toLowerCase(),
                  password.toString().trim(),
                )
                .then((v) async {
                  if (v != null) {
                    await onUserLogin(v.id.toString());

                    log("✅ تم تسجيل دخول العميل: ${v.email}");
                    log(v.status.toString());
                    if (v.status == 'active') {
                      Get.find<ClientController>().listenToClient(v.id!);
                      WidgetsBinding.instance.addPostFrameCallback((_) => Get.offAllNamed('/ClientHome'));
                      if (!kIsWeb) {
                        try {
                          await _fcm.unsubscribeFromTopic('employees');
                          await _fcm.subscribeToTopic('clients');
                          await _fcm.subscribeToTopic('all');
                        } catch (e) {
                          log('FCM subscribe (client): $e');
                        }
                      }
                    } else {
                      FunHelper.showsnackbar(
                        'error'.tr,
                        'account_not_active_contact_support'.tr,
                        snackPosition: SnackPosition.TOP,
                        backgroundColor: Colors.red,
                        colorText: Colors.white,
                      );
                    }
                  }
                });
          }
        });
  }
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
