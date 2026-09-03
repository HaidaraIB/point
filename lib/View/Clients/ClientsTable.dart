import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/ClientModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/View/Shared/InputText.dart';
import 'package:point/View/Shared/ReadOnlyAccountEmailField.dart';
import 'package:point/View/Publish/meta_loading_overlay.dart';
import 'package:point/View/Clients/ClientFormMobilePage.dart';
import 'package:point/View/Clients/Mobile/ClientsMobileScreen.dart';
import 'package:point/View/Shared/ResponsiveScaffold.dart';
import 'package:point/View/Shared/button.dart';
import 'package:point/View/Shared/HorizontalScroll.dart';
import 'package:point/View/Shared/TableCellCenter.dart';
import 'package:point/View/Shared/responsive.dart';
import 'package:point/View/Shared/app_date_time_picker.dart';
import 'package:point/View/Shared/table_actions_menu_row.dart';
import 'package:point/Utils/PasswordValidator.dart';
import 'package:point/Services/meta/meta_graph_client.dart';
import 'package:point/Services/meta/meta_errors.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Shared/safe_network_image.dart';
import 'package:uuid/uuid.dart';

bool _canEditClientCredentials(ClientModel? model) {
  if (model == null) return true;
  final uid = FirebaseAuth.instance.currentUser?.uid;
  final au = model.authUid;
  return uid != null &&
      uid.isNotEmpty &&
      au != null &&
      au.isNotEmpty &&
      uid == au;
}

String _clientMetaPageTableLabel(ClientModel client) {
  final name = client.metaPageName?.trim() ?? '';
  if (name.isEmpty) return '--';
  final ig = client.metaInstagramUserName?.trim() ?? '';
  if (ig.isNotEmpty) return '$name / IG: $ig';
  return name;
}

class ClientsTable extends StatefulWidget {
  @override
  State<ClientsTable> createState() => _ClientsTableState();
}

