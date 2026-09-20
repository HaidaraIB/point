import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/OsCrmController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/ClientModel.dart';
import 'package:point/Models/Os/os_crm_enums.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/Crm/os_crm_labels.dart';
import 'package:point/View/Os/os_finance_format.dart';
import 'package:point/View/Shared/responsive.dart';

/// Mobile-friendly stage picker (replaces broken RTL drag on narrow boards).
Future<void> showOsCrmMoveStageSheet(
  BuildContext context, {
  required String currentStage,
  required ValueChanged<String> onPick,
}) async {
  final theme = context.appTheme;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(
                AppLocaleKeys.osCrmChangeStage.tr,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: theme.primaryText,
                ),
              ),
            ),
            for (final s in OsCrmStage.ordered)
              ListTile(
                leading: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: osCrmStageColor(s),
                    shape: BoxShape.circle,
                  ),
                ),
                title: Text(osCrmStageLabel(s)),
                trailing: s == currentStage
                    ? Icon(Icons.check_rounded, color: theme.accentText)
                    : null,
                onTap: () {
                  Navigator.pop(ctx);
                  if (s != currentStage) onPick(s);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

class CrmDragPayload {
  const CrmDragPayload({required this.client, required this.fromStage});

  final ClientModel client;
  final String fromStage;
}

/// Kanban pipeline with drag-and-drop between stage columns.
class OsCrmKanbanView extends StatefulWidget {
  const OsCrmKanbanView({
    super.key,
    required this.clients,
    required this.crm,
    required this.onTap,
    required this.onAdd,
    required this.onChangeStage,
  });

  final List<ClientModel> clients;
  final OsCrmController crm;
  final ValueChanged<String> onTap;
  final ValueChanged<String> onAdd;
  final Future<void> Function(ClientModel client, String stage) onChangeStage;

  static const _desktopColumnWidth = 272.0;
  static const _columnGap = 12.0;
  static const _horizontalPadding = 16.0;
  static const _columnPeek = 52.0;

  @override
  State<OsCrmKanbanView> createState() => _OsCrmKanbanViewState();
}

class _OsCrmKanbanViewState extends State<OsCrmKanbanView> {
  final _horizontalController = ScrollController();
  final _boardKey = GlobalKey();

  Timer? _autoScrollTimer;
  ScrollHoldController? _scrollHold;
  var _isDragging = false;
  var _dragPointerX = 0.0;
  var _hasDragPointer = false;

  static const _edgeZone = 72.0;
  static const _maxScrollPerTick = 20.0;
  static const _autoScrollInterval = Duration(milliseconds: 16);

  @override
  void dispose() {
    _releaseScrollHold();
    _stopAutoScroll();
    _horizontalController.dispose();
    super.dispose();
  }

  void _releaseScrollHold() {
    _scrollHold?.cancel();
    _scrollHold = null;
  }

  bool get _isMobile =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  void _onDragStarted() {
    // Do not setState here — rebuilding the board cancels LongPressDraggable.
    _isDragging = true;
    _hasDragPointer = false;
    _stopAutoScroll();
    if (_horizontalController.hasClients) {
      _scrollHold = _horizontalController.position.hold(() {});
    }
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _dragPointerX = details.globalPosition.dx;
    _hasDragPointer = true;
    if (_autoScrollTimer == null) {
      _startAutoScroll();
    }
  }

  void _onDragEnded() {
    _isDragging = false;
    _hasDragPointer = false;
    _releaseScrollHold();
    _stopAutoScroll();
  }

  void _startAutoScroll() {
    if (_isMobile) return;
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(_autoScrollInterval, (_) {
      _tickAutoScroll();
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  void _tickAutoScroll() {
    if (_isMobile ||
        !_isDragging ||
        !_hasDragPointer ||
        !_horizontalController.hasClients) {
      return;
    }

    final box = _boardKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    final topLeft = box.localToGlobal(Offset.zero);
    final rect = topLeft & box.size;
    final leftDist = _dragPointerX - rect.left;
    final rightDist = rect.right - _dragPointerX;

    double delta = 0;
    if (leftDist >= 0 && leftDist < _edgeZone) {
      final intensity = 1 - (leftDist / _edgeZone).clamp(0.0, 1.0);
      delta = -_maxScrollPerTick * intensity;
    } else if (rightDist >= 0 && rightDist < _edgeZone) {
      final intensity = 1 - (rightDist / _edgeZone).clamp(0.0, 1.0);
      delta = _maxScrollPerTick * intensity;
    }

    if (delta == 0) return;

    final isRtl = Directionality.of(context) == TextDirection.rtl;
    if (isRtl) delta = -delta;

    final position = _horizontalController.position;
    final atStart = position.pixels <= position.minScrollExtent + 0.5;
    final atEnd = position.pixels >= position.maxScrollExtent - 0.5;
    if ((delta < 0 && atStart) || (delta > 0 && atEnd)) {
      return;
    }

    final target = (position.pixels + delta)
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    if (target != position.pixels) {
      _horizontalController.jumpTo(target);
    }
  }

  static double _columnWidthFor(BuildContext context, double maxWidth) {
    if (!Responsive.isMobile(context)) {
      return OsCrmKanbanView._desktopColumnWidth;
    }
    final w = maxWidth -
        OsCrmKanbanView._horizontalPadding -
        OsCrmKanbanView._columnPeek;
    return w.clamp(220.0, 360.0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columnWidth = _columnWidthFor(context, constraints.maxWidth);
        final snap = Responsive.isMobile(context);
        final snapExtent = columnWidth + OsCrmKanbanView._columnGap;

        final board = KeyedSubtree(
          key: _boardKey,
          child: ListView.separated(
            controller: _horizontalController,
            primary: false,
            scrollDirection: Axis.horizontal,
            physics: snap
                ? _KanbanSnapScrollPhysics(
                    itemExtent: snapExtent,
                    parent: const BouncingScrollPhysics(),
                  )
                : const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              OsCrmKanbanView._horizontalPadding,
              0,
              OsCrmKanbanView._horizontalPadding,
              16,
            ),
            itemCount: OsCrmStage.ordered.length,
            separatorBuilder: (_, __) =>
                const SizedBox(width: OsCrmKanbanView._columnGap),
            itemBuilder: (context, index) {
              final stage = OsCrmStage.ordered[index];
              return SizedBox(
                width: columnWidth,
                child: _StageColumn(
                  stage: stage,
                  clients: widget.clients
                      .where((c) => widget.crm.effectiveStage(c) == stage)
                      .toList(),
                  crm: widget.crm,
                  cardWidth: columnWidth,
                  onTap: widget.onTap,
                  onAdd: widget.onAdd,
                  onChangeStage: widget.onChangeStage,
                  onDragStarted: _onDragStarted,
                  onDragUpdate: _onDragUpdate,
                  onDragEnded: _onDragEnded,
                ),
              );
            },
          ),
        );

        if (_isMobile) return board;
        return Scrollbar(
          controller: _horizontalController,
          thumbVisibility: true,
          scrollbarOrientation: ScrollbarOrientation.bottom,
          child: board,
        );
      },
    );
  }
}

/// Snaps horizontal kanban scroll to column boundaries on mobile.
class _KanbanSnapScrollPhysics extends ScrollPhysics {
  const _KanbanSnapScrollPhysics({
    required this.itemExtent,
    super.parent,
  });

  final double itemExtent;

  @override
  _KanbanSnapScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _KanbanSnapScrollPhysics(
      itemExtent: itemExtent,
      parent: buildParent(ancestor),
    );
  }

  double _targetPixels(ScrollMetrics position, double velocity) {
    if (itemExtent <= 0) return position.pixels;
    final tol = toleranceFor(position);
    var page = position.pixels / itemExtent;
    if (velocity.abs() >= tol.velocity) {
      page = velocity > 0 ? page.ceilToDouble() : page.floorToDouble();
    } else {
      page = page.roundToDouble();
    }
    final maxPage = (position.maxScrollExtent / itemExtent).floorToDouble();
    page = page.clamp(0.0, maxPage);
    return page * itemExtent;
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    final tol = toleranceFor(position);
    final target = _targetPixels(position, velocity);
    if ((target - position.pixels).abs() < tol.distance &&
        velocity.abs() < tol.velocity) {
      return null;
    }
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      target,
      velocity,
      tolerance: tol,
    );
  }
}

