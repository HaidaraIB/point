import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:point/Services/app_version.dart';
import 'package:point/config/app_config.dart';

/// Arguments for [`ForceUpdatePage`] (store link + which splash to reopen after update).
class ForceUpdateArgs {
  const ForceUpdateArgs({
    this.storeUrl,
    this.returnSplashRoute = '/mobileSplash',
  });

  final String? storeUrl;
  final String returnSplashRoute;
}

/// Result of comparing the installed mobile build to Firestore `appVersionGate/mobile`.
class MobileVersionGateSnapshot {
  const MobileVersionGateSnapshot({
    required this.blocked,
    this.storeUrl,
    this.remoteLoaded = false,
  });

  final bool blocked;
  final String? storeUrl;
  final bool remoteLoaded;
}

/// Remote minimum build gate for Android/iOS (skipped on web/desktop).
class MobileVersionGate {
  MobileVersionGate._();

  static const String firestoreDocPath = 'appVersionGate/mobile';
  static const Duration _fetchTimeout = Duration(seconds: 8);

  static Future<MobileVersionGateSnapshot> evaluate() async {
    if (kIsWeb) {
      return const MobileVersionGateSnapshot(blocked: false);
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        break;
      default:
        return const MobileVersionGateSnapshot(blocked: false);
    }

    final info = await loadAppVersionInfo();
    final current = int.tryParse(info.buildNumber.trim());
    if (current == null) {
      return const MobileVersionGateSnapshot(blocked: false);
    }

    try {
      final snap = await FirebaseFirestore.instance
          .doc(firestoreDocPath)
          .get()
          .timeout(_fetchTimeout);

      if (!snap.exists) {
        return const MobileVersionGateSnapshot(
          blocked: false,
          remoteLoaded: true,
        );
      }

      final data = snap.data();
      if (data == null) {
        return const MobileVersionGateSnapshot(
          blocked: false,
          remoteLoaded: true,
        );
      }

      final isAndroid = defaultTargetPlatform == TargetPlatform.android;
      final int? minBuild = isAndroid
          ? _asInt(data['androidMinBuild'])
          : _asInt(data['iosMinBuild']);
      if (minBuild == null) {
        return const MobileVersionGateSnapshot(
          blocked: false,
          remoteLoaded: true,
        );
      }

      final remoteStore = _nonEmptyString(
        isAndroid ? data['androidStoreUrl'] : data['iosStoreUrl'],
      );
      final fallback = _nonEmptyString(
        isAndroid
            ? AppConfig.androidStoreUrlFallback
            : AppConfig.iosStoreUrlFallback,
      );
      final storeUrl = remoteStore ?? fallback;

      if (current < minBuild) {
        return MobileVersionGateSnapshot(
          blocked: true,
          storeUrl: storeUrl,
          remoteLoaded: true,
        );
      }

      return const MobileVersionGateSnapshot(
        blocked: false,
        remoteLoaded: true,
      );
    } catch (_) {
      return const MobileVersionGateSnapshot(
        blocked: false,
        remoteLoaded: false,
      );
    }
  }

  static int? _asInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  static String? _nonEmptyString(Object? value) {
    if (value == null) return null;
    final s = value.toString().trim();
    if (s.isEmpty) return null;
    return s;
  }
}
