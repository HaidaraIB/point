import 'dart:async' show unawaited;

import 'package:firebase_core/firebase_core.dart'
    show Firebase, FirebaseException;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:point/Services/AudioService.dart';
import 'package:point/Services/chat_voice_playback_service.dart';
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
import 'package:point/Utils/app_log.dart';
import 'package:point/config/app_config.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:point/firebase_app_options.dart';
import 'package:point/fcm_background_handler.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // على الويب: تجنّب dumpErrorToConsole الافتراضي عندما تتضمّن سلسلة التشخيص
  // كائنات JS interop؛ وإلا يحدث TypeError (LegacyJavaScriptObject ليس DiagnosticsNode).
  if (kIsWeb) {
    FlutterError.onError = (FlutterErrorDetails details) {
      appDebugPrint(details.exceptionAsString());
      if (details.stack != null) {
        appDebugPrint(details.stack.toString());
      }
    };
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      // بعد تسجيل الخروج قد تُلغى الاشتراكات متأخرًا؛ Firestore يرمي permission-denied
      // بدون سطر في مشروعك — نعتبره معالجًا حتى لا يظهر RethrownDartError في الـ console.
      final msg = error.toString();
      if (msg.contains('cloud_firestore') &&
          msg.contains('permission-denied')) {
        return true;
      }
      appDebugPrint('Uncaught async error: $error');
      appDebugPrint(stack.toString());
      return true;
    };
  }

  final languageController = Get.put(LanguageController(), permanent: true);
  await languageController.initialize();
  Get.put(ChatVoicePlaybackService(), permanent: true);

  final supabaseUrl = AppConfig.supabaseUrl;
  final supabaseKey = StorageKeys.supabaseKey;
  if (supabaseUrl.isEmpty || supabaseKey.isEmpty) {
    throw StateError(
      'Supabase config missing. Pass --dart-define=SUPABASE_URL=... and --dart-define=SUPABASE_ANON_KEY=...',
    );
  }
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseKey,
    debug: kDebugMode,
  );
  if (Firebase.apps.isEmpty) {
    try {
      await Firebase.initializeApp(
        options: FirebaseAppOptions.currentPlatform,
      );
      appLog(
        'Firebase: projectId=${Firebase.app().options.projectId} '
        '(استخدم point (debug mode) أو USE_FIREBASE_TEST للاختبار؛ '
        'USE_FIREBASE_PROD للإنتاج)',
      );
    } on FirebaseException catch (e) {
      if (!e.code.contains('duplicate-app')) rethrow;
    }
  }
  // FCM + إشعارات محلية (Android/iOS فقط) — على الويب لا دفع ولا تهيئة.
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await NotificationService().init();
  }
  if (kDebugMode) {
    await FirestoreServices().ensureTestAdminUser();
    final storageOk = await FirebaseStorageService.checkConnection();
    appLog(
      storageOk
          ? '✅ Firebase Storage متصل'
          : '⚠️ تحقق من إعداد Firebase Storage (.env و Storage rules)',
    );
  }
  // لا نحمّل الصوت هنا على الويب: setSource قد يعلق/ينتظر حتى تفاعل المستخدم.
  if (!kIsWeb) {
    await AudioService.instance.initialize();
  }

  runApp(const App());
}

Future<void> onUserLogin(String userId) async {
  // على Android/iOS يُحدَّث توكن FCM من setupFCM/getFCMToken — على الويب معطّل.
}

/// Legacy auto-login entrypoint (kept for compatibility).
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

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(NotificationService().onAppResumed());
    }
  }

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
        enableLog: kDebugMode,
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
