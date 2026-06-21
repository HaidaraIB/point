import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:point/Services/chat_mark_read_scheduler.dart';
import 'package:point/Services/chat_scroll_persistence.dart';
import 'package:point/Services/firestore/firestore_chat_api.dart';
import 'package:point/Services/firestore/firestore_query_limits.dart';

import 'package:point/View/Chats/chat_scroll_to_latest_fab.dart';

import 'package:point/View/Chats/chat_pinned_messages_bar.dart';
import 'package:point/View/Chats/chat_ui_helpers.dart';

import 'package:scroll_to_index/scroll_to_index.dart';



typedef ChatMessageTileBuilder = Widget Function(

  BuildContext context,

  QueryDocumentSnapshot<Map<String, dynamic>> doc,

  int index,

);



class ChatMessageListPanelController {

  AutoScrollController? _scrollController;

  Object? _scrollOwner;

  ChatScrollSnapshot? Function()? _scrollSnapshotProvider;

  List<QueryDocumentSnapshot<Map<String, dynamic>>> orderedDocs = const [];

  /// Latest tile builder from the parent; read by the scroll list without
  /// forcing a list rebuild when the parent setStates (composer, reply, etc.).
  ChatMessageTileBuilder? tileBuilder;

  Future<void> Function(String messageId)? ensureMessageVisible;

  AutoScrollController? get scrollController => _scrollController;

  ChatScrollSnapshot? get currentScrollSnapshot =>
      _scrollSnapshotProvider?.call();

  void _attach({
    required Object owner,
    required AutoScrollController scrollController,
    required ChatScrollSnapshot? Function() scrollSnapshotProvider,
  }) {
    _scrollOwner = owner;
    _scrollController = scrollController;
    _scrollSnapshotProvider = scrollSnapshotProvider;
  }

  void _detach({required Object owner}) {
    if (!identical(_scrollOwner, owner)) return;
    _scrollOwner = null;
    _scrollController = null;
    _scrollSnapshotProvider = null;
    orderedDocs = const [];
    tileBuilder = null;
    ensureMessageVisible = null;
  }



  void scrollToMessageId(String messageId) {
    unawaited(_scrollToMessageId(messageId));
  }

  Future<void> _scrollToMessageId(String messageId) async {
    await ensureMessageVisible?.call(messageId);

    final idx = orderedDocs.indexWhere((d) => d.id == messageId);

    if (idx < 0 || _scrollController == null) return;

    scheduleScrollChatToMessageIndex(

      controller: _scrollController!,

      index: idx,

      mounted: () => _scrollController != null,

    );
  }



  void scrollToLatest() {

    if (_scrollController == null) return;

    scheduleScrollChatToLatest(

      controller: _scrollController!,

      mounted: () => _scrollController != null,

    );

  }

}



int chatMessageDisplayFingerprint(

  Map<String, dynamic> data, {

  String? currentUserId,

}) {

  return Object.hash(

    data['text'],

    currentUserId != null && data['senderId'] == currentUserId

        ? data['isRead']

        : null,

    data['deleted'],

    data['attachmentUrl'],

    data['messageType'],

    data['fileName'],

    data['isPinned'],

    data['senderName'],

    data['replyPreview'],

    data['replyImageUrl'],

    data['replyVideoUrl'],

    data['editedAt'],

    data['replyToMessageId'],

    _timestampFingerprint(data['timestamp']),

  );

}

Object? _timestampFingerprint(dynamic timestamp) {
  if (timestamp == null) return null;
  if (timestamp is Timestamp) return timestamp.seconds;
  return timestamp.toString();
}



bool _docsNeedListRebuild(

  List<QueryDocumentSnapshot<Map<String, dynamic>>> prev,

  List<QueryDocumentSnapshot<Map<String, dynamic>>> next,

  String currentUserId,

) {

  if (prev.length != next.length) return true;

  for (var i = 0; i < next.length; i++) {

    if (prev[i].id != next[i].id) return true;

    if (chatMessageDisplayFingerprint(

          prev[i].data(),

          currentUserId: currentUserId,

        ) !=

        chatMessageDisplayFingerprint(

          next[i].data(),

          currentUserId: currentUserId,

        )) {

      return true;

    }

  }

  return false;

}






/// Keeps the message list alive when the parent rebuilds (sidebar, composer, etc.).

class ChatMessagesViewport extends StatefulWidget {

  final String chatId;

