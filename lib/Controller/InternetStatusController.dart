import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

class InternetStatusController extends GetxController {
  final RxBool isOnline = true.obs;
  final RxBool isChecking = false.obs;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _periodicRecheckTimer;
  bool _initialized = false;

  @override
  void onInit() {
    super.onInit();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((_) {
      unawaited(refreshStatus());
    });
    _periodicRecheckTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      unawaited(refreshStatus());
    });
    unawaited(refreshStatus());
  }

  Future<void> refreshStatus() async {
    if (isChecking.value) return;
    isChecking.value = true;
    try {
      final connectivityResults = await Connectivity().checkConnectivity();
      final hasAnyNetwork = connectivityResults.any(
        (result) => result != ConnectivityResult.none,
      );
      final hasInternet = hasAnyNetwork
          ? await InternetConnection().hasInternetAccess
          : false;
      isOnline.value = hasInternet;
      _initialized = true;
    } catch (_) {
      if (_initialized) {
        isOnline.value = false;
      }
    } finally {
      isChecking.value = false;
    }
  }

  Future<void> retryNow() async {
    await refreshStatus();
  }

  @override
  void onClose() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
    _periodicRecheckTimer?.cancel();
    _periodicRecheckTimer = null;
    super.onClose();
  }
}
