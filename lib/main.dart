import 'dart:developer';
import 'package:firebase_core/firebase_core.dart'
    show Firebase, FirebaseException;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:point/Services/AudioService.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:point/Bindings/AppBindings.dart';
import 'package:point/Localization/LanguageController.dart';
import 'package:point/Localization/AppTranslations.dart';
import 'package:point/Routing/AppRouting.dart';
import 'package:point/Services/FcmServices.dart';
import 'package:point/Services/FireStoreServices.dart';
import 'package:point/Services/FirebaseStorageService.dart';
import 'package:point/Services/AutoLoginService.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/config/app_config.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // على الويب: تجنّب dumpErrorToConsole الافتراضي عندما تتضمّن سلسلة التشخيص
  // كائنات JS interop؛ وإلا يحدث TypeError (LegacyJavaScriptObject ليس DiagnosticsNode).
  if (kIsWeb) {
    FlutterError.onError = (FlutterErrorDetails details) {
      debugPrint(details.exceptionAsString());
      if (kDebugMode && details.stack != null) {
        debugPrint(details.stack.toString());
      }
    };
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      debugPrint('Uncaught async error: $error');
      if (kDebugMode) {
        debugPrint(stack.toString());
      }
      return true;
    };
  }

  final languageController = Get.put(LanguageController(), permanent: true);
  await languageController.initialize();

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
    // تهيئة إشعارات الـPush + الـLocal مرة واحدة قبل runApp.
    await NotificationService().init();
  }
  if (kDebugMode) {
    await FirestoreServices().ensureTestAdminUser();
    final storageOk = await FirebaseStorageService.checkConnection();
    log(
      storageOk
          ? '✅ Firebase Storage متصل'
          : '⚠️ تحقق من إعداد Firebase Storage (.env و Storage rules)',
    );
  }
  // لا نحمّل الصوت هنا على الويب: setSource قد يعلق/ينتظر حتى تفاعل المستخدم.
  if (!kIsWeb) {
    await AudioService.instance.initialize();
  }

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
    final lc = Get.find<LanguageController>();
    final almaraiTextTheme =
        GoogleFonts.almaraiTextTheme(ThemeData.light().textTheme);
    return Obx(
      () => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) {
          AudioService.instance.unlockAudio();
        },
        child: GetMaterialApp(
        key: navigatorKey,

        title: 'Point Agency',
        debugShowCheckedModeBanner: false,
        initialBinding: AppBindings(),
        builder: (context, child) {
          final code = lc.currentLocale.value.languageCode;
          final dir =
              code == 'ar' ? TextDirection.rtl : TextDirection.ltr;
          return Directionality(
            textDirection: dir,
            child: child ?? const SizedBox.shrink(),
          );
        },
        theme: ThemeData(
          scaffoldBackgroundColor: Colors.white,
          progressIndicatorTheme: ProgressIndicatorThemeData(color: Colors.white),
          textTheme: almaraiTextTheme.copyWith(
            bodyLarge: almaraiTextTheme.bodyLarge
                ?.copyWith(color: AppColors.primaryfontColor),
            bodyMedium: almaraiTextTheme.bodyMedium
                ?.copyWith(color: AppColors.primaryfontColor),
            bodySmall: almaraiTextTheme.bodySmall
                ?.copyWith(color: AppColors.primaryfontColor),
          ),
        ),
        initialRoute: AppRouting.initialPage,
        locale: lc.currentLocale.value,
        fallbackLocale: const Locale('ar'),
        translations: AppTranslations(),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        popGesture: true,
        getPages: AppRouting.routing,
        // theme: ThemeData(primarySwatch: Colors.blue),
        ),
      ),
    );
  }
}