  final Widget child;



  const ChatMessagesViewport({

    super.key,

    required this.chatId,

    required this.child,

  });



  @override

  State<ChatMessagesViewport> createState() => _ChatMessagesViewportState();

}



class _ChatMessagesViewportState extends State<ChatMessagesViewport>

    with AutomaticKeepAliveClientMixin {

  @override

  bool get wantKeepAlive => true;



  @override

  Widget build(BuildContext context) {

    super.build(context);

    return KeyedSubtree(

      key: ValueKey('chat_viewport_${widget.chatId}'),

      child: widget.child,

    );

  }

}



/// Host that keeps a stable [ChatMessageListPanel] instance across parent
/// setStates (composer, reply draft, emoji picker). Only remounts when chat
/// identity or stream changes; tile content updates via [panelController.tileBuilder].
class ChatMessageListHost extends StatefulWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final String chatId;
  final String currentUserId;
  final int listEpoch;
  final ChatMessageListPanelController panelController;
  final ChatScrollSnapshot? persistedScroll;
  final bool usePersistedScroll;
  final EdgeInsets padding;
  final Widget loadingWidget;
  final Widget emptyWidget;
  final ChatMessageTileBuilder itemBuilder;
  final void Function(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs)?
  onDocsChanged;
  final void Function(ChatScrollSnapshot snapshot)? onScrollSnapshotChanged;
  final Widget Function(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> pinnedDocs,
  )?
  pinnedBannerBuilder;

  const ChatMessageListHost({
    super.key,
    required this.stream,
    required this.chatId,
    required this.currentUserId,
    required this.listEpoch,
    required this.panelController,
    this.persistedScroll,
    this.usePersistedScroll = true,
    this.padding = const EdgeInsets.all(16),
    required this.loadingWidget,
    required this.emptyWidget,
    required this.itemBuilder,
    this.onDocsChanged,
    this.onScrollSnapshotChanged,
    this.pinnedBannerBuilder,
  });

  @override
  State<ChatMessageListHost> createState() => _ChatMessageListHostState();
}

class _ChatMessageListHostState extends State<ChatMessageListHost> {
  ChatMessageListPanel? _panel;
  String? _panelChatId;
  int _panelEpoch = -1;
  Object? _panelStream;

  @override
  void didUpdateWidget(ChatMessageListHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.panelController.tileBuilder = widget.itemBuilder;
    if (_needsNewPanel(oldWidget)) {
      _panel = null;
    }
  }

  bool _needsNewPanel([ChatMessageListHost? old]) {
    return _panel == null ||
        _panelChatId != widget.chatId ||
        _panelEpoch != widget.listEpoch ||
        !identical(_panelStream, widget.stream);
  }

  ChatMessageListPanel _buildPanel() {
    _panelChatId = widget.chatId;
    _panelEpoch = widget.listEpoch;
    _panelStream = widget.stream;
    return ChatMessageListPanel(
      stream: widget.stream,
      chatId: widget.chatId,
      currentUserId: widget.currentUserId,
      listEpoch: widget.listEpoch,
      panelController: widget.panelController,
      persistedScroll: widget.persistedScroll,
      usePersistedScroll: widget.usePersistedScroll,
      padding: widget.padding,
      loadingWidget: widget.loadingWidget,
      emptyWidget: widget.emptyWidget,
      itemBuilder: widget.itemBuilder,
      onDocsChanged: widget.onDocsChanged,
      onScrollSnapshotChanged: widget.onScrollSnapshotChanged,
      pinnedBannerBuilder: widget.pinnedBannerBuilder,
    );
  }

  @override
  Widget build(BuildContext context) {
    widget.panelController.tileBuilder = widget.itemBuilder;
    if (_needsNewPanel()) {
      _panel = _buildPanel();
    }
    return _panel!;
  }
}

/// Stable reverse chat message list backed by [ListView] + [AutoScrollController].

class ChatMessageListPanel extends StatefulWidget {

  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;

  final String chatId;

  final String currentUserId;

  final int listEpoch;

  final ChatMessageListPanelController panelController;

  final ChatScrollSnapshot? persistedScroll;

  final bool usePersistedScroll;

  final EdgeInsets padding;

  final Widget loadingWidget;

  final Widget emptyWidget;

  final ChatMessageTileBuilder itemBuilder;

  final void Function(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs)?

  onDocsChanged;

