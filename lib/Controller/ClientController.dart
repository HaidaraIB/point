import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Models/ClientModel.dart';
import 'package:point/Models/ContentModel.dart';
import 'package:point/Services/FireStoreServices.dart';
import 'package:point/Services/FunHelper.dart';

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
    clients.bindStream(_service.getClientsStream());

    update();
  }

  final _clientCollection = FirebaseFirestore.instance.collection("clients");
  StreamSubscription<String>? _fcmTokenRefreshSub;

  void listenToClient(String clientId) {
    _clientCollection.doc(clientId).snapshots().listen((snapshot) async {
      if (snapshot.exists) {
        currentClient.value = ClientModel.fromJson(
          snapshot.data()!,
          snapshot.id,
        );
        getFCMToken(currentClient.value);
        fetchContents();
      } else {
        currentClient.value = null;
      }
    });
  }

  void getFCMToken(ClientModel? model) async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      if (model != null && token != null) {
        await FirestoreServices.addClientFcmToken(clientId: model.id!, token: token);
      }

      _fcmTokenRefreshSub?.cancel();
      _fcmTokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((
        refreshedToken,
      ) async {
        final clientId = currentClient.value?.id ?? model?.id;
        if (clientId == null || clientId.trim().isEmpty) return;
        await FirestoreServices.addClientFcmToken(
          clientId: clientId,
          token: refreshedToken,
        );
        debugPrint('FCM token refreshed for client $clientId');
      });
    } catch (e) {
      // على الويب قد يفشل FCM لغياب OAuth/Service Worker
      debugPrint('getFCMToken: $e');
    }
  }

  var contents = <ContentModel>[].obs;
  void fetchContents() async {
    contents.bindStream(_service.getContentsForClient(currentClient.value?.id));
    update();
  }

  Future<bool> updateContent(ContentModel content) async {
    isLoading.value = true;
    final result = await _service.updateContent(content);
    isLoading.value = false;
    return result;
  }

  @override
  void onInit() {
    fetchClients();
    // fetchContents();

    super.onInit();
  }

  @override
  void onClose() {
    _fcmTokenRefreshSub?.cancel();
    _fcmTokenRefreshSub = null;
    super.onClose();
  }
}
