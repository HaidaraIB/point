import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:point/Controller/ClientController.dart';
import 'package:point/Controller/HomeController.dart';

import 'package:point/View/Auth/ChooseUserType.dart';
import 'package:point/View/Auth/ClientSessionSetupScreen.dart';
import 'package:point/View/Auth/CreateUserAccount.dart';
import 'package:point/View/Auth/EnterCode.dart';
import 'package:point/View/Auth/ForgetPassword.dart';
import 'package:point/View/Auth/Login.dart';
import 'package:point/View/Auth/ResetPassword.dart';
import 'package:point/View/Auth/SessionSetupScreen.dart';
import 'package:point/View/Auth/WebClientAuthSplashDecider.dart';
import 'package:point/View/Auth/WebAuthSplashDecider.dart';
import 'package:point/View/Clients/ClientsTable.dart';
import 'package:point/View/ClientDashboard/client_profile_screen.dart';
import 'package:point/View/Contents/ContentsTable.dart';
import 'package:point/View/Library/LibraryPage.dart';
import 'package:point/View/EmployeeDashboard/EmployeeDashboard.dart';
import 'package:point/View/EmployeeDashboard/employee_profile_screen.dart';
import 'package:point/View/Employees/EmployeesTable.dart';
import 'package:point/View/History/History.dart';
import 'package:point/View/History/TaskHistory.dart';
import 'package:point/View/Home/Home.dart';
import 'package:point/View/Mobile/ClientHome.dart';
import 'package:point/View/Mobile/CreateUserAccount.dart';
import 'package:point/View/Mobile/MobileClientSplashDecider.dart';
import 'package:point/View/Mobile/LoginUserAccount.dart';
import 'package:point/View/Mobile/MobileSplashDecider.dart';
import 'package:point/View/Mobile/force_update_page.dart';
import 'package:point/View/Statistics/Statistics.dart';
import 'package:point/View/Tasks/Tasks.dart';

class AuthMiddleware extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    final user = Get.find<HomeController>().currentEmployee.value;
    if (user == null) {
      final authUser = FirebaseAuth.instance.currentUser;
      if (authUser != null) {
        final currentRoute = route ?? Get.currentRoute;
        final encodedNext = Uri.encodeComponent(currentRoute);
        final splash = kIsWeb ? '/webAuthSplash' : '/mobileSplash';
        return RouteSettings(name: '$splash?next=$encodedNext');
      }
      return const RouteSettings(name: '/auth/login');
    }
    return null;
  }
}

class ClientAuthMiddleware extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    final client = Get.find<ClientController>().currentClient.value;
    if (client != null) return null;

    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser != null) {
      final currentRoute = route ?? Get.currentRoute;
      final encodedNext = Uri.encodeComponent(currentRoute);
      final splash = kIsWeb ? '/webClientAuthSplash' : '/mobileClientSplash';
      return RouteSettings(name: '$splash?next=$encodedNext');
    }
    return const RouteSettings(name: '/auth/LoginUserAccount');
  }
}

class AppRouting {
  static var initialPage = kIsWeb ? '/webAuthSplash' : '/mobileSplash';

  static final routing = [
    GetPage(name: '/webAuthSplash', page: () => const WebAuthSplashDecider()),
    GetPage(
      name: '/webClientAuthSplash',
      page: () => const WebClientAuthSplashDecider(),
    ),
    GetPage(name: '/mobileSplash', page: () => const MobileSplashDecider()),
    GetPage(
      name: '/mobileClientSplash',
      page: () => const MobileClientSplashDecider(),
    ),
    GetPage(
      name: '/forceUpdate',
      page: () => const ForceUpdatePage(),
    ),
    GetPage(
      name: '/ClientHome',
      middlewares: [ClientAuthMiddleware()],
      page: () {
        return ClientHome();
      },
    ),
    GetPage(name: '/sessionSetup', page: () => const SessionSetupScreen()),
    GetPage(
      name: '/clientSessionSetup',
      page: () => const ClientSessionSetupScreen(),
    ),

    GetPage(
      name: '/auth',
      page: () {
        return LoginView();
      },
      children: [
        GetPage(name: '/ChooseUserType', page: () => ChooseUserType()),
        GetPage(
          name: '/CreateUserAccountMobileVersion',
          page: () {
            return CreateUserAccountMobileVersion();
          },
          // middlewares: [AuthMiddleware()],
        ),
        GetPage(
          name: '/LoginUserAccount',
          page: () {
            return LoginUserAccount();
          },
          // middlewares: [AuthMiddleware()],
        ),
        GetPage(
          name: '/login',
          page: () {
            return LoginView();
          },
          // middlewares: [AuthMiddleware()],
        ),
        GetPage(
          name: '/signUp',
          page: () {
            return CreateUserAccount();
          },
          // middlewares: [AuthMiddleware()],
        ),
        GetPage(
          name: '/forgetPassword',
          page: () {
            return ForgetPassword();
          },
        ),
        GetPage(
          name: '/enterCode',
          page: () {
            return EnterCode();
          },
          // middlewares: [AuthMiddleware()],
        ),
        GetPage(
          name: '/resetPassword',
          page: () {
            return ResetPassword();
          },
          // middlewares: [AuthMiddleware()],
        ),
      ],
    ),
    GetPage(
      name: '/',
      middlewares: [AuthMiddleware()],
      page: () {
        return Home();
      },

      children: [
        GetPage(
          name: '/employees',
          page: () {
            return EmployeeTable();
          },
          middlewares: [AuthMiddleware()],
        ),
        GetPage(
          name: '/clients',
          page: () {
            return ClientsTable();
          },
          middlewares: [AuthMiddleware()],
        ),
        GetPage(
          name: '/content',
          page: () {
            return ContentsTable();
          },
          middlewares: [AuthMiddleware()],
        ),
        GetPage(
          name: '/library',
          page: () => const LibraryPage(),
          middlewares: [AuthMiddleware()],
        ),
        GetPage(
          name: '/statistics',
          page: () {
            return Statistics();
          },
          // middlewares: [AuthMiddleware()],
        ),
        GetPage(
          name: '/History',
          page: () {
            return History();
          },
          // middlewares: [AuthMiddleware()],
        ),
        GetPage(
          name: '/TasksHistory',
          page: () {
            return TasksHistory();
          },
          // middlewares: [AuthMiddleware()],
        ),
        GetPage(
          name: '/tasks',
          page: () {
            return Tasks();
          },
          middlewares: [AuthMiddleware()],
        ),
      ],
    ),
    GetPage(
      name: '/employeeDashboard',
      page: () {
        return EmployeeDashboard();
      },
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: '/employeeProfile',
      page: () => const EmployeeProfileScreen(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: '/clientProfile',
      page: () => const ClientProfileScreen(),
      middlewares: [ClientAuthMiddleware()],
    ),
    GetPage(
      name: '/employeeContent',
      page: () {
        // نفس منطق `/content`: لا نستخدم EmployeeContentDashboard هنا وإلا يُتجاوز
        // فرع موظفي النشر/الترويج على الويب (جدول الأدمن + الشريط الجانبي).
        return ContentsTable();
      },
      middlewares: [AuthMiddleware()],
    ),
  ];
}