  final void Function(ChatScrollSnapshot snapshot)? onScrollSnapshotChanged;

  final Widget Function(

    BuildContext context,

    List<QueryDocumentSnapshot<Map<String, dynamic>>> pinnedDocs,

  )?

  pinnedBannerBuilder;



  const ChatMessageListPanel({

    super.key,

    required this.stream,

    required this.chatId,

    required this.currentUserId,

    required this.listEpoch,

    required this.panelController,

    this.persistedScroll,

    this.usePersistedScroll = true,

    this.padding = const EdgeInsets.all(16),

    required this.loadingWidget,

    required this.emptyWidget,

    required this.itemBuilder,

    this.onDocsChanged,

    this.onScrollSnapshotChanged,

    this.pinnedBannerBuilder,

  });



  @override

  State<ChatMessageListPanel> createState() => _ChatMessageListPanelState();

}



class _ChatMessageListPanelState extends State<ChatMessageListPanel> {

  late final AutoScrollController _scrollController = AutoScrollController(

    axis: Axis.vertical,

    suggestedRowHeight: kChatEstimatedRowHeight,

  );



  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _pinnedSubscription;

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _liveDocs = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _olderDocs = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _pinnedDocs = [];
  bool _hasMoreOlder = true;
  bool _loadingOlder = false;

  bool _waitingForFirstSnapshot = true;



  final ValueNotifier<bool> _fabVisible = ValueNotifier(false);

  final ValueNotifier<int> _fabUnread = ValueNotifier(0);



  ({int index, double alignment})? _openScroll;

  bool _initialScrollApplied = false;
  bool _initialScrollComplete = false;
  bool _isRestoringScroll = false;

  int _listEpochApplied = -1;



  Timer? _persistDebounce;

  Timer? _fabThrottle;



  @override
  void initState() {
    super.initState();
    _attachPanelController();
    _scrollController.addListener(_onScrollOffset);
    _bindStream(widget.stream);
    _bindPinnedStream(widget.chatId);
  }

  void _attachPanelController() {
    widget.panelController._attach(
      owner: this,
      scrollController: _scrollController,
      scrollSnapshotProvider: _currentScrollSnapshot,
    );
    widget.panelController.ensureMessageVisible = _ensureMessageVisible;
  }

  void _scrollToLatest() {
    scheduleScrollChatToLatest(
      controller: _scrollController,
      mounted: () => mounted,
    );
  }

  @override
  void didUpdateWidget(ChatMessageListPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _attachPanelController();
    widget.panelController.tileBuilder = widget.itemBuilder;

    if (oldWidget.stream != widget.stream) {
      _bindStream(widget.stream);
      _resetScrollGate();
    }

    if (oldWidget.chatId != widget.chatId) {
      _bindPinnedStream(widget.chatId);
    }

    if (oldWidget.listEpoch != widget.listEpoch) {
      _openScroll = null;
      _resetScrollGate();
    }
  }

  void _resetScrollGate() {
    _initialScrollApplied = false;
    _initialScrollComplete = false;
    _isRestoringScroll = false;
    _listEpochApplied = -1;
    ChatScrollInteraction.reset();
    ChatMarkReadScheduler.cancelForChat(widget.chatId);
  }

  void _scheduleMarkReadIfAllowed() {
    if (!_initialScrollComplete || _isRestoringScroll || _docs.isEmpty) {
      return;
    }
    if (!chatReverseListShowsLatestFromScroll(_scrollController)) {
      return;
    }
    ChatMarkReadScheduler.scheduleFromSnapshot(
      chatId: widget.chatId,
      viewerUserId: widget.currentUserId,
      docs: _docs,
      scrollController: _scrollController,
    );
  }



  ChatScrollSnapshot? _currentScrollSnapshot() {

    return chatScrollSnapshotFromScrollController(

      _scrollController,

      _docs.length,

    );

  }



  void _bindStream(Stream<QuerySnapshot<Map<String, dynamic>>> stream) {

    _subscription?.cancel();

    _liveDocs = [];
    _olderDocs = [];
    _hasMoreOlder = true;
    _loadingOlder = false;
    _waitingForFirstSnapshot = _docs.isEmpty;

    _subscription = stream.listen(

      _onSnapshot,

      onError: (_) {

        if (mounted) setState(() => _waitingForFirstSnapshot = false);

      },

    );

  }

