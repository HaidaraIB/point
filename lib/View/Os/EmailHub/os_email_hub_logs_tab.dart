import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/OsEmailHubController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsEmailLogModel.dart';
import 'package:point/Models/Os/os_email_enums.dart';
import 'package:point/Utils/OsPermissions.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/EmailHub/OsEmailHubPage.dart';
import 'package:point/View/Os/EmailHub/os_email_hub_form_widgets.dart';
import 'package:point/View/Os/EmailHub/os_email_hub_helpers.dart';
import 'package:point/View/Os/EmailHub/os_email_hub_previews.dart';
import 'package:point/View/Shared/app_data_table.dart';

class OsEmailHubLogsTab extends StatelessWidget {
  const OsEmailHubLogsTab({super.key, required this.hub});

  final OsEmailHubController hub;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    return Obx(() {
      final items = hub.filteredLogs;
      final activeFilter = hub.logsCategoryFilter.value;
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.cardSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: osEmailHubTextField(
                        context,
                        label: AppLocaleKeys.osEmailHubLogsSearch.tr,
                        showLabel: false,
                        hintText: AppLocaleKeys.osEmailHubLogsSearch.tr,
                        prefixIcon: const Icon(Icons.search, size: 20),
                        value: hub.logsSearch.value,
                        onChanged: (v) => hub.logsSearch.value = v,
                      ),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      tooltip: AppLocaleKeys.osEmailHubLogsFilter.tr,
                      onSelected: (v) => hub.logsCategoryFilter.value = v,
                      itemBuilder: (ctx) => [
                        _filterItem(OsEmailCategory.invoice),
                        _filterItem(OsEmailCategory.quotation),
                        _filterItem(OsEmailCategory.payslip),
                        _filterItem(OsEmailCategory.appreciation),
                        _filterItem(OsEmailCategory.penalty),
                        _filterItem(OsEmailCategory.contract),
                        PopupMenuItem(
                          value: 'ALL',
                          child: Text(AppLocaleKeys.osEmailHubLogsFilterAll.tr),
                        ),
                      ],
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.panelTint,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: theme.border),
                        ),
                        child: Icon(Icons.filter_list, color: theme.accentText),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: AppLocaleKeys.osEmailHubLogsClearTitle.tr,
                      onPressed: () => confirmClearEmailLogs(hub),
                      icon: Icon(
                        Icons.delete_sweep_outlined,
                        color: theme.accentText,
                      ),
                    ),
                  ],
                ),
                if (activeFilter != 'ALL') ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: InputChip(
                      label: Text(
                        AppLocaleKeys.osEmailHubLogsFilterActive.trParams({
                          'type': osEmailCategoryLabel(activeFilter),
                        }),
                      ),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () => hub.logsCategoryFilter.value = 'ALL',
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  AppLocaleKeys.osEmailHubLogsEmpty.tr,
                  style: TextStyle(color: theme.secondaryText),
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 720) {
                  return Column(
                    children: items
                        .map((log) => _logCard(context, log))
                        .toList(),
                  );
                }
                final tableWidth = constraints.maxWidth < 1000
                    ? 1000.0
                    : constraints.maxWidth;
                return Container(
                  decoration: BoxDecoration(
                    color: theme.cardSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.border),
                  ),
                  child: AppDataTable(
                    minWidth: tableWidth,
                    showCheckboxColumn: false,
                    columnSpacing: 20,
                    horizontalMargin: 16,
                    dataRowMinHeight: 72,
                    dataRowMaxHeight: 88,
                    columns: [
                      appDataColumn(
                        context,
                        AppLocaleKeys.osEmailHubLogsColType.tr,
                      ),
                      appDataColumn(
                        context,
                        AppLocaleKeys.osEmailHubLogsColRecipient.tr,
                      ),
                      appDataColumn(
                        context,
                        AppLocaleKeys.osEmailHubLogsColSubject.tr,
                      ),
                      appDataColumn(
                        context,
                        AppLocaleKeys.osEmailHubLogsColDate.tr,
                      ),
                      appDataColumn(
                        context,
                        AppLocaleKeys.osEmailHubLogsColStatus.tr,
                      ),
                      appDataColumn(
                        context,
                        AppLocaleKeys.osCommonActions.tr,
                        width: 120,
                      ),
                    ],
                    rows: items.map((log) => _logRow(context, log)).toList(),
                  ),
                );
              },
            ),
        ],
      );
    });
  }

  PopupMenuItem<String> _filterItem(String type) {
    return PopupMenuItem(
      value: type,
      child: Text(osEmailCategoryLabel(type)),
    );
  }

  Widget _logCard(BuildContext context, OsEmailLogModel log) {
    final theme = context.appTheme;
    final failed = log.status == OsEmailLogStatus.failed;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: theme.cardSurface,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: theme.border),
        ),
        onTap: () => showEmailLogPreview(context, log, hub: hub),
        title: Text(
          log.subject,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: theme.primaryText,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${log.recipientName} • ${osEmailCategoryLabel(log.type)}',
              style: TextStyle(color: theme.secondaryText, fontSize: 12),
            ),
            Text(
              formatEmailLogDate(log.sentAt),
              style: TextStyle(color: theme.mutedText, fontSize: 11),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              failed ? Icons.error_outline : Icons.check_circle_outline,
              color: failed ? Colors.redAccent : Colors.green,
              size: 18,
            ),
            if (OsPermissions.canDeleteCurrentOsRecords)
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  color: theme.mutedText,
                  size: 20,
                ),
                onPressed: () => confirmDeleteEmailLog(
                  context: context,
                  hub: hub,
                  log: log,
                ),
              ),
          ],
        ),
        ),
      ),
    );
  }

  DataRow _logRow(BuildContext context, OsEmailLogModel log) {
    final theme = context.appTheme;
    final failed = log.status == OsEmailLogStatus.failed;
    return DataRow(
      cells: [
        appDataCell(
          Text(
            osEmailCategoryLabel(log.type),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: theme.primaryText,
            ),
          ),
        ),
        appDataCell(
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                log.recipientName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: theme.primaryText,
                ),
              ),
              Text(
                log.recipientEmail,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: theme.mutedText),
              ),
            ],
          ),
        ),
        appDataCell(
          Text(
            log.subject,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.primaryText),
          ),
        ),
        appDataCell(
          Text(
            formatEmailLogDate(log.sentAt),
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.secondaryText),
          ),
        ),
        appDataCell(
          Text(
            failed
                ? AppLocaleKeys.osEmailHubLogsStatusFailed.tr
                : AppLocaleKeys.osEmailHubLogsStatusSent.tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: failed ? Colors.redAccent : Colors.green.shade700,
            ),
          ),
        ),
        appDataCell(
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: AppLocaleKeys.osEmailHubLogsDetailTitle.tr,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                icon: Icon(Icons.visibility_outlined, color: theme.accentText),
                onPressed: () => showEmailLogPreview(context, log, hub: hub),
              ),
              if (OsPermissions.canDeleteCurrentOsRecords)
                IconButton(
                  tooltip: AppLocaleKeys.osCommonDelete.tr,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  icon: Icon(Icons.delete_outline, color: theme.mutedText),
                  onPressed: () => confirmDeleteEmailLog(
                    context: context,
                    hub: hub,
                    log: log,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