class _ClientsTableState extends State<ClientsTable> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final hc = Get.find<HomeController>();
      final emp = hc.effectiveEmployee;
      if (emp == null) return;
      if (hc.clients.isNotEmpty) return;
      final role = emp.role.trim().toLowerCase();
      if (role != 'admin' && role != 'supervisor' && role != 'employee') {
        return;
      }
      await hc.syncAuthRoleAndRefreshDataStreams(emp);
    });
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = context.appTheme;
    return ResponsiveScaffold(
      selectedTab: 2,

      body: GetBuilder<HomeController>(
        builder: (controller) {
          final canDeleteClients =
              controller.effectiveEmployee?.role == 'admin';
          return Responsive(
            mobile: Obx(
              () => ClientsMobileScreen(
                clients: controller.clients.toList(),
                canDelete: canDeleteClients,
                onAdd: () => showAddEmployeeDialog(context),
                onEdit: (client) => showAddEmployeeDialog(context, model: client),
                onDelete: (client) {
                  FunHelper.showConfirmDailog(
                    context,
                    onTap: () async => await controller.deleteClient(client.id!),
                  );
                },
                onToggleStatus: (client) {
                  FunHelper.showConfirmDailog(
                    context,
                    onTap: () async {
                      await controller.updateClient(
                        client.copyWith(
                          status: client.status == 'active' ? 'inactive' : 'active',
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            desktop: Container(
              padding: const EdgeInsets.all(10),
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 50),
                  Row(
                    children: [
                      Text(
                        'clients'.tr,
                        style: TextStyle(
                          color: appTheme.primaryText,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Spacer(),
                      MainButton(
                        width: 180,
                        height: 45,
                        borderSize: 35,
                        fontColor: Colors.white,
                        backgroundColor: AppColors.primary,
                        widget: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'addnewclient'.tr,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            Icon(
                              Icons.add_circle_outline_rounded,
                              color: Colors.white,
                            ),
                          ],
                        ),
                        onPressed: () {
                          showAddEmployeeDialog(context);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: Obx(() {
                      if (controller.clients.isEmpty) {
                        return Center(
                          child: Text(
                            'history.empty_data'.tr,
                            style: TextStyle(
                              color: appTheme.secondaryText,
                              fontSize: 15,
                            ),
                          ),
                        );
                      }
                      return HorizontalScrollbarTable(
                        child: SizedBox(
                          width: (Get.width - 270).clamp(
                            1100.0,
                            double.infinity,
                          ),
                          child: DataTable(
                                dataRowMinHeight: 60,
                                dataRowMaxHeight: 60,
                                // headingRowColor: WidgetStateProperty.all(Colors.blue.shade50),
                                dataRowColor: context.tableDataRowColor,
                                headingRowColor: context.tableHeadingRowColor,
                                dividerThickness: 0.5,
                                columns: [
                                  DataColumn(
                                    headingRowAlignment:
                                        MainAxisAlignment.center,

                                    label: Text(
                                      'name'.tr,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: appTheme.secondaryText,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    headingRowAlignment:
                                        MainAxisAlignment.center,

                                    label: Text(
                                      'desc'.tr,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: appTheme.secondaryText,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    headingRowAlignment:
                                        MainAxisAlignment.center,
                                    label: Text(
                                      'publish.page_label'.tr,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: appTheme.secondaryText,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    headingRowAlignment:
                                        MainAxisAlignment.center,

                                    label: Text(
                                      'startat'.tr,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: appTheme.secondaryText,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    headingRowAlignment:
                                        MainAxisAlignment.center,
                                    label: Text(
                                      'endat'.tr,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: appTheme.secondaryText,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    headingRowAlignment:
                                        MainAxisAlignment.center,
                                    label: Text(
                                      'actions'.tr,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: appTheme.secondaryText,
                                      ),
                                    ),
                                  ),
                                ],
                                rows:
                                    controller.clients.map((emp) {
                                      return DataRow(
                                        cells: [
                                          DataCell(
                                            TableCellCenter(
                                              child: Text(
                                                emp.name ?? '',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color:
                                                      appTheme.secondaryText,
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            TableCellCenter(
                                              child: Container(
                                                constraints: BoxConstraints(
                                                  maxWidth: 150,
                                                ),
                                                child: Text(
                                                  emp.description ?? '--',
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color:
                                                        appTheme.secondaryText,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            TableCellCenter(
                                              child: Text(
                                                _clientMetaPageTableLabel(emp),
                                                textAlign: TextAlign.center,
                                                softWrap: true,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color:
                                                      appTheme.secondaryText,
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            TableCellCenter(
                                              child: Text(
                                                FunHelper.formatdate(
                                                      emp.startAt!,
                                                    ) ??
                                                    '',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color:
                                                      appTheme.secondaryText,
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            TableCellCenter(
                                              child: Text(
                                                FunHelper.formatdate(
                                                      emp.endAt!,
                                                    ) ??
                                                    '',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color:
                                                      appTheme.secondaryText,
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            TableCellCenter(
                                              child: PopupMenuButton<int>(
                                                tooltip:
                                                    'tasks.options_tooltip'.tr,
                                                padding: EdgeInsets.zero,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                color: Theme.of(context).colorScheme.surface,
                                                elevation: 4,
                                                itemBuilder: (context) {
                                                  final active =
                                                      emp.status == 'active';
                                                  final toggleVal =
                                                      canDeleteClients ? 2 : 1;
                                                  return [
                                                    PopupMenuItem(
                                                      value: 0,
                                                      child:
                                                          tableActionsMenuRow(
                                                        label: 'edit'.tr,
                                                        icon:
                                                            Icons.edit_outlined,
                                                        iconColor:
                                                            AppColors.success,
                                                      ),
                                                    ),
                                                    if (canDeleteClients)
                                                      PopupMenuItem(
                                                        value: 1,
                                                        child:
                                                            tableActionsMenuRow(
                                                          label: 'delete'.tr,
                                                          icon: Icons
                                                              .delete_outline,
                                                          iconColor: AppColors
                                                              .destructive,
                                                        ),
                                                      ),
                                                    PopupMenuItem(
                                                      value: toggleVal,
                                                      child:
                                                          tableActionsMenuRow(
                                                        label: active
                                                            ? 'common.disable'
                                                                .tr
                                                            : 'common.enable'
                                                                .tr,
                                                        icon: active
                                                            ? Icons
                                                                .pause_circle_outline
                                                            : Icons
                                                                .play_circle_outline,
                                                        iconColor: active
                                                            ? AppColors.caution
                                                            : AppColors
                                                                .success,
                                                      ),
                                                    ),
                                                  ];
                                                },
                                                onSelected: (value) {
                                                  if (value == 0) {
                                                    showAddEmployeeDialog(
                                                      context,
                                                      model: emp,
                                                    );
                                                  } else if (canDeleteClients &&
                                                      value == 1) {
                                                    FunHelper.showConfirmDailog(
                                                      context,
                                                      onTap: () async {
                                                        await controller
                                                            .deleteClient(
                                                              emp.id!,
                                                            );
                                                      },
                                                    );
                                                  } else if (value ==
                                                      (canDeleteClients
                                                          ? 2
                                                          : 1)) {
                                                    FunHelper.showConfirmDailog(
                                                      context,
                                                      onTap: () async {
                                                        await controller
                                                            .updateClient(
                                                          emp.copyWith(
                                                            status: emp.status ==
                                                                    'active'
                                                                ? 'inactive'
                                                                : 'active',
                                                          ),
                                                        );
                                                      },
                                                    );
                                                  }
                                                },
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.all(8),
                                                  child: Icon(
                                                    Icons.more_vert,
                                                    color: appTheme.primaryText,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                              ),
                          ),
                        );
                      }),
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

Future<void> showAddEmployeeDialog(BuildContext context, {ClientModel? model}) async {
  if (Responsive.isMobile(context)) {
    Get.to(() => ClientFormMobilePage(model: model));
    return;
  }
  final nameController = TextEditingController(text: model?.name);
  final emailController = TextEditingController(text: model?.email);
  final passwordController = TextEditingController();
  final desccontroller = TextEditingController(text: model?.description);
  final startatcontroller = TextEditingController(
    text: FunHelper.formatdate(model?.startAt),
  );
  final endatcontroller = TextEditingController(
    text: FunHelper.formatdate(model?.endAt),
  );
  DateTime? startAt = model?.startAt;
  DateTime? endAt = model?.endAt;
  Get.find<HomeController>().uploadedFilesPaths.assignAll(
    model != null && model.image != null ? [model.image!] : [],
  );
  // String selectedRole = model?.role ?? "media_buyer";
  // List<String> roles = ["media_buyer", "designer", "developer", "manager"];
  var _key = GlobalKey<FormState>();
  bool obscurePassword = true;
  final canEditCredentials = _canEditClientCredentials(model);
  const unlinkMetaAssetValue = '__unlink_meta_asset__';
  final metaAssets = <MetaBusinessAsset>[];
  String? metaLoadError;
  await runWithMetaGraphLoadingOverlay(() async {
    try {
      final settings = await MetaAppSettings.load();
      if (settings != null) {
        metaAssets.addAll(await MetaGraphClient.listBusinessAssets(settings));
      }
    } catch (e) {
      metaLoadError = formatMetaPublishFailure(e, Get.locale?.languageCode ?? 'ar');
    }
  });
  final selectedMetaAssetValue = (() {
    final linkedPageId = (model?.metaPageId ?? '').trim();
    if (linkedPageId.isEmpty) return unlinkMetaAssetValue;
    final matched = metaAssets.firstWhereOrNull((a) => a.pageId == linkedPageId);
    if (matched != null) return matched.pageId;
    return unlinkMetaAssetValue;
  })().obs;
  showDialog(
    barrierDismissible: false,
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          final appTheme = context.appTheme;
          return Dialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: GetBuilder<HomeController>(
              builder: (controller) {
                return Form(
                  key: _key,
                  child: SizedBox(
                    width: Get.width * 0.5,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header
                          Container(
                            margin: EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: appTheme.accentText,
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(12),
                              ),
                            ),
                            padding: EdgeInsets.all(16),
                            child: Row(
                              children: [
                                SvgPicture.asset(
                                  'assets/svgs/icon_check_circle.svg',
                                ),
                                SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'addclient'.tr,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    Text(
                                      'addclienthint'.tr,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Content
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Builder(
                                  builder:
                                      (c) => InkWell(
                                        onTap: () async {
                                          await controller.pickoneImage().then((
                                            v,
                                          ) {
                                            if (v.isNotEmpty) {
                                              controller.uploadFiles(
                                                filePathOrBytes: v.first.bytes!,
                                                fileName: v.first.name,
                                              );
                                            }
                                          });
                                        },
                                        child: CircleAvatar(
                                          backgroundColor: appTheme.unselected,
                                          radius: 50,
                                          child: Obx(
                                            () =>
                                                controller
                                                        .uploadedFilesPaths
                                                        .isNotEmpty
                                                    ? ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            50,
                                                          ),
                                                      child: SafeNetworkImage(
                                                        controller
                                                            .uploadedFilesPaths
                                                            .last,
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
                                InputText(
                                  labelText: 'name'.tr,
                                  hintText: 'entername'.tr,
                                  height: 42,
                                  controller: nameController,

                                  validator: (v) {
                                    if (v == null || v.isEmpty) {
                                      return ' ';
                                    }
                                    return null;
                                  },

                                  borderRadius: 5,
                                ),
                                if (model == null || canEditCredentials)
                                  InputText(
                                    labelText: 'email'.tr,
                                    hintText: 'example@example.com'.tr,
                                    height: 42,
                                    textInputType: TextInputType.emailAddress,
                                    controller: emailController,
                                    validator: (v) {
                                      if (v == null ||
                                          v.isEmpty ||
                                          !v.toString().isEmail) {
                                        return ' ';
                                      }
                                      return null;
                                    },
                                    borderRadius: 5,
                                  )
                                else
                                  ReadOnlyAccountEmailField(
                                    email: model.email ?? '',
                                    height: 42,
                                    borderRadius: 5,
                                  ),
                                if (model == null || canEditCredentials)
                                  InputText(
                                    hintText:
                                        model == null
                                            ? '******'.tr
                                            : 'leave_empty_unchanged'.tr,
                                    labelText: 'password'.tr,
                                    obscureText: obscurePassword,
                                    controller: passwordController,
                                    height: 42,
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        obscurePassword
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                        color: appTheme.mutedText,
                                      ),
                                      onPressed: () {
                                        obscurePassword = !obscurePassword;
                                        setState(() {});
                                      },
                                    ),
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) {
                                        return null;
                                      }
                                      return validatePasswordStrong(v.trim());
                                    },
                                    borderRadius: 5,
                                  ),
                                InputText(
                                  labelText: 'desc'.tr,
                                  hintText: ''.tr,
                                  expanded: true,
                                  height: 42,
                                  textInputType: TextInputType.emailAddress,
                                  controller: desccontroller,

                                  validator: (v) {
                                    if (v == null || v.isEmpty) {
                                      return ' ';
                                    }
                                    return null;
                                  },

                                  borderRadius: 5,
                                ),
                                const SizedBox(height: 8),
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
                                if (metaLoadError != null)
                                  Align(
                                    alignment: AlignmentDirectional.centerStart,
                                    child: Text(
                                      metaLoadError!,
                                      style: TextStyle(
                                        color: Colors.orange.shade800,
                                        fontSize: 12,
                                      ),
                                    ),
                                  )
                                else
                                  Obx(
                                    () => DropdownButtonFormField<String>(
                                      initialValue: selectedMetaAssetValue.value,
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
                                        isDense: true,
                                        filled: true,
                                        fillColor: appTheme.inputFill,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(5),
                                          borderSide: BorderSide(
                                            color: appTheme.border,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(5),
                                          borderSide: BorderSide(
                                            color: appTheme.border,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(5),
                                          borderSide: BorderSide(
                                            color: appTheme.accentText,
                                            width: 1.5,
                                          ),
                                        ),
                                      ),
                                      items: [
                                        const DropdownMenuItem<String>(
                                          value: unlinkMetaAssetValue,
                                          child: Text('Unlink'),
                                        ),
                                        ...metaAssets.map(
                                          (asset) => DropdownMenuItem<String>(
                                            value: asset.pageId,
                                            child: Text(
                                              asset.label,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                      ],
                                      onChanged: (value) {
                                        if (value == null) return;
                                        selectedMetaAssetValue.value = value;
                                      },
                                    ),
                                  ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    SizedBox(
                                      width: Get.width / 4.3,
                                      child: InputText(
                                        onTap: () async {
                                          final picked = await customDatePicker(
                                            context,
                                            initialDateTime: startAt,
                                          );
                                          if (picked != null) {
                                            startAt = picked;
                                            startatcontroller.text = DateFormat(
                                              'dd MM yyyy - hh:mm a',
                                            ).format(picked.toLocal());
                                          }
                                        },
                                        labelText: 'startat'.tr,
                                        hintText: '1/10/2025'.tr,
                                        height: 42,
                                        textInputType: TextInputType.datetime,
                                        controller: startatcontroller,
                                        readOnly: true,
                                        // enable: false,
                                        validator: (v) {
                                          if (v == null || v.isEmpty) {
                                            return ' ';
                                          }
                                          return null;
                                        },
                                        suffixIcon: Icon(
                                          CupertinoIcons.calendar,
                                          color: appTheme.mutedText,
                                        ),

                                        borderRadius: 5,
                                      ),
                                    ),
                                    SizedBox(
                                      width: Get.width / 4.3,

                                      child: InputText(
                                        labelText: 'endat'.tr,
                                        hintText: '1/10/2026'.tr,
                                        readOnly: true,

                                        onTap: () async {
                                          final picked = await customDatePicker(
                                            context,
                                            initialDateTime: endAt,
                                          );
                                          if (picked != null) {
                                            endAt = picked;
                                            endatcontroller.text = DateFormat(
                                              'dd MM yyyy - hh:mm a',
                                            ).format(picked.toLocal());
                                          }
                                        },
                                        height: 42,
                                        textInputType: TextInputType.datetime,
                                        controller: endatcontroller,
                                        // enable: false,
                                        validator: (v) {
                                          if (v == null || v.isEmpty) {
                                            return ' ';
                                          }
                                          return null;
                                        },
                                        suffixIcon: Icon(
                                          CupertinoIcons.calendar,
                                          color: appTheme.mutedText,
                                        ),
                                        borderRadius: 5,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Actions
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Obx(
                                  () => SizedBox(
                                    width: Get.width * 0.5 - 260,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            24,
                                          ),
                                        ),
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 48,
                                          vertical: 20,
                                        ),
                                      ),
                                      onPressed: () {
                                        if (_key.currentState!.validate()) {
                                          if (model == null) {
                                            final selectedAsset = metaAssets
                                                .firstWhereOrNull(
                                                  (a) =>
                                                      a.pageId ==
                                                      selectedMetaAssetValue.value,
                                                );
                                            controller
                                                .addClient(
                                                  password:
                                                      passwordController.text.trim().isEmpty
                                                          ? 'TempPass@123'
                                                          : passwordController.text.trim(),
                                                  ClientModel(
                                                    id:
                                                        const Uuid().v4(),
                                                    name: nameController.text,
                                                    email: emailController.text,
                                                    image:
                                                        controller
                                                            .uploadedFilesPaths
                                                            .lastOrNull,
                                                    description:
                                                        desccontroller.text,
                                                    status: 'active',
                                                    createdAt: DateTime.now(),

                                                    startAt: startAt,
                                                    endAt: endAt,
                                                    metaPageId:
                                                        selectedAsset?.pageId,
                                                    metaPageName:
                                                        selectedAsset?.pageName,
                                                    metaPageAccessToken:
                                                        selectedAsset
                                                            ?.pageAccessToken,
                                                    metaInstagramUserId:
                                                        selectedAsset
                                                            ?.instagramUserId,
                                                    metaInstagramUserName:
                                                        selectedAsset
                                                            ?.instagramUserName,
                                                  ),
                                                )
                                                .then((v) {
                                                  if (v) {
                                                    controller
                                                        .uploadedFilesPaths
                                                        .clear();

                                                    Get.back();
                                                  }
                                                });
                                          } else {
                                            final selectedAsset = metaAssets
                                                .firstWhereOrNull(
                                                  (a) =>
                                                      a.pageId ==
                                                      selectedMetaAssetValue.value,
                                                );
                                            // log(
                                            //   controller
                                            //       .uploadedFilesPaths
                                            //       .lastOrNull
                                            //       .toString(),
                                            // );
                                            // return;
                                            controller
                                                .updateClient(
                                                  model.copyWith(
                                                    name: nameController.text,
                                                    email:
                                                        canEditCredentials
                                                            ? emailController.text
                                                            : (model.email ?? ''),
                                                    image:
                                                        controller
                                                            .uploadedFilesPaths
                                                            .lastOrNull,

                                                    startAt: startAt,
                                                    endAt: endAt,
                                                    description:
                                                        desccontroller.text,
                                                    metaPageId:
                                                        selectedAsset?.pageId,
                                                    metaPageName:
                                                        selectedAsset?.pageName,
                                                    metaPageAccessToken:
                                                        selectedAsset
                                                            ?.pageAccessToken,
                                                    metaInstagramUserId:
                                                        selectedAsset
                                                            ?.instagramUserId,
                                                    metaInstagramUserName:
                                                        selectedAsset
                                                            ?.instagramUserName,
                                                  ),
                                                  newPassword:
                                                      !canEditCredentials ||
                                                              passwordController.text.trim().isEmpty
                                                          ? null
                                                          : passwordController.text.trim(),
                                                )
                                                .then((v) {
                                                  if (v) {
                                                    controller
                                                        .uploadedFilesPaths
                                                        .clear();

                                                    Get.back();
                                                  }
                                                });
                                          }
                                        }
                                      },
                                      child:
                                          controller.isLoading.value
                                              ? Center(
                                                child:
                                                    CircularProgressIndicator(),
                                              )
                                              : Text(
                                                'common.confirm'.tr,
                                                style: TextStyle(
                                                  color: Colors.white,
                                                ),
                                              ),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 190,
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 32,
                                        vertical: 20,
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
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      );
    },
  );
}

// Future<DateTime?> customDatePicker(BuildContext context) async {
//   DateTime selectedDate = DateTime.now();

//   final pickedDate = await showDialog<DateTime>(
//     context: context,
//     builder: (context) {
//       return AlertDialog(
//         backgroundColor: Theme.of(context).colorScheme.surface,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//         // title: const Text("اختر التاريخ"),
//         content: SizedBox(
//           height: 400,
//           width: 350,
//           child: CalendarDatePicker(

//             initialDate: DateTime.now(),
//             firstDate: DateTime(2000),
//             lastDate: DateTime(2100),
//             onDateChanged: (date) {
//               selectedDate = date;
//             },
//           ),
//         ),
//         actions: [
//           SizedBox(
//             width: 160,
//             child: ElevatedButton(
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: AppColors.primary,
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(24),
//                 ),
//                 padding: EdgeInsets.symmetric(horizontal: 48, vertical: 20),
//               ),
//               onPressed: () {
//                 Navigator.pop(context, selectedDate);
//               },
//               child: Text(
//                 "تأكيد",
//                 style: TextStyle(color: Colors.white),
//               ),
//             ),
//           ),
//           SizedBox(
//             width: 160,
//             child: OutlinedButton(
//               style: OutlinedButton.styleFrom(
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(24),
//                 ),
//                 padding: EdgeInsets.symmetric(horizontal: 32, vertical: 20),
//               ),
//               onPressed: () => Navigator.pop(context),
//               child: Text('common.cancel'.tr),
//             ),
//           ),
//         ],
//       );
//     },
//   );

//   if (pickedDate != null) {
//     log("✅ Selected: $pickedDate");
//     return pickedDate;
//   } else {
//     log("❌ Cancelled");
//     return null;
//   }
// }
Future<DateTime?> customDatePicker(
  BuildContext context, {
  DateTime? initialDateTime,
}) {
  return pickAppDateTime(
    context,
    initialDateTime: initialDateTime,
    firstDate: DateTime(2000),
    lastDate: DateTime(2100),
  );
}