  void _bindPinnedStream(String chatId) {
    _pinnedSubscription?.cancel();
    _pinnedDocs = [];
    if (chatId.isEmpty) return;

    _pinnedSubscription = FirestoreChatApi.pinnedMessagesStream(
      FirebaseFirestore.instance,
      chatId,
    ).listen(
      (snapshot) {
        if (!mounted) return;
        setState(() {
          _pinnedDocs = findPinnedMessageDocs(snapshot.docs);
        });
      },
      onError: (_) {},
    );
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _mergeDocs() {
    return [..._liveDocs, ..._olderDocs];
  }

  Future<void> _loadOlderMessages() async {
    if (_loadingOlder || !_hasMoreOlder || _docs.isEmpty) return;
    setState(() => _loadingOlder = true);
    try {
      final anchor = _docs.last;
      final older = await FirestoreChatApi.fetchOlderChatMessages(
        fs: FirebaseFirestore.instance,
        chatId: widget.chatId,
        oldestLoaded: anchor,
      );
      if (!mounted) return;
      if (older.isEmpty) {
        _hasMoreOlder = false;
      } else {
        _olderDocs = [..._olderDocs, ...older];
        if (older.length < FirestoreQueryLimits.chatMessagesPage) {
          _hasMoreOlder = false;
        }
      }
      _docs = _mergeDocs();
      widget.panelController.orderedDocs = _docs;
      widget.onDocsChanged?.call(_docs);
    } catch (_) {
      if (mounted) _hasMoreOlder = false;
    } finally {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  Future<void> _ensureMessageVisible(String messageId) async {
    final id = messageId.trim();
    if (id.isEmpty || _docs.any((d) => d.id == id)) return;

    var guard = 0;
    const maxPages = 20;
    while (_hasMoreOlder &&
        !_docs.any((d) => d.id == id) &&
        guard < maxPages) {
      await _loadOlderMessages();
      guard++;
    }
    if (_docs.any((d) => d.id == id) || !mounted) return;

    final doc = await FirestoreChatApi.fetchChatMessageById(
      FirebaseFirestore.instance,
      widget.chatId,
      id,
    );
    if (doc == null || !mounted) return;
    setState(() => _insertOlderDocIfMissing(doc));
  }

  void _insertOlderDocIfMissing(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    if (_docs.any((d) => d.id == doc.id)) return;
    final ts = doc.data()['timestamp'] as Timestamp?;
    if (ts == null) {
      _olderDocs = [..._olderDocs, doc];
    } else {
      final list = [..._olderDocs];
      var inserted = false;
      for (var i = 0; i < list.length; i++) {
        final otherTs = list[i].data()['timestamp'] as Timestamp?;
        if (otherTs == null || ts.compareTo(otherTs) > 0) {
          list.insert(i, doc);
          inserted = true;
          break;
        }
      }
      if (!inserted) list.add(doc);
      _olderDocs = list;
    }
    _docs = _mergeDocs();
    widget.panelController.orderedDocs = _docs;
    widget.onDocsChanged?.call(_docs);
  }



  void _onSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {

    if (!mounted) return;

    final next = snapshot.docs;
    if (next.length < FirestoreQueryLimits.chatMessagesPage) {
      _hasMoreOlder = _olderDocs.isNotEmpty;
    }

    final prevLen = _docs.length;

    final wasAtLatest = _initialScrollComplete &&
        _scrollController.hasClients &&
        chatReverseListShowsLatestFromScroll(_scrollController);

    final needsRebuild =

        _docsNeedListRebuild(_docs, next, widget.currentUserId);



    _openScroll ??= _resolveOpenScroll(next);



    if (needsRebuild || _waitingForFirstSnapshot) {

      setState(() {

        _liveDocs = next;
        _docs = _mergeDocs();
        _waitingForFirstSnapshot = false;

      });

      widget.panelController.orderedDocs = _docs;

      widget.onDocsChanged?.call(_docs);
      _scheduleMarkReadIfAllowed();

      if (!_initialScrollApplied || _listEpochApplied != widget.listEpoch) {

        _scheduleInitialScroll();

      } else if (next.length > prevLen && wasAtLatest) {

        WidgetsBinding.instance.addPostFrameCallback((_) {

          if (!mounted || ChatScrollInteraction.userIsScrolling) return;

          unawaited(chatScrollToIndexInstant(_scrollController, 0));

        });

      }

    } else {

      _liveDocs = next;
      _docs = _mergeDocs();

      widget.panelController.orderedDocs = _docs;

      widget.onDocsChanged?.call(_docs);
      _scheduleMarkReadIfAllowed();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateFabNotifiers();
    });
  }

  void _scheduleInitialScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (_docs.isEmpty) {
        _initialScrollComplete = true;
        return;
      }
      if (_initialScrollApplied && _listEpochApplied == widget.listEpoch) {
        _initialScrollComplete = true;
        return;
      }

      final open = _openScroll ?? _resolveOpenScroll(_docs);
      _isRestoringScroll = true;
      final prefer = open.alignment >= 0.65
          ? AutoScrollPosition.end
          : (open.alignment <= 0.35
                ? AutoScrollPosition.begin
                : AutoScrollPosition.middle);
      try {
        await chatScrollToIndexInstant(
          _scrollController,
          open.index,
          preferPosition: prefer,
        );
      } catch (_) {}
      if (!mounted) return;
      _isRestoringScroll = false;
      _initialScrollApplied = true;
      _initialScrollComplete = true;
      _listEpochApplied = widget.listEpoch;
      _updateFabNotifiers();
      _scheduleMarkReadIfAllowed();
    });
  }



  ({int index, double alignment}) _resolveOpenScroll(

    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,

  ) {

    return resolveChatOpenScroll(

      itemCount: docs.length,

      currentUserId: widget.currentUserId,

      docs: docs,

      persisted: widget.usePersistedScroll ? widget.persistedScroll : null,

      usePersisted:

          widget.usePersistedScroll && widget.persistedScroll != null,

    );

  }



  void _onScrollOffset() {

    if (ChatScrollInteraction.userIsScrolling) {

      _fabThrottle ??= Timer(const Duration(milliseconds: 120), () {

        _fabThrottle = null;

        _updateFabNotifiers();

      });

      return;

    }

    _fabThrottle?.cancel();

    _fabThrottle = null;

    _updateFabNotifiers();

    _schedulePersistSnapshot();

  }



  void _updateFabNotifiers() {

    final n = _docs.length;

    if (n <= 0) return;



    final showFab = !chatReverseListShowsLatestFromScroll(_scrollController);
    if (showFab) {
      ChatMarkReadScheduler.cancelForChat(widget.chatId);
    }

    final unreadBelow = chatReverseListUnreadIncomingBelowCountFromScroll(

      controller: _scrollController,

      itemCount: n,

      docs: _docs,

      currentUserId: widget.currentUserId,

    );



    if (_fabVisible.value != showFab) {

      _fabVisible.value = showFab;

    }

    if (_fabUnread.value != unreadBelow) {

      _fabUnread.value = unreadBelow;

    }

  }



  void _schedulePersistSnapshot() {

    if (widget.onScrollSnapshotChanged == null) return;

    if (ChatScrollInteraction.userIsScrolling) return;



    _persistDebounce?.cancel();

    _persistDebounce = Timer(const Duration(milliseconds: 150), () {

      _persistDebounce = null;

      if (!mounted || ChatScrollInteraction.userIsScrolling) return;

      final snap = _currentScrollSnapshot();

      if (snap != null) {

        widget.onScrollSnapshotChanged?.call(snap);

      }

    });

  }



  bool _handleScrollNotification(ScrollNotification notification) {

    if (notification is ScrollStartNotification) {

      ChatScrollInteraction.onScrollStart();

    } else if (notification is ScrollUpdateNotification) {

      ChatScrollInteraction.onScrollActivity();

    } else if (notification is ScrollEndNotification) {

      ChatScrollInteraction.onScrollEnd();

      _fabThrottle?.cancel();

      _fabThrottle = null;

      _updateFabNotifiers();

      _schedulePersistSnapshot();
      _scheduleMarkReadIfAllowed();
    }

    return false;

  }



  @override

  void dispose() {

    _persistDebounce?.cancel();

    _fabThrottle?.cancel();
    _subscription?.cancel();
    _pinnedSubscription?.cancel();
    ChatMarkReadScheduler.cancelForChat(widget.chatId);

    _scrollController.removeListener(_onScrollOffset);

    _fabVisible.dispose();

    _fabUnread.dispose();

    widget.panelController._detach(owner: this);

    _scrollController.dispose();

    super.dispose();

  }



  @override

  Widget build(BuildContext context) {

    widget.panelController.tileBuilder = widget.itemBuilder;



    if (_waitingForFirstSnapshot && _docs.isEmpty && _pinnedDocs.isEmpty) {

      return widget.loadingWidget;

    }



    return Column(

      children: [

        if (_pinnedDocs.isNotEmpty && widget.pinnedBannerBuilder != null)

          widget.pinnedBannerBuilder!(context, _pinnedDocs),

        Expanded(

          child: _docs.isEmpty

              ? (_waitingForFirstSnapshot

                  ? widget.loadingWidget

                  : widget.emptyWidget)

              : Stack(

            clipBehavior: Clip.none,

            alignment: Alignment.bottomRight,

            children: [

              Positioned.fill(

                child: _ChatMessageScrollList(

                  listKey: ValueKey('${widget.chatId}_${widget.listEpoch}'),

                  scrollController: _scrollController,

                  panelController: widget.panelController,

                  padding: widget.padding,

                  docs: _docs,
                  hasMoreOlder: _hasMoreOlder,
                  loadingOlder: _loadingOlder,
                  onLoadOlder: _loadOlderMessages,

                  onScrollNotification: _handleScrollNotification,

                ),

              ),

              Positioned(

                right: 6,

                bottom: 10,

                child: ListenableBuilder(

                  listenable: Listenable.merge([_fabVisible, _fabUnread]),

                  builder: (context, _) {

                    return ChatScrollToLatestFab(

                      visible: _fabVisible.value,

                      badgeCount: _fabUnread.value,

                      onPressed: _scrollToLatest,

                    );

                  },

                ),

              ),

            ],

          ),

        ),

      ],

    );

  }

}

