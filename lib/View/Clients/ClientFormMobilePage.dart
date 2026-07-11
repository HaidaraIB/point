import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/ClientModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Services/meta/meta_graph_client.dart';
import 'package:point/View/Shared/app_date_time_picker.dart';
import 'package:point/View/Shared/InputText.dart';
import 'package:point/View/Shared/ReadOnlyAccountEmailField.dart';
import 'package:point/Utils/PasswordValidator.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:uuid/uuid.dart';

/// Mobile-only full-screen add/edit client form.
/// Opened when showAddEmployeeDialog is called on mobile; desktop keeps the dialog.
class ClientFormMobilePage extends StatefulWidget {
  final ClientModel? model;

  const ClientFormMobilePage({super.key, this.model});

  @override
  State<ClientFormMobilePage> createState() => _ClientFormMobilePageState();
}

class _ClientFormMobilePageState extends State<ClientFormMobilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController nameController;
  late final TextEditingController emailController;
  late final TextEditingController passwordController;
  late final TextEditingController descController;
  late final TextEditingController startDateController;
  late final TextEditingController endDateController;

  DateTime? startAt;
  DateTime? endAt;
  bool obscurePassword = true;
  final RxList<MetaBusinessAsset> _metaAssets = <MetaBusinessAsset>[].obs;
  final RxString _selectedMetaAssetValue = '__unlink_meta_asset__'.obs;
  final RxnString _metaLoadError = RxnString();
  final RxBool _metaLoading = false.obs;
  static const String _unlinkMetaAssetValue = '__unlink_meta_asset__';

  bool get _canEditCredentials {
    final m = widget.model;
    if (m == null) return true;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final au = m.authUid;
    return uid != null &&
        uid.isNotEmpty &&
        au != null &&
        au.isNotEmpty &&
        uid == au;
  }

  @override
  void initState() {
    super.initState();
    final m = widget.model;
    nameController = TextEditingController(text: m?.name);
    emailController = TextEditingController(text: m?.email);
    passwordController = TextEditingController();
    descController = TextEditingController(text: m?.description);
    startDateController = TextEditingController(text: FunHelper.formatdate(m?.startAt));
    endDateController = TextEditingController(text: FunHelper.formatdate(m?.endAt));
    startAt = m?.startAt;
    endAt = m?.endAt;
    Get.find<HomeController>().uploadedFilesPaths.assignAll(
      m != null && m.image != null ? [m.image!] : [],
    );
    _loadMetaAssets();
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    descController.dispose();
    startDateController.dispose();
    endDateController.dispose();
    super.dispose();
  }

  Future<void> _loadMetaAssets() async {
    _metaLoading.value = true;
    try {
      final settings = await MetaAppSettings.load();
      if (!mounted) return;
      if (settings == null) {
        _metaAssets.clear();
        _metaLoadError.value = 'Set Meta token in Publish settings';
        _selectedMetaAssetValue.value = _unlinkMetaAssetValue;
        return;
      }
      final assets = await MetaGraphClient.listBusinessAssets(settings);
      if (!mounted) return;
      _metaAssets.assignAll(assets);
      _metaLoadError.value = null;
      final linkedPageId = (widget.model?.metaPageId ?? '').trim();
      if (linkedPageId.isNotEmpty &&
          assets.any((asset) => asset.pageId == linkedPageId)) {
        _selectedMetaAssetValue.value = linkedPageId;
      } else {
        _selectedMetaAssetValue.value = _unlinkMetaAssetValue;
      }
    } catch (_) {
      if (!mounted) return;
      _metaAssets.clear();
      _metaLoadError.value = 'Set Meta token in Publish settings';
      _selectedMetaAssetValue.value = _unlinkMetaAssetValue;
    } finally {
      _metaLoading.value = false;
    }
  }

  Future<void> _pickStartDate() async {
    final picked = await pickAppDateTime(
      context,
      initialDateTime: startAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      startAt = picked;
      startDateController.text = FunHelper.formatdate(startAt) ?? '';
    });
  }

  Future<void> _pickEndDate() async {
    final picked = await pickAppDateTime(
      context,
      initialDateTime: endAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      endAt = picked;
      endDateController.text = FunHelper.formatdate(endAt) ?? '';
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (startAt == null || endAt == null) {
      FunHelper.showSnackbar(
        'validation.title'.tr,
        'validation.pick_dates'.tr,
        snackPosition: SnackPosition.BOTTOM,
        colorText: Colors.white,
        backgroundColor: Colors.red,
        autoHideAfter: const Duration(seconds: 4),

      );
      return;
    }
    final controller = Get.find<HomeController>();
    final model = widget.model;
    final selectedMetaAsset = _metaAssets.firstWhereOrNull(
      (asset) => asset.pageId == _selectedMetaAssetValue.value,
    );

    if (model == null) {
      final success = await controller.addClient(
        password:
            passwordController.text.trim().isEmpty
                ? 'TempPass@123'
                : passwordController.text.trim(),
        ClientModel(
          id: const Uuid().v4(),
          name: nameController.text,
          email: emailController.text,
          image: controller.uploadedFilesPaths.lastOrNull,
          description: descController.text,
          status: 'active',
          createdAt: DateTime.now(),
          startAt: startAt,
          endAt: endAt,
          metaPageId: selectedMetaAsset?.pageId,
          metaPageName: selectedMetaAsset?.pageName,
          metaPageAccessToken: selectedMetaAsset?.pageAccessToken,
          metaInstagramUserId: selectedMetaAsset?.instagramUserId,
          metaInstagramUserName: selectedMetaAsset?.instagramUserName,
        ),
      );
      if (!mounted) return;
      if (success) {
        controller.uploadedFilesPaths.clear();
        Get.back();
      }
    } else {
      final success = await controller.updateClient(
        model.copyWith(
          name: nameController.text,
          email:
              _canEditCredentials
                  ? emailController.text
                  : (model.email ?? ''),
          image: controller.uploadedFilesPaths.lastOrNull,
          startAt: startAt,
          endAt: endAt,
          description: descController.text,
          metaPageId: selectedMetaAsset?.pageId,
          metaPageName: selectedMetaAsset?.pageName,
          metaPageAccessToken: selectedMetaAsset?.pageAccessToken,
          metaInstagramUserId: selectedMetaAsset?.instagramUserId,
          metaInstagramUserName: selectedMetaAsset?.instagramUserName,
        ),
        newPassword:
            !_canEditCredentials || passwordController.text.trim().isEmpty
                ? null
                : passwordController.text.trim(),
      );
      if (!mounted) return;
      if (success) {
        controller.uploadedFilesPaths.clear();
        Get.back();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = context.appTheme;
    final bottomPadding = MediaQuery.of(context).padding.bottom + 24;

    return Scaffold(
      backgroundColor: appTheme.pageBackground,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.model == null ? 'addclient'.tr : 'editclient'.tr,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Get.back(),
        ),
      ),
      body: GetBuilder<HomeController>(
        builder: (controller) {
          return Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: InkWell(
                      onTap: () async {
                        final v = await controller.pickoneImage();
                        if (v.isNotEmpty) {
                          controller.uploadFiles(
                            filePathOrBytes: v.first.bytes!,
                            fileName: v.first.name,
                          );
                        }
                      },
                      child: Obx(
                        () => CircleAvatar(
                          backgroundColor: appTheme.unselected,
                          radius: 50,
                          child: controller.uploadedFilesPaths.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(50),
                                  child: Image.network(
                                    controller.uploadedFilesPaths.last,
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Icon(
                                  Icons.camera_alt,
                                  size: 50,
                                  color: appTheme.mutedText,
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  InputText(
                    labelText: 'name'.tr,
                    hintText: 'entername'.tr,
                    height: 48,
                    controller: nameController,
                    validator: (v) => (v == null || v.isEmpty) ? ' ' : null,
                    borderRadius: 8,
                  ),
                  const SizedBox(height: 16),
                  if (widget.model == null || _canEditCredentials) ...[
                    InputText(
                      labelText: 'email'.tr,
                      hintText: 'example@example.com'.tr,
                      height: 48,
                      textInputType: TextInputType.emailAddress,
                      controller: emailController,
                      validator: (v) {
                        if (v == null || v.isEmpty || !v.toString().isEmail) {
                          return ' ';
                        }
                        return null;
                      },
                      borderRadius: 8,
                    ),
                    const SizedBox(height: 16),
                    InputText(
                      hintText:
                          widget.model == null
                              ? '******'.tr
                              : 'leave_empty_unchanged'.tr,
                      labelText: 'password'.tr,
                      obscureText: obscurePassword,
                      controller: passwordController,
                      height: 48,
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: appTheme.mutedText,
                        ),
                        onPressed:
                            () => setState(() => obscurePassword = !obscurePassword),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return null;
                        return validatePasswordStrong(v);
                      },
                      borderRadius: 8,
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    ReadOnlyAccountEmailField(
                      email: widget.model?.email ?? '',
                      height: 48,
                      borderRadius: 8,
                    ),
                    const SizedBox(height: 16),
                  ],
                  InputText(
                    labelText: 'desc'.tr,
                    hintText: '',
                    expanded: true,
                    height: 80,
                    textInputType: TextInputType.multiline,
                    controller: descController,
                    validator: (v) => (v == null || v.isEmpty) ? ' ' : null,
                    borderRadius: 8,
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      'Meta page',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: appTheme.primaryText,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Obx(() {
                    if (_metaLoading.value) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: LinearProgressIndicator(minHeight: 3),
                      );
                    }
                    if (_metaLoadError.value != null) {
                      return Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          _metaLoadError.value!,
                          style: TextStyle(
                            color: Colors.orange.shade800,
                            fontSize: 12,
                          ),
                        ),
                      );
                    }
                    return SizedBox(
                      height: 48,
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedMetaAssetValue.value,
                        isExpanded: true,
                        dropdownColor: appTheme.cardSurface,
                        style: TextStyle(
                          fontSize: 13,
                          color: appTheme.primaryText,
                        ),
                        icon: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: appTheme.mutedText,
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: appTheme.inputFill,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: appTheme.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: appTheme.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: appTheme.accentText,
                              width: 1.5,
                            ),
                          ),
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: _unlinkMetaAssetValue,
                            child: Text(
                              'Unlink',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          ..._metaAssets.map(
                            (asset) => DropdownMenuItem<String>(
                              value: asset.pageId,
                              child: Text(
                                asset.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          _selectedMetaAssetValue.value = value;
                        },
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  InputText(
                    onTap: _pickStartDate,
                    labelText: 'startat'.tr,
                    hintText: '1/10/2025'.tr,
                    height: 48,
                    controller: startDateController,
                    readOnly: true,
                    validator: (v) => (v == null || v.isEmpty) ? ' ' : null,
                    suffixIcon: Icon(
                      CupertinoIcons.calendar,
                      color: appTheme.mutedText,
                    ),
                    borderRadius: 8,
                  ),
                  const SizedBox(height: 16),
                  InputText(
                    onTap: _pickEndDate,
                    labelText: 'endat'.tr,
                    hintText: '1/10/2026'.tr,
                    height: 48,
                    controller: endDateController,
                    readOnly: true,
                    validator: (v) => (v == null || v.isEmpty) ? ' ' : null,
                    suffixIcon: Icon(
                      CupertinoIcons.calendar,
                      color: appTheme.mutedText,
                    ),
                    borderRadius: 8,
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
                        onPressed: controller.isLoading.value ? null : _submit,
                        child: controller.isLoading.value
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'common.confirm'.tr,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        controller.uploadedFilesPaths.clear();
                        Get.back();
                      },
                      child: Text('common.cancel'.tr),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
