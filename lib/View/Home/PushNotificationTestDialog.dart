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
import 'package:point/firebase_app_options.dart';
import 'package:point/Utils/app_theme_extension.dart';

/// حوار لمسؤولي النظام (admin / supervisor):
/// إرسال تجربة Push: أي [notificationType] إلى أي مزيج من الموظفين والعملاء.
void showPushNotificationTestDialog(BuildContext context) {
  if (!FirebaseAppOptions.isUsingTestFirebaseProject) return;
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return Dialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
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
  bool _useSupabaseTemplateWrapper = false;
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

  /// فهرس الصف في القائمة المصفّاة — يُستخدم كقيمة [RadioListTile] حتى لا يتكرر
  /// نفس [notificationType] في مجموعة واحدة (Flutter 3.32+ يفرض تفرد القيمة المختارة).
  int _selectedIndexIn(List<PushNotificationTestDefinition> types) {
    final i = types.indexWhere(
      (e) => e.notificationType == _selected.notificationType,
    );
    if (i >= 0) return i;
    return 0;
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

    final sample = _sampleCopyForType(_selected.notificationType);
    final title = sample.$1;
    final body = sample.$2;
    final chatTestExtras = _selected.notificationType == 'chat_message'
        ? <String, String>{
            'chatId': 'push_test_chat_${DateTime.now().millisecondsSinceEpoch}',
            'chatTitle': 'Push Test Chat',
            'chatDisplayName': 'Push Test Chat',
            'senderName': 'Push Tester',
            'isGroup': '0',
          }
        : null;

    setState(() => _sending = true);
    try {
      final batchSeenTokens = <String>{};
      final batchSeenEmails = <String>{};
      for (final id in _empIds) {
        await FirestoreServices.sendFcm(
          userId: id,
          title: title,
          body: body,
          notificationType: _selected.notificationType,
          fcmDataExtras: chatTestExtras,
          sendPush: _sendPush,
          sendEmail: _sendEmail,
          useSupabaseTemplateWrapper: _useSupabaseTemplateWrapper,
          batchSeenTokens: batchSeenTokens,
          batchSeenEmails: batchSeenEmails,
          excludeCurrentActor: false,
        );
      }
      for (final id in _clientIds) {
        await FirestoreServices.sendFcmForClient(
          userId: id,
          title: title,
          body: body,
          notificationType: _selected.notificationType,
          fcmDataExtras: chatTestExtras,
          sendPush: _sendPush,
          sendEmail: _sendEmail,
          useSupabaseTemplateWrapper: _useSupabaseTemplateWrapper,
          batchSeenTokens: batchSeenTokens,
          batchSeenEmails: batchSeenEmails,
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

  (String, String) _sampleCopyForType(String notificationType) {
    final params = <String, String>{
      'title': 'مهمة تجريبية',
      'name': 'الموظف',
      'label': 'status_task_completed'.tr,
      'by': 'الموظف',
      'pct': '50',
      'client': 'العميل',
      'platform': 'Instagram',
      'date': '2026-04-27',
      'time': '10:00',
      'ref': 'REF-1001',
      'dept': 'التصميم',
      'type': 'محتوى',
      'supervisor': 'المشرف',
    };

    final prefixByType = <String, String>{
      'chat_message': 'notify.emp.new_comment',
      'chat_unread_digest': 'notify.emp.new_comment',
      'employee_task_assigned': 'notify.emp.assigned',
      'employee_task_due_soon': 'notify.emp.due_soon',
      'employee_task_edit_requested': 'notify.emp.edit_mgmt',
      'employee_task_rejected': 'notify.emp.rejected',
      'employee_task_reopened': 'notify.emp.reopened',
      'employee_task_new_attachments': 'notify.emp.attachments',
      'employee_task_new_comment': 'notify.emp.new_comment',
      'employee_task_status_changed': 'notify.emp.status_changed',
      'employee_task_start_reminder': 'notify.emp.start_reminder',
      'employee_task_stale_update': 'notify.emp.stale_update',
      'employee_task_followup': 'notify.emp.followup',
      'employee_task_overdue': 'notify.emp.overdue',
      'employee_task_due_soon_1h': 'notify.emp.due_soon_1h',
      'employee_task_no_progress_yet': 'notify.emp.no_progress_yet',
      'employee_progress_quarter': 'notify.emp.milestone.on_track',
      'employee_progress_half': 'notify.emp.milestone.halfway',
      'employee_progress_three_quarter': 'notify.emp.milestone.near_end',
      'employee_progress_finished': 'notify.emp.milestone.finished',
      'employee_progress_reminder_0': 'notify.emp.no_progress_yet',
      'employee_progress_reminder_25': 'notify.emp.milestone.on_track',
      'employee_progress_reminder_50': 'notify.emp.milestone.halfway',
      'employee_progress_reminder_75_a': 'notify.emp.milestone.near_end',
      'employee_progress_reminder_75_b': 'notify.emp.milestone.near_end',
      'employee_progress_reminder_100': 'notify.emp.milestone.finished',
      'manager_task_received': 'notify.mgr.received',
      'manager_task_completed': 'notify.mgr.completed',
      'manager_task_edited': 'notify.mgr.edited',
      'manager_task_comment': 'notify.mgr.edited',
      'manager_content_submitted_by_client': 'notify.mgr.content_submitted',
      'manager_task_overdue': 'notify.mgr.overdue',
      'manager_task_progress_updated': 'notify.mgr.progress_updated',
      'manager_task_no_action': 'notify.mgr.no_action',
      'manager_task_progress_stalled': 'notify.mgr.stalled',
      'manager_new_task_department': 'notify.mgr.new_task_dept',
      'manager_client_notes': 'notify.mgr.client_notes',
      'manager_client_approved_content': 'notify.mgr.client_approved',
      'client_content_pending_approval': 'notify.client.pending',
      'client_pending_over_24h': 'notify.client.pending_24h',
      'client_approval_confirmed': 'notify.client.approval_confirmed',
      'client_edits_done': 'notify.client.edits_done',
      'client_content_updated': 'notify.client.updated',
      'client_content_scheduled': 'notify.client.scheduled',
      'publish_content_added': 'notify.publish.added',
      'publish_client_edit_request': 'notify.publish.edit_req',
      'publish_client_approved': 'notify.publish.approved',
      'publish_client_rejected': 'notify.publish.rejected',
      'publish_post_one_hour': 'notify.publish.one_hour',
      'publish_post_not_confirmed_today': 'notify.publish.today_not_confirmed',
      'publish_no_posts_tomorrow': 'notify.publish.no_posts_tomorrow',
      'publish_post_published': 'notify.publish.published',
      'publish_link_added': 'notify.publish.link_added',
      'publish_notes_after_publish': 'notify.publish.notes_after',
      'publish_scheduled_cancelled': 'notify.publish.cancelled',
      'admin_promotion_status_changed': 'notify.admin.promo_changed',
      'admin_content_status_changed': 'notify.admin.status_changed',
      'promotion_new_published_content': 'notify.promo.new_published',
      'broadcast_topic': 'notify.publish.added',
    };

    final prefix = prefixByType[notificationType];
    if (prefix != null) {
      final title = '$prefix.title'.trParams(params);
      final rawBody = '$prefix.body'.trParams(params);
      final body =
          rawBody == '$prefix.body'
              ? '$prefix.action'.trParams(params)
              : rawBody;
      if (title != '$prefix.title') {
        return (title, body == '$prefix.action' ? _genericBody() : body);
      }
    }

    final isArabic = Get.locale?.languageCode.toLowerCase() == 'ar';
    return isArabic
        ? ('إشعار جديد', 'لديك تحديث جديد في النظام.')
        : ('New notification', 'You have a new update in the system.');
  }

  String _genericBody() {
    final isArabic = Get.locale?.languageCode.toLowerCase() == 'ar';
    return isArabic
        ? 'يرجى فتح التطبيق للاطلاع على التفاصيل.'
        : 'Open the app to view details.';
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
                style: TextStyle(fontSize: 12, color: context.appTheme.mutedText),
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
                      style: TextStyle(fontSize: 12, color: context.appTheme.mutedText),
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
        color: context.appTheme.navSurface,
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
                  style: TextStyle(
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _sendPush,
                onChanged:
                    _sending ? null : (v) => setState(() => _sendPush = v ?? true),
                title: Text(
                  AppLocaleKeys.pushTestSendPush.tr,
                  style: TextStyle(fontSize: 13),
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ),
            Expanded(
              child: CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _sendEmail,
                onChanged:
                    _sending
                        ? null
                        : (v) => setState(() {
                          _sendEmail = v ?? false;
                          if (!_sendEmail) {
                            _useSupabaseTemplateWrapper = false;
                          }
                        }),
                title: Text(
                  AppLocaleKeys.pushTestSendEmail.tr,
                  style: TextStyle(fontSize: 13),
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ),
          ],
        ),
        if (_sendEmail)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _useSupabaseTemplateWrapper,
            onChanged:
                _sending
                    ? null
                    : (v) => setState(
                      () => _useSupabaseTemplateWrapper = v ?? false,
                    ),
            title: Text(
              AppLocaleKeys.pushTestUseSupabaseWrapper.tr,
              style: TextStyle(fontSize: 13),
            ),
            controlAffinity: ListTileControlAffinity.leading,
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
              backgroundColor: AppColors.primary,
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
                      style: TextStyle(
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
          controller: _typeFilter,
          borderRadius: 8,
        ),
        const SizedBox(height: 8),
        Text(
          AppLocaleKeys.pushTestSelectType.tr,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
                  : RadioGroup<int>(
                    groupValue: _selectedIndexIn(types),
                    onChanged: (v) {
                      if (_sending || v == null) return;
                      if (v < 0 || v >= types.length) return;
                      setState(() => _selected = types[v]);
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
                        return RadioListTile<int>(
                          dense: true,
                          enabled: !_sending,
                          value: i,
                          title: Text(
                            def.notificationType,
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                          subtitle: Text(
                            def.categoryKey.tr,
                            style: TextStyle(
                              fontSize: 11,
                              color: context.appTheme.mutedText,
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
            controller: _recipientSearch,
            borderRadius: 8,
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
                            color: context.appTheme.mutedText,
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
        Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
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
          controller: _typeFilter,
          borderRadius: 8,
        ),
        const SizedBox(height: 8),
        Text(
          AppLocaleKeys.pushTestSelectType.tr,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
                    : RadioGroup<int>(
              groupValue: _selectedIndexIn(types),
              onChanged: (v) {
                if (_sending || v == null) return;
                if (v < 0 || v >= types.length) return;
                setState(() => _selected = types[v]);
              },
              child: ListView.builder(
                itemCount: types.length,
                itemBuilder: (context, i) {
                  final def = types[i];
                  final sel =
                      def.notificationType == _selected.notificationType;
                  return RadioListTile<int>(
                    dense: true,
                    enabled: !_sending,
                    value: i,
                    title: Text(
                      def.notificationType,
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                    subtitle: Text(
                      def.categoryKey.tr,
                      style: TextStyle(
                        fontSize: 11,
                        color: context.appTheme.mutedText,
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
            controller: _recipientSearch,
            borderRadius: 8,
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
                              color: context.appTheme.mutedText,
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
        Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
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
