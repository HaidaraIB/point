import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Utils/app_log.dart';
import 'package:point/Models/ClientModel.dart';
import 'package:point/Models/ContentModel.dart';
import 'package:point/Localization/LanguageController.dart';
import 'package:point/Services/fcm_token_cache.dart';
import 'package:point/Services/FireStoreServices.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/push_permissions_helper.dart';

class ClientController extends GetxController {
  var clients = <ClientModel>[].obs;
  Rxn<ClientModel> currentClient = Rxn<ClientModel>();
  var notesController = TextEditingController();

  var isLoading = false.obs;
  bool obSecure = true;

  void changeObsecure() {
    obSecure = !obSecure;
    update();
  }
  final FirestoreServices _service = FirestoreServices();
  FirestoreServices get service => _service;
  Stream<List<ClientModel>> _safeClientsStream() async* {
    while (true) {
      try {
        await for (
          final items in _service.getClientsStreamForCurrentAuthEmail()
        ) {
          yield items;
        }
        return;
      } catch (e) {
        appDebugPrint('⚠️ fetchClients stream error: $e');
        yield const <ClientModel>[];
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    }
  }

  Future<bool> addClient(ClientModel client) async {
    final normalizedEmail = (client.email ?? '').trim().toLowerCase();
    final exists = clients.any(
      (c) => (c.email ?? '').trim().toLowerCase() == normalizedEmail,
    );
    if (exists) {
      FunHelper.showSnackbar(
        'error'.tr,
        'client.errors.email_exists'.trParams({'email': '${client.email}'}),
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );

      return false;
    }
    if (normalizedEmail.isNotEmpty) {
      final crossUsed = await _service.isEmailUsedAcrossUsers(normalizedEmail);
      if (crossUsed) {
        FunHelper.showSnackbar(
          'error'.tr,
          'client.errors.email_in_use_cross'.tr,
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return false;
      }
    }
    isLoading.value = true;
    final result = await _service.addClient(client);
    isLoading.value = false;
    return result;
  }

  Future<bool> updateClient(ClientModel client) async {
    final normalizedEmail = (client.email ?? '').trim().toLowerCase();
    if (normalizedEmail.isNotEmpty) {
      final crossUsed = await _service.isEmailUsedAcrossUsers(
        normalizedEmail,
        excludeClientId: client.id,
      );
      if (crossUsed) {
        FunHelper.showSnackbar(
          'error'.tr,
          'client.errors.email_in_use_cross'.tr,
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return false;
      }
    }
    isLoading.value = true;
    final result = await _service.updateClient(client);
    isLoading.value = false;
    return result;
  }

  Future<ClientModel?> loginclient(email, pass) async {
    isLoading.value = true;
    final result = await _service.loginClient(email, pass);
    isLoading.value = false;
    return result;
  }

  fetchClients() {
    if (FirebaseAuth.instance.currentUser == null) {
      clients.bindStream(Stream<List<ClientModel>>.value(const []));
      update();
      return;
    }
    clients.bindStream(_safeClientsStream());

    update();
  }

  final _clientCollection = FirebaseFirestore.instance.collection("clients");
  StreamSubscription<String>? _fcmTokenRefreshSub;
  StreamSubscription<User?>? _authStateSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _clientDocSub;
  /// Web cold start: [authStateChanges] can emit `null` once before persistence
  /// restores the user — clearing [currentClient] there wipes the UI after refresh.
  Timer? _authSignedOutDebounce;

  /// First snapshot can be from local cache and miss fields; a later event has
  /// full server data. Avoid overwriting a good [currentClient] with empty strings.
  ClientModel _mergeClientWithPrevious(ClientModel incoming, ClientModel? prev) {
    if (prev == null) return incoming;
    final sameId =
        (prev.id ?? '').trim().isNotEmpty &&
        (incoming.id ?? '').trim().isNotEmpty &&
        (prev.id ?? '').trim() == (incoming.id ?? '').trim();
    if (!sameId) return incoming;

    var m = incoming;
    if ((m.name ?? '').trim().isEmpty && (prev.name ?? '').trim().isNotEmpty) {
      m = m.copyWith(name: prev.name);
    }
    if ((m.email ?? '').trim().isEmpty && (prev.email ?? '').trim().isNotEmpty) {
      m = m.copyWith(email: prev.email);
    }
    if ((m.image ?? '').trim().isEmpty && (prev.image ?? '').trim().isNotEmpty) {
      m = m.copyWith(image: prev.image);
    }
    return m;
  }

  void listenToClient(String clientId) {
    _clientDocSub?.cancel();
    _clientDocSub = _clientCollection.doc(clientId).snapshots().listen(
      (snapshot) async {
        if (snapshot.exists) {
          final raw = ClientModel.fromJson(
            snapshot.data()!,
            snapshot.id,
          );
          final cl = _mergeClientWithPrevious(raw, currentClient.value);
          currentClient.value = cl;
          unawaited(FirestoreServices.syncAuthRoleForClient(cl));
          getFCMToken(currentClient.value);
          fetchContents();
        } else {
          currentClient.value = null;
        }
      },
      onError: (Object e, StackTrace st) {
        appDebugPrint('⚠️ listenToClient(doc): $e');
      },
    );
  }

  void getFCMToken(ClientModel? model) async {
    if (kIsWeb) return;
    try {
      final settings = await PushPermissionsHelper.ensurePushPermissionsFlow();
      if (!PushPermissionsHelper.isNotificationAllowed(settings)) {
        appDebugPrint('getFCMToken: notification permission not granted');
        return;
      }

      String? token = await FirebaseMessaging.instance.getToken();
      if (model != null && token != null && model.id != null) {
        final cid = model.id!;
        for (var attempt = 0; attempt < 3; attempt++) {
          try {
            await FirestoreServices.addClientFcmToken(
              clientId: cid,
              token: token,
            );
            await FcmTokenCache.rememberSuccess(
              token: token,
              role: 'client',
              userId: cid,
            );
            await LanguageController.syncPersistedLocaleToFirestore();
            break;
          } catch (e) {
            if (attempt == 2) {
              appDebugPrint('addClientFcmToken failed after retries: $e');
            } else {
              await Future<void>.delayed(
                Duration(milliseconds: 350 * (attempt + 1)),
              );
            }
          }
        }
      }

      _fcmTokenRefreshSub?.cancel();
      _fcmTokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((
        refreshedToken,
      ) async {
        final clientId = currentClient.value?.id ?? model?.id;
        if (clientId == null || clientId.trim().isEmpty) return;
        for (var attempt = 0; attempt < 3; attempt++) {
          try {
            await FirestoreServices.addClientFcmToken(
              clientId: clientId,
              token: refreshedToken,
            );
            await FcmTokenCache.rememberSuccess(
              token: refreshedToken,
              role: 'client',
              userId: clientId,
            );
            await LanguageController.syncPersistedLocaleToFirestore();
            appDebugPrint('FCM token refreshed for client $clientId');
            return;
          } catch (e) {
            if (attempt == 2) {
              appDebugPrint('FCM onTokenRefresh (client) failed: $e');
            } else {
              await Future<void>.delayed(
                Duration(milliseconds: 350 * (attempt + 1)),
              );
            }
          }
        }
      });
    } catch (e) {
      appDebugPrint('getFCMToken: $e');
    }
  }

  var contents = <ContentModel>[].obs;
  void fetchContents() async {
    contents.bindStream(_service.getContentsForClient(currentClient.value?.id));
    update();
  }

  void refreshAfterSilentPush() {
    fetchContents();
  }

  Future<bool> updateContent(ContentModel content) async {
    isLoading.value = true;
    final result = await _service.updateContent(content);
    isLoading.value = false;
    if (result && content.id != null) {
      final i = contents.indexWhere((c) => c.id == content.id);
      if (i >= 0) {
        contents[i] = content;
      }
    }
    update();
    return result;
  }

  @override
  void onInit() {
    fetchClients();
    _authStateSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      _authSignedOutDebounce?.cancel();
      if (user == null) {
        // Defer clear so a transient null during IndexedDB restore does not
        // wipe session after silent login / refresh.
        _authSignedOutDebounce = Timer(const Duration(milliseconds: 400), () {
          if (FirebaseAuth.instance.currentUser != null) return;
          _clientDocSub?.cancel();
          _clientDocSub = null;
          currentClient.value = null;
          clients.bindStream(Stream<List<ClientModel>>.value(const []));
          update();
        });
        return;
      }
      fetchClients();
    });
    // fetchContents();

    super.onInit();
  }

  @override
  void onClose() {
    _authSignedOutDebounce?.cancel();
    _authSignedOutDebounce = null;
    _clientDocSub?.cancel();
    _clientDocSub = null;
    _authStateSub?.cancel();
    _authStateSub = null;
    _fcmTokenRefreshSub?.cancel();
    _fcmTokenRefreshSub = null;
    super.onClose();
  }
}
