import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Models/ClientModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/View/Shared/button.dart';
import 'package:point/View/Shared/table_actions_menu_row.dart';

class ClientsMobileScreen extends StatelessWidget {
  final List<ClientModel> clients;
  final VoidCallback onAdd;
  final ValueChanged<ClientModel> onEdit;
  final ValueChanged<ClientModel> onDelete;
  final ValueChanged<ClientModel> onToggleStatus;

  const ClientsMobileScreen({
    super.key,
    required this.clients,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleStatus,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'clients'.tr,
                  style: TextStyle(
                    color: AppColors.fontColorGrey,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              MainButton(
                width: 126,
                height: 44,
                margin: EdgeInsets.zero,
                borderSize: 28,
                fontColor: Colors.white,
                backgroundColor: AppColors.primary,
                widget: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'addnewclient'.tr,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.add_circle_outline_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
                onPressed: onAdd,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (clients.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 36),
                child: Text(
                  'history.empty_data'.tr,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.fontColorGrey,
                  ),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: clients.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, index) {
                final client = clients[index];
                final active = client.status == 'active';
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              client.name ?? '',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.fontColorGrey,
                              ),
                            ),
                          ),
                          PopupMenuButton<int>(
                            tooltip: 'tasks.options_tooltip'.tr,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            color: Colors.white,
                            elevation: 4,
                            itemBuilder:
                                (context) => [
                                  PopupMenuItem(
                                    value: 0,
                                    child: tableActionsMenuRow(
                                      label: 'edit'.tr,
                                      icon: Icons.edit_outlined,
                                      iconColor: AppColors.success,
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 1,
                                    child: tableActionsMenuRow(
                                      label: 'delete'.tr,
                                      icon: Icons.delete_outline,
                                      iconColor: AppColors.destructive,
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 2,
                                    child: tableActionsMenuRow(
                                      label:
                                          active
                                              ? 'common.disable'.tr
                                              : 'common.enable'.tr,
                                      icon:
                                          active
                                              ? Icons.pause_circle_outline
                                              : Icons.play_circle_outline,
                                      iconColor:
                                          active
                                              ? AppColors.caution
                                              : AppColors.success,
                                    ),
                                  ),
                                ],
                            onSelected: (value) {
                              if (value == 0) {
                                onEdit(client);
                              } else if (value == 1) {
                                onDelete(client);
                              } else if (value == 2) {
                                onToggleStatus(client);
                              }
                            },
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.more_vert,
                                color: AppColors.primaryfontColor,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        client.description ?? '--',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.fontColorGrey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _mobileInfoChip(
                            '${'startat'.tr}: ${FunHelper.formatdate(client.startAt) ?? ''}',
                          ),
                          _mobileInfoChip(
                            '${'endat'.tr}: ${FunHelper.formatdate(client.endAt) ?? ''}',
                          ),
                          _mobileInfoChip(
                            active ? 'common.enable'.tr : 'common.disable'.tr,
                            backgroundColor:
                                active
                                    ? Colors.green.shade50
                                    : Colors.orange.shade50,
                            textColor:
                                active
                                    ? Colors.green.shade700
                                    : Colors.orange.shade700,
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _mobileInfoChip(
    String text, {
    Color? backgroundColor,
    Color? textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: textColor ?? AppColors.fontColorGrey,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