class _StageColumn extends StatelessWidget {
  const _StageColumn({
    required this.stage,
    required this.clients,
    required this.crm,
    required this.cardWidth,
    required this.onTap,
    required this.onAdd,
    required this.onChangeStage,
    required this.onDragStarted,
    required this.onDragUpdate,
    required this.onDragEnded,
  });

  final String stage;
  final List<ClientModel> clients;
  final OsCrmController crm;
  final double cardWidth;
  final ValueChanged<String> onTap;
  final ValueChanged<String> onAdd;
  final Future<void> Function(ClientModel client, String stage) onChangeStage;
  final VoidCallback onDragStarted;
  final ValueChanged<DragUpdateDetails> onDragUpdate;
  final VoidCallback onDragEnded;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final color = osCrmStageColor(stage);

    return DragTarget<CrmDragPayload>(
      onWillAcceptWithDetails: (d) => d.data.fromStage != stage,
      onAcceptWithDetails: (d) => onChangeStage(d.data.client, stage),
      builder: (context, candidate, rejected) {
        final hovering = candidate.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: hovering
                ? color.withValues(alpha: 0.08)
                : theme.inputFill.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hovering ? color : theme.border,
              width: hovering ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ColumnHeader(
                stage: stage,
                count: clients.length,
                color: color,
                onAdd: () => onAdd(stage),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: clients.isEmpty
                    ? _EmptyColumn(hovering: hovering, color: color)
                    : ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: clients.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final client = clients[i];
                          return _DraggableCrmCard(
                            client: client,
                            crm: crm,
                            stage: stage,
                            feedbackWidth: cardWidth - 20,
                            onTap: () => onTap(client.id!),
                            onChangeStage: (s) => onChangeStage(client, s),
                            onDragStarted: onDragStarted,
                            onDragUpdate: onDragUpdate,
                            onDragEnded: onDragEnded,
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ColumnHeader extends StatelessWidget {
  const _ColumnHeader({
    required this.stage,
    required this.count,
    required this.color,
    required this.onAdd,
  });

  final String stage;
  final int count;
  final Color color;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            osCrmStageLabel(stage),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: theme.primaryText,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          tooltip: AppLocaleKeys.osCrmAdd.tr,
          onPressed: onAdd,
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 28, height: 28),
          style: IconButton.styleFrom(
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: EdgeInsets.zero,
            minimumSize: const Size(28, 28),
            visualDensity: VisualDensity.compact,
          ),
          icon: Icon(Icons.add_rounded, size: 18, color: color),
        ),
      ],
    );
  }
}

