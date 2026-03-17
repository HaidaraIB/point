import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';

import 'package:point/View/Auth/ChooseUserType.dart';
import 'package:point/View/Auth/CreateUserAccount.dart';
import 'package:point/View/Auth/EnterCode.dart';
import 'package:point/View/Auth/ForgetPassword.dart';
import 'package:point/View/Auth/Login.dart';
import 'package:point/View/Auth/ResetPassword.dart';
import 'package:point/View/Clients/ClientsTable.dart';
import 'package:point/View/Contents/ContentsTable.dart';
import 'package:point/View/EmployeeDashboard/EmployeeDashBord.dart';
import 'package:point/View/Employees/EmployeesTable.dart';
import 'package:point/View/History/History.dart';
import 'package:point/View/History/TaskHistory.dart';
import 'package:point/View/Home/Home.dart';
import 'package:point/View/Mobile/ClientHome.dart';
import 'package:point/View/Mobile/CreateUserAccount.dart';
import 'package:point/View/Mobile/LoginUserAccount.dart';
import 'package:point/View/Statistics/Statistics.dart';
import 'package:point/View/Tasks/Tasks.dart';

class AuthMiddleware extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    final user = Get.find<HomeController>().currentemployee.value;
    if (user == null) {
      return const RouteSettings(name: '/auth/login');
    }
    return null;
  }
}

class AppRouting {
  static var initailPage = kIsWeb ? '/auth/login' : '/auth/ChooseUserType';

  static final routing = [
    GetPage(
      name: '/ClientHome',
      page: () {
        return ClientHome();
      },
    ),

    GetPage(
      name: '/auth',
      // middlewares: [AuthMiddleware()],
      page: () {
        return LoginView();
      },
      children: [
        GetPage(
          name: '/ChooseUserType',
          page: () => ChooseUserType(),
        ),
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
          name: '/forgetpassword',
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

      // middlewares: [AuthMiddleware()],
      page: () {
        return Home();
      },

      children: [
        GetPage(
          name: '/employees',
          page: () {
            return EmployeeTable();
          },
          // middlewares: [AuthMiddleware()],
        ),
        GetPage(
          name: '/clients',
          page: () {
            return ClientsTable();
          },
          // middlewares: [AuthMiddleware()],
        ),
        GetPage(
          name: '/content',
          page: () {
            return ContentsTable();
          },
          // middlewares: [AuthMiddleware()],
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
          // middlewares: [AuthMiddleware()],
        ),
        // GetPage(
        //   name: '/conversation',
        //   page: () {
        //     return ChatScreen();
        //   },
        //   // middlewares: [AuthMiddleware()],
        // ),
      ],
    ),
    GetPage(
      name: '/employeeDashboard',
      page: () {
        return EmployeeDashBord();
      },
      // middlewares: [AuthMiddleware()],
    ),
  ];
}
