import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/InternetStatusController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Services/FunHelper.dart';

class InternetOfflineGuard extends StatefulWidget {
  const InternetOfflineGuard({super.key, required this.child});

  final Widget child;

  @override
  State<InternetOfflineGuard> createState() => _InternetOfflineGuardState();
}

class _InternetOfflineGuardState extends State<InternetOfflineGuard> {
  late final InternetStatusController _internetController;
  Worker? _worker;
  bool? _previousOnline;

  @override
  void initState() {
    super.initState();
    _internetController = Get.find<InternetStatusController>();
    _previousOnline = _internetController.isOnline.value;
    _worker = ever<bool>(_internetController.isOnline, (online) {
      final previous = _previousOnline;
      _previousOnline = online;
      if (previous == null || previous == online) return;
      if (online) {
        FunHelper.showSnackbarDeduped(
          AppLocaleKeys.successTitle.tr,
          AppLocaleKeys.internetBackOnlineSnackbar.tr,
          dedupeKey: 'internet_back_online',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else {
        FunHelper.showSnackbarDeduped(
          AppLocaleKeys.errorTitle.tr,
          AppLocaleKeys.internetOfflineSnackbar.tr,
          dedupeKey: 'internet_went_offline',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    });
  }

  @override
  void dispose() {
    _worker?.dispose();
    _worker = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