class _EmptyColumn extends StatelessWidget {
  const _EmptyColumn({required this.hovering, required this.color});

  final bool hovering;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hovering
                ? color.withValues(alpha: 0.5)
                : theme.border.withValues(alpha: 0.7),
            style: hovering ? BorderStyle.solid : BorderStyle.none,
          ),
        ),
        child: Text(
          AppLocaleKeys.osCrmKanbanEmpty.tr,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: theme.mutedText),
        ),
      ),
    );
  }
}

class _DraggableCrmCard extends StatelessWidget {
  const _DraggableCrmCard({
    required this.client,
    required this.crm,
    required this.stage,
    required this.feedbackWidth,
    required this.onTap,
    required this.onChangeStage,
    required this.onDragStarted,
    required this.onDragUpdate,
    required this.onDragEnded,
  });

  final ClientModel client;
  final OsCrmController crm;
  final String stage;
  final double feedbackWidth;
  final VoidCallback onTap;
  final ValueChanged<String> onChangeStage;
  final VoidCallback onDragStarted;
  final ValueChanged<DragUpdateDetails> onDragUpdate;
  final VoidCallback onDragEnded;

  @override
  Widget build(BuildContext context) {
    final card = _CrmCardBody(
      client: client,
      crm: crm,
      stage: stage,
      onTap: onTap,
      onChangeStage: onChangeStage,
      showDragHandle: !Responsive.isMobile(context),
      onLongPress: Responsive.isMobile(context)
          ? () => showOsCrmMoveStageSheet(
                context,
                currentStage: stage,
                onPick: onChangeStage,
              )
          : null,
    );

    if (Responsive.isMobile(context)) {
      return card;
    }

    final payload = CrmDragPayload(client: client, fromStage: stage);

    return LongPressDraggable<CrmDragPayload>(
      data: payload,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      rootOverlay: true,
      onDragStarted: onDragStarted,
      onDragUpdate: onDragUpdate,
      onDragEnd: (_) => onDragEnded(),
      onDraggableCanceled: (_, __) => onDragEnded(),
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(14),
        child: Opacity(
          opacity: 0.92,
          child: SizedBox(
            width: feedbackWidth.clamp(200.0, 320.0),
            child: _CrmCardBody(
              client: client,
              crm: crm,
              stage: stage,
              dragging: true,
              showDragHandle: true,
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.35,
        child: _CrmCardBody(
          client: client,
          crm: crm,
          stage: stage,
          showDragHandle: true,
        ),
      ),
      child: card,
    );
  }
}

Future<void> _showStageMenu(
  BuildContext context,
  ValueChanged<String> onSelected,
) async {
  final box = context.findRenderObject() as RenderBox?;
  if (box == null || !box.hasSize) return;
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
  final bottomRight = box.localToGlobal(
    box.size.bottomRight(Offset.zero),
    ancestor: overlay,
  );
  final selected = await showMenu<String>(
    context: context,
    position: RelativeRect.fromRect(
      Rect.fromPoints(topLeft, bottomRight),
      Offset.zero & overlay.size,
    ),
    items: osCrmStagePopupMenuItems(),
  );
  if (selected != null) onSelected(selected);
}

class _CrmCardBody extends StatelessWidget {
  const _CrmCardBody({
    required this.client,
    required this.crm,
    required this.stage,
    this.onTap,
    this.onChangeStage,
    this.onLongPress,
    this.showDragHandle = true,
    this.dragging = false,
  });

  final ClientModel client;
  final OsCrmController crm;
  final String stage;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChangeStage;
  final VoidCallback? onLongPress;
  final bool showDragHandle;
  final bool dragging;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final color = osCrmStageColor(stage);
    final company = crm.displayCompany(client);
    final assignee = (client.assignedTo ?? '').trim();
    final assigneeInitial = assignee.isNotEmpty ? assignee[0] : '?';

    return Material(
      color: theme.cardSurface,
      elevation: dragging ? 0 : 0.5,
      shadowColor: theme.shadowColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: dragging ? null : onTap,
        onLongPress: dragging ? null : onLongPress,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.border),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 3,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: const BorderRadiusDirectional.horizontal(
                      start: Radius.circular(14),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (showDragHandle) ...[
                              Icon(
                                Icons.drag_indicator_rounded,
                                size: 16,
                                color: theme.mutedText.withValues(alpha: 0.7),
                              ),
                              const SizedBox(width: 4),
                            ],
                            Expanded(
                              child: Text(
                                company,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: theme.primaryText,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (onChangeStage != null)
                              IconButton(
                                tooltip: AppLocaleKeys.osCrmChangeStage.tr,
                                onPressed: () => _showStageMenu(
                                  context,
                                  onChangeStage!,
                                ),
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                                constraints: const BoxConstraints.tightFor(
                                  width: 28,
                                  height: 28,
                                ),
                                icon: Icon(
                                  Icons.more_horiz_rounded,
                                  size: 18,
                                  color: theme.mutedText,
                                ),
                              ),
                          ],
                        ),
                        if ((client.name ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Padding(
                            padding: const EdgeInsetsDirectional.only(start: 20),
                            child: Text(
                              client.name!,
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.secondaryText,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 11,
                              backgroundColor:
                                  AppColors.primary.withValues(alpha: 0.12),
                              child: Text(
                                assigneeInitial,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                assignee.isEmpty
                                    ? AppLocaleKeys.osCommonDash.tr
                                    : assignee,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: theme.mutedText,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              OsFinanceFormat.money(client.totalRevenue ?? 0),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: theme.accentText,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact kanban / list toggle for the CRM header.
class OsCrmViewToggle extends StatelessWidget {
  const OsCrmViewToggle({
    super.key,
    required this.isKanban,
    required this.onKanban,
    required this.onList,
  });

  final bool isKanban;
  final VoidCallback onKanban;
  final VoidCallback onList;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    return Container(
      decoration: BoxDecoration(
        color: theme.inputFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.border),
      ),
      padding: const EdgeInsets.all(3),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stretch = constraints.maxWidth.isFinite;
          final kanban = _ToggleChip(
            selected: isKanban,
            label: AppLocaleKeys.osCrmViewKanban.tr,
            icon: Icons.view_kanban_outlined,
            onTap: onKanban,
          );
          final list = _ToggleChip(
            selected: !isKanban,
            label: AppLocaleKeys.osCrmViewList.tr,
            icon: Icons.list_alt_outlined,
            onTap: onList,
          );
          if (!stretch) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [kanban, list],
            );
          }
          return Row(
            children: [
              Expanded(child: kanban),
              Expanded(child: list),
            ],
          );
        },
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.selected,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    return Material(
      color: selected ? theme.cardSurface : Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? theme.accentText : theme.mutedText,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: selected ? theme.primaryText : theme.mutedText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
