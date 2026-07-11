import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:point/Controller/ClientController.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/View/Shared/InputText.dart';
import 'package:point/View/Shared/ReadOnlyAccountEmailField.dart';
import 'package:point/View/Shared/app_version_label.dart';
import 'package:point/Models/ClientModel.dart';
import 'package:point/Utils/app_theme_extension.dart';

class ClientProfileForm extends StatefulWidget {
  const ClientProfileForm({
    super.key,
    this.closeOnSuccess = false,
    this.padding = EdgeInsets.zero,
  });

  final bool closeOnSuccess;
  final EdgeInsetsGeometry padding;

  @override
  State<ClientProfileForm> createState() => _ClientProfileFormState();
}

class _ClientProfileFormState extends State<ClientProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  String _lastHydratedClientId = '';

  @override
  void initState() {
    super.initState();
    final clientController = Get.find<ClientController>();
    final uploadController = Get.find<HomeController>();
    final client = clientController.currentClient.value;
    _nameController = TextEditingController(text: client?.name ?? '');
    uploadController.uploadedFilesPaths.assignAll(
      client != null && (client.image ?? '').trim().isNotEmpty
          ? [client.image!.trim()]
          : [],
    );
  }

  void _hydrateFromClient({
    required ClientController clientController,
    required HomeController uploadController,
  }) {
    final client = clientController.currentClient.value;
    if (client == null) return;

    final clientId = (client.id ?? '').trim();
    final shouldHydrateName =
        _lastHydratedClientId != clientId || _nameController.text.trim().isEmpty;
    if (shouldHydrateName) {
      final name = (client.name ?? '').trim();
      _nameController.value = TextEditingValue(
        text: name,
        selection: TextSelection.collapsed(offset: name.length),
      );
      _lastHydratedClientId = clientId;
    }

    final image = (client.image ?? '').trim();
    if (uploadController.uploadedFilesPaths.isEmpty && image.isNotEmpty) {
      uploadController.uploadedFilesPaths.assignAll([image]);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    Get.find<HomeController>().uploadedFilesPaths.clear();
    super.dispose();
  }

  /// Firestore doc may lag behind auth on cold start; prefer doc email, else JWT.
  static String _accountEmail(ClientModel? client) {
    final fromDoc = (client?.email ?? '').trim();
    if (fromDoc.isNotEmpty) return fromDoc;
    return (FirebaseAuth.instance.currentUser?.email ?? '').trim();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final clientController = Get.find<ClientController>();
    final uploadController = Get.find<HomeController>();
    final client = clientController.currentClient.value;
    if (client == null) return;

    final imageUrl =
        uploadController.uploadedFilesPaths.isNotEmpty
            ? uploadController.uploadedFilesPaths.last
            : client.image;

    final ok = await clientController.updateClient(
      client.copyWith(name: _nameController.text.trim(), image: imageUrl),
    );
    if (!mounted) return;
    if (ok) {
      uploadController.uploadedFilesPaths.clear();
      if (widget.closeOnSuccess) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ClientController>(
      builder: (clientController) {
        final uploadController = Get.find<HomeController>();
        return Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: widget.padding,
            child: Obx(() {
              final client = clientController.currentClient.value;
              _hydrateFromClient(
                clientController: clientController,
                uploadController: uploadController,
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: InkWell(
                        onTap: () async {
                          final files = await uploadController.pickoneImage();
                          if (files.isNotEmpty) {
                            await uploadController.uploadFiles(
                              filePathOrBytes: files.first.bytes!,
                              fileName: files.first.name,
                            );
                            if (mounted) setState(() {});
                          }
                        },
                        child: Obx(
                          () => CircleAvatar(
                            backgroundColor: context.appTheme.unselected,
                            radius: 50,
                            child:
                                uploadController.uploadedFilesPaths.isNotEmpty
                                    ? ClipRRect(
                                      borderRadius: BorderRadius.circular(50),
                                      child: Image.network(
                                        uploadController.uploadedFilesPaths.last,
                                        width: 100,
                                        height: 100,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (_, __, ___) => Icon(
                                              Icons.person,
                                              size: 50,
                                              color: context.appTheme.accentText,
                                            ),
                                      ),
                                    )
                                    : (client != null &&
                                            (client.image ?? '').trim().isNotEmpty)
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              50,
                                            ),
                                            child: Image.network(
                                              client.image!.trim(),
                                              width: 100,
                                              height: 100,
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (_, __, ___) => Icon(
                                                    Icons.camera_alt,
                                                    size: 50,
                                                    color: context.appTheme.accentText,
                                                  ),
                                            ),
                                          )
                                        : Icon(
                                            Icons.camera_alt,
                                            size: 50,
                                            color: context.appTheme.accentText,
                                          ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  InputText(
                    labelText: 'client.profile.name'.tr,
                    hintText: 'entername'.tr,
                    height: 48,
                    controller: _nameController,
                    validator: (v) => (v == null || v.trim().isEmpty) ? ' ' : null,
                    borderRadius: 8,
                  ),
                  const SizedBox(height: 16),
                  ReadOnlyAccountEmailField(
                    email: _accountEmail(client),
                    height: 48,
                    borderRadius: 8,
                  ),
                  const SizedBox(height: 16),
                  _readOnlyLine(
                    label: 'client.profile.role'.tr,
                    value: 'user_type_client'.tr,
                  ),
                  const SizedBox(height: 32),
                  Obx(
                    () => SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed:
                            clientController.isLoading.value ? null : _save,
                        child:
                            clientController.isLoading.value
                                ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                                : Text(
                                  'client.profile.save'.tr,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                      ),
                    ),
                  ),
                  AppVersionLabel(
                    padding: const EdgeInsets.only(top: 24),
                    textStyle: TextStyle(
                      fontSize: 12,
                      height: 1.25,
                      color: context.appTheme.mutedText,
                    ),
                  ),
                ],
              );
            }),
          ),
        );
      },
    );
  }

  Widget _readOnlyLine({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.appTheme.secondaryText,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: context.appTheme.inputFill,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: context.appTheme.border),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 15,
              color: context.appTheme.primaryText,
            ),
          ),
        ),
      ],
    );
  }
}

void showClientProfileDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      final h = MediaQuery.sizeOf(ctx).height;
      final dialogH = h < 600 ? h * 0.92 : (h * 0.9).clamp(400.0, 640.0);
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: 440,
          height: dialogH,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 4, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'client.profile.title'.tr,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: context.appTheme.primaryText,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: MaterialLocalizations.of(ctx).closeButtonTooltip,
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: context.appTheme.border),
              Expanded(
                child: ClientProfileForm(
                  closeOnSuccess: true,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
