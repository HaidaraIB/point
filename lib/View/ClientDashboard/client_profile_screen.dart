import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/ClientDashboard/client_profile_form.dart';

/// Full-screen client profile (name + photo) for mobile; mirrors employee profile screen.
class ClientProfileScreen extends StatelessWidget {
  const ClientProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom + 24;
    final theme = context.appTheme;

    return Scaffold(
      backgroundColor: theme.pageBackground,
      appBar: AppBar(
        backgroundColor: theme.navSurface,
        foregroundColor: theme.onNavSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'client.profile.title'.tr,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: theme.onNavSurface,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: theme.onNavSurface,
          onPressed: () => Get.back(),
        ),
      ),
      body: ClientProfileForm(
        closeOnSuccess: false,
        padding: EdgeInsets.fromLTRB(16, 16, 16, bottom),
      ),
    );
  }
}