/// [docs], [padding], or [listKey] change.

class _ChatMessageScrollList extends StatefulWidget {

  final Key listKey;

  final AutoScrollController scrollController;

  final ChatMessageListPanelController panelController;

  final EdgeInsets padding;

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final bool hasMoreOlder;
  final bool loadingOlder;
  final VoidCallback? onLoadOlder;

  final bool Function(ScrollNotification notification) onScrollNotification;



  const _ChatMessageScrollList({

    required this.listKey,

    required this.scrollController,

    required this.panelController,

    required this.padding,

    required this.docs,
    this.hasMoreOlder = false,
    this.loadingOlder = false,
    this.onLoadOlder,

    required this.onScrollNotification,

  });



  @override

  State<_ChatMessageScrollList> createState() => _ChatMessageScrollListState();

}



class _ChatMessageScrollListState extends State<_ChatMessageScrollList> {

  static const _listPhysics = ClampingScrollPhysics(

    parent: AlwaysScrollableScrollPhysics(),

  );



  int? _indexForMessageId(String messageId) {

    for (var i = 0; i < widget.docs.length; i++) {

      if (widget.docs[i].id == messageId) return i;

    }

    return null;

  }



  @override

  Widget build(BuildContext context) {

    return NotificationListener<ScrollNotification>(

      onNotification: widget.onScrollNotification,

      child: ScrollConfiguration(

        behavior: ScrollConfiguration.of(context).copyWith(

          scrollbars: true,

          physics: _listPhysics,

        ),

        child: ListView.builder(

          key: widget.listKey,

          controller: widget.scrollController,

          reverse: true,

          padding: widget.padding,

          itemCount: widget.docs.length + (widget.hasMoreOlder ? 1 : 0),

          addAutomaticKeepAlives: true,

          addRepaintBoundaries: true,

          findChildIndexCallback: (Key key) {
            if (key is ValueKey<String>) {
              final value = key.value;
              if (value.startsWith('scroll_tag_')) {
                return _indexForMessageId(value.substring('scroll_tag_'.length));
              }
              return _indexForMessageId(value);
            }
            return null;
          },

          itemBuilder: (context, index) {
            if (widget.hasMoreOlder && index == widget.docs.length) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: widget.loadingOlder
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : TextButton(
                          onPressed: widget.onLoadOlder,
                          child: const Text('Load older messages'),
                        ),
                ),
              );
            }

            final doc = widget.docs[index];

            final builder = widget.panelController.tileBuilder;

            if (builder == null) return const SizedBox.shrink();

            return AutoScrollTag(

              key: ValueKey('scroll_tag_${doc.id}'),

              controller: widget.scrollController,

              index: index,

              child: RepaintBoundary(

                child: builder(context, doc, index),

              ),

            );

          },

        ),

      ),

    );

  }

}


