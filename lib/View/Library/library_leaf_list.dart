import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Models/LibraryFileModel.dart';
import 'package:point/Models/TaskModel.dart';
import 'package:point/Services/library_path_utils.dart';
import 'package:point/View/Library/library_direct_file_card.dart';
import 'package:point/View/Library/LibraryPage.dart' show LibraryFileEntryCard;

enum _LibraryLeafEntryKind { task, directFile }

class _LibraryLeafEntry {
  final _LibraryLeafEntryKind kind;
  final DateTime sortAt;
  final TaskModel? task;
  final LibraryFileModel? directFile;

  const _LibraryLeafEntry._({
    required this.kind,
    required this.sortAt,
    this.task,
    this.directFile,
  });

  factory _LibraryLeafEntry.task(TaskModel t) {
    return _LibraryLeafEntry._(
      kind: _LibraryLeafEntryKind.task,
      sortAt:
          LibraryPathUtils.inferredFinalDeliverableLastActivity(t) ?? t.toDate,
      task: t,
    );
  }

  factory _LibraryLeafEntry.directFile(LibraryFileModel f) {
    return _LibraryLeafEntry._(
      kind: _LibraryLeafEntryKind.directFile,
      sortAt: f.uploadedAt,
      directFile: f,
    );
  }
}

List<_LibraryLeafEntry> libraryLeafEntriesSorted({
  required List<TaskModel> tasks,
  required List<LibraryFileModel> directFiles,
}) {
  final out = <_LibraryLeafEntry>[
    ...tasks.map(_LibraryLeafEntry.task),
    ...directFiles.map(_LibraryLeafEntry.directFile),
  ];
  out.sort((a, b) => b.sortAt.compareTo(a.sortAt));
  return out;
}

class LibraryLeafList extends StatelessWidget {
  final List<TaskModel> tasks;
  final List<LibraryFileModel> directFiles;
  final VoidCallback? onChanged;

  const LibraryLeafList({
    super.key,
    required this.tasks,
    required this.directFiles,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final entries = libraryLeafEntriesSorted(
      tasks: tasks,
      directFiles: directFiles,
    );
    if (entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'library.empty'.tr,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 12),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final e = entries[i];
        switch (e.kind) {
          case _LibraryLeafEntryKind.task:
            return LibraryFileEntryCard(task: e.task!);
          case _LibraryLeafEntryKind.directFile:
            return LibraryDirectFileCard(
              file: e.directFile!,
              onDeleted: onChanged,
            );
        }
      },
    );
  }
}
