import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Services/FireStoreServices.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/push_notification_test_catalog.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/View/Shared/InputText.dart';
import 'package:point/View/Shared/responsive.dart';

/// حوار لمسؤولي النظام (admin / supervisor):
/// إرسال تجربة Push: أي [notificationType] إلى أي مزيج من الموظفين والعملاء.
void showPushNotificationTestDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 720,
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.92,
            minWidth: 280,
          ),
          child: const _PushNotificationTestDialogBody(),
        ),
      );
    },
  );
}

class _PushNotificationTestDialogBody extends StatefulWidget {
  const _PushNotificationTestDialogBody();

  @override
  State<_PushNotificationTestDialogBody> createState() =>
      _PushNotificationTestDialogBodyState();
}

class _PushNotificationTestDialogBodyState
    extends State<_PushNotificationTestDialogBody> {
  late final List<PushNotificationTestDefinition> _catalog;
  late PushNotificationTestDefinition _selected;
  final TextEditingController _typeFilter = TextEditingController();
  final TextEditingController _recipientSearch = TextEditingController();
  final Set<String> _empIds = <String>{};
  final Set<String> _clientIds = <String>{};
  bool _sendPush = true;
  bool _sendEmail = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _catalog = sortedPushTestCatalog();
    _selected = _catalog.first;
    _typeFilter.addListener(_onTypeFilterChanged);
    _recipientSearch.addListener(_onRecipientSearchChanged);
  }

  void _onRecipientSearchChanged() => setState(() {});

  void _onTypeFilterChanged() {
    final visible = _filteredTypes;
    if (visible.isEmpty) return;
    if (!visible.any((e) => e.notificationType == _selected.notificationType)) {
      setState(() => _selected = visible.first);
    } else {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _typeFilter.removeListener(_onTypeFilterChanged);
    _recipientSearch.removeListener(_onRecipientSearchChanged);
    _typeFilter.dispose();
    _recipientSearch.dispose();
    super.dispose();
  }

  List<PushNotificationTestDefinition> get _filteredTypes {
    final q = _typeFilter.text.trim().toLowerCase();
    if (q.isEmpty) return _catalog;
    return _catalog
        .where((t) => t.notificationType.toLowerCase().contains(q))
        .toList();
  }

  void _addMe(HomeController c) {
    final id = c.effectiveEmployee?.id;
    if (id == null || id.isEmpty) return;
    setState(() => _empIds.add(id));
  }

  void _selectAllEmployees(HomeController c) {
    setState(() {
      for (final e in c.employees) {
        final id = e.id;
        if (id != null && id.isNotEmpty) _empIds.add(id);
      }
    });
  }

  void _selectAllClients(HomeController c) {
    setState(() {
      for (final cl in c.clients) {
        final id = cl.id;
        if (id != null && id.isNotEmpty) _clientIds.add(id);
      }
    });
  }

  Future<void> _send(HomeController c) async {
    if (!_sendPush && !_sendEmail) {
      FunHelper.showSnackbar(
        'error'.tr,
        AppLocaleKeys.pushTestNoChannel.tr,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    final title = '[TEST] ${_selected.notificationType}';
    final body =
        'Push test • ${DateTime.now().toIso8601String()} • ${c.effectiveEmployee?.name ?? ''}';

    setState(() => _sending = true);
    try {
      for (final id in _empIds) {
        await FirestoreServices.sendFcm(
          userId: id,
          title: title,
          body: body,
          notificationType: _selected.notificationType,
          sendPush: _sendPush,
          sendEmail: _sendEmail,
        );
      }
      for (final id in _clientIds) {
        await FirestoreServices.sendFcmForClient(
          userId: id,
          title: title,
          body: body,
          notificationType: _selected.notificationType,
          sendPush: _sendPush,
          sendEmail: _sendEmail,
        );
      }

      if (mounted) {
        final anyTarget = _empIds.isNotEmpty || _clientIds.isNotEmpty;
        FunHelper.showSnackbar(
          'success'.tr,
          anyTarget
              ? AppLocaleKeys.pushTestDone.tr
              : AppLocaleKeys.pushTestNoTargetsClosed.tr,
          snackPosition: SnackPosition.TOP,
          backgroundColor: anyTarget ? Colors.green : Colors.blueGrey,
          colorText: Colors.white,
        );
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Get.find<HomeController>();
    final isDesktop = Responsive.isDesktop(context);
    final qRec = _recipientSearch.text.trim().toLowerCase();
    final h = MediaQuery.sizeOf(context).height * 0.92;

    return SizedBox(
      height: h,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context),
          if (isDesktop) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                AppLocaleKeys.pushTestAudienceHint.tr,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _buildTypeColumn()),
                    const SizedBox(width: 12),
                    Expanded(child: _buildRecipientsColumn(c, qRec)),
                  ],
                ),
              ),
            ),
          ] else
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      AppLocaleKeys.pushTestAudienceHint.tr,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 12),
                    _buildTypeColumnMobile(),
                    const SizedBox(height: 16),
                    _buildRecipientsColumnMobile(c, qRec),
                    const SizedBox(height: 16),
                    _buildChannelRow(),
                    const SizedBox(height: 12),
                    _buildActionRow(context, c),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          if (isDesktop)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildChannelRow(),
                  const SizedBox(height: 8),
                  _buildActionRow(context, c),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const Icon(Icons.bug_report_outlined, color: Colors.white, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocaleKeys.pushTestTitle.tr,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  AppLocaleKeys.pushTestSubtitle.tr,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _sending ? null : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelRow() {
    return Row(
      children: [
        Expanded(
          child: CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _sendPush,
            onChanged:
                _sending ? null : (v) => setState(() => _sendPush = v ?? true),
            title: Text(
              AppLocaleKeys.pushTestSendPush.tr,
              style: const TextStyle(fontSize: 13),
            ),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ),
        Expanded(
          child: CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _sendEmail,
            onChanged:
                _sending ? null : (v) => setState(() => _sendEmail = v ?? false),
            title: Text(
              AppLocaleKeys.pushTestSendEmail.tr,
              style: const TextStyle(fontSize: 13),
            ),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ),
      ],
    );
  }

  Widget _buildActionRow(BuildContext context, HomeController c) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _sending ? null : () => Navigator.pop(context),
            child: Text(AppLocaleKeys.commonCancel.tr),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5C5589),
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.white70,
            ),
            onPressed: _sending ? null : () => _send(c),
            child:
                _sending
                    ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                    : Text(
                      AppLocaleKeys.pushTestSend.tr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
          ),
        ),
      ],
    );
  }

  Widget _buildTypeColumnMobile() {
    final types = _filteredTypes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InputText(
          labelText: AppLocaleKeys.pushTestFilterTypes.tr,
          hintText: AppLocaleKeys.commonSearch.tr,
          height: 40,
          fillColor: Colors.white,
          controller: _typeFilter,
          borderRadius: 8,
          borderColor: Colors.grey.shade300,
        ),
        const SizedBox(height: 8),
        Text(
          AppLocaleKeys.pushTestSelectType.tr,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 4),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child:
              types.isEmpty
                  ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      AppLocaleKeys.pushTestNoMatches.tr,
                      textAlign: TextAlign.center,
                    ),
                  )
                  : RadioGroup<String>(
                    groupValue: _selected.notificationType,
                    onChanged: (v) {
                      if (_sending || v == null) return;
                      setState(
                        () => _selected = types.firstWhere(
                          (e) => e.notificationType == v,
                        ),
                      );
                    },
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: types.length,
                      itemBuilder: (context, i) {
                        final def = types[i];
                        final sel =
                            def.notificationType ==
                            _selected.notificationType;
                        return RadioListTile<String>(
                          dense: true,
                          enabled: !_sending,
                          value: def.notificationType,
                          title: Text(
                            def.notificationType,
                            style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                          subtitle: Text(
                            def.categoryKey.tr,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          selected: sel,
                        );
                      },
                    ),
                  ),
        ),
      ],
    );
  }

  Widget _buildRecipientsColumnMobile(HomeController c, String qRec) {
    return Obx(() {
      final emps =
          c.employees.where((e) {
            final id = e.id;
            if (id == null || id.isEmpty) return false;
            if (qRec.isEmpty) return true;
            final name = (e.name ?? '').toLowerCase();
            return name.contains(qRec) || id.toLowerCase().contains(qRec);
          }).toList();
      final cls =
          c.clients.where((cl) {
            final id = cl.id;
            if (id == null || id.isEmpty) return false;
            if (qRec.isEmpty) return true;
            final name = (cl.name ?? '').toLowerCase();
            return name.contains(qRec) || id.toLowerCase().contains(qRec);
          }).toList();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InputText(
            labelText: AppLocaleKeys.pushTestSearchRecipients.tr,
            hintText: AppLocaleKeys.commonSearch.tr,
            height: 40,
            fillColor: Colors.white,
            controller: _recipientSearch,
            borderRadius: 8,
            borderColor: Colors.grey.shade300,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              TextButton(
                onPressed: _sending ? null : () => _addMe(c),
                child: Text(AppLocaleKeys.pushTestSelectMe.tr),
              ),
              TextButton(
                onPressed: _sending ? null : () => _selectAllEmployees(c),
                child: Text(AppLocaleKeys.pushTestSelectAllEmployees.tr),
              ),
              TextButton(
                onPressed: _sending ? null : () => _selectAllClients(c),
                child: Text(AppLocaleKeys.pushTestSelectAllClients.tr),
              ),
              TextButton(
                onPressed:
                    _sending
                        ? null
                        : () => setState(() {
                          _empIds.clear();
                          _clientIds.clear();
                        }),
                child: Text(AppLocaleKeys.pushTestClearRecipients.tr),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _recipientSectionMobile(
                  title: AppLocaleKeys.pushTestEmployees.tr,
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: emps.length,
                    itemBuilder: (context, i) {
                      final e = emps[i];
                      final id = e.id!;
                      return CheckboxListTile(
                        dense: true,
                        value: _empIds.contains(id),
                        onChanged:
                            _sending
                                ? null
                                : (v) {
                                  setState(() {
                                    if (v == true) {
                                      _empIds.add(id);
                                    } else {
                                      _empIds.remove(id);
                                    }
                                  });
                                },
                        title: Text(
                          e.name ?? id,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          e.role,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _recipientSectionMobile(
                  title: AppLocaleKeys.pushTestClients.tr,
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: cls.length,
                    itemBuilder: (context, i) {
                      final cl = cls[i];
                      final id = cl.id!;
                      return CheckboxListTile(
                        dense: true,
                        value: _clientIds.contains(id),
                        onChanged:
                            _sending
                                ? null
                                : (v) {
                                  setState(() {
                                    if (v == true) {
                                      _clientIds.add(id);
                                    } else {
                                      _clientIds.remove(id);
                                    }
                                  });
                                },
                        title: Text(
                          cl.name ?? id,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    });
  }

  Widget _recipientSectionMobile({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: child,
        ),
      ],
    );
  }

  Widget _buildTypeColumn() {
    final types = _filteredTypes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InputText(
          labelText: AppLocaleKeys.pushTestFilterTypes.tr,
          hintText: AppLocaleKeys.commonSearch.tr,
          height: 40,
          fillColor: Colors.white,
          controller: _typeFilter,
          borderRadius: 8,
          borderColor: Colors.grey.shade300,
        ),
        const SizedBox(height: 8),
        Text(
          AppLocaleKeys.pushTestSelectType.tr,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child:
                types.isEmpty
                    ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          AppLocaleKeys.pushTestNoMatches.tr,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                    : RadioGroup<String>(
              groupValue: _selected.notificationType,
              onChanged: (v) {
                if (_sending || v == null) return;
                setState(
                  () => _selected = types.firstWhere(
                    (e) => e.notificationType == v,
                  ),
                );
              },
              child: ListView.builder(
                itemCount: types.length,
                itemBuilder: (context, i) {
                  final def = types[i];
                  final sel =
                      def.notificationType == _selected.notificationType;
                  return RadioListTile<String>(
                    dense: true,
                    enabled: !_sending,
                    value: def.notificationType,
                    title: Text(
                      def.notificationType,
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                    subtitle: Text(
                      def.categoryKey.tr,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    selected: sel,
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecipientsColumn(HomeController c, String qRec) {
    return Obx(() {
      final emps =
          c.employees.where((e) {
            final id = e.id;
            if (id == null || id.isEmpty) return false;
            if (qRec.isEmpty) return true;
            final name = (e.name ?? '').toLowerCase();
            return name.contains(qRec) || id.toLowerCase().contains(qRec);
          }).toList();
      final cls =
          c.clients.where((cl) {
            final id = cl.id;
            if (id == null || id.isEmpty) return false;
            if (qRec.isEmpty) return true;
            final name = (cl.name ?? '').toLowerCase();
            return name.contains(qRec) || id.toLowerCase().contains(qRec);
          }).toList();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InputText(
            labelText: AppLocaleKeys.pushTestSearchRecipients.tr,
            hintText: AppLocaleKeys.commonSearch.tr,
            height: 40,
            fillColor: Colors.white,
            controller: _recipientSearch,
            borderRadius: 8,
            borderColor: Colors.grey.shade300,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              TextButton(
                onPressed: _sending ? null : () => _addMe(c),
                child: Text(AppLocaleKeys.pushTestSelectMe.tr),
              ),
              TextButton(
                onPressed: _sending ? null : () => _selectAllEmployees(c),
                child: Text(AppLocaleKeys.pushTestSelectAllEmployees.tr),
              ),
              TextButton(
                onPressed: _sending ? null : () => _selectAllClients(c),
                child: Text(AppLocaleKeys.pushTestSelectAllClients.tr),
              ),
              TextButton(
                onPressed:
                    _sending
                        ? null
                        : () => setState(() {
                          _empIds.clear();
                          _clientIds.clear();
                        }),
                child: Text(AppLocaleKeys.pushTestClearRecipients.tr),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _recipientSection(
                    title: AppLocaleKeys.pushTestEmployees.tr,
                    child: ListView.builder(
                      itemCount: emps.length,
                      itemBuilder: (context, i) {
                        final e = emps[i];
                        final id = e.id!;
                        return CheckboxListTile(
                          dense: true,
                          value: _empIds.contains(id),
                          onChanged:
                              _sending
                                  ? null
                                  : (v) {
                                    setState(() {
                                      if (v == true) {
                                        _empIds.add(id);
                                      } else {
                                        _empIds.remove(id);
                                      }
                                    });
                                  },
                          title: Text(
                            e.name ?? id,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            e.role,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _recipientSection(
                    title: AppLocaleKeys.pushTestClients.tr,
                    child: ListView.builder(
                      itemCount: cls.length,
                      itemBuilder: (context, i) {
                        final cl = cls[i];
                        final id = cl.id!;
                        return CheckboxListTile(
                          dense: true,
                          value: _clientIds.contains(id),
                          onChanged:
                              _sending
                                  ? null
                                  : (v) {
                                    setState(() {
                                      if (v == true) {
                                        _clientIds.add(id);
                                      } else {
                                        _clientIds.remove(id);
                                      }
                                    });
                                  },
                          title: Text(
                            cl.name ?? id,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    });
  }

  Widget _recipientSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: child,
          ),
        ),
      ],
    );
  }
}
