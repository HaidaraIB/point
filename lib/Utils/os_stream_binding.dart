import 'package:get/get.dart';

/// Binds [list] to [stream] when [allowed]; otherwise binds an empty list.
void bindOsListStream<T>(
  RxList<T> list,
  bool allowed,
  Stream<List<T>> stream,
) {
  if (!allowed) {
    list.bindStream(Stream<List<T>>.value(const []));
    return;
  }
  list.bindStream(stream);
}

/// Binds [rx] to [stream] when [allowed]; otherwise binds [emptyValue].
void bindOsValueStream<T>(
  Rx<T> rx,
  bool allowed,
  Stream<T> stream,
  T emptyValue,
) {
  if (!allowed) {
    rx.bindStream(Stream<T>.value(emptyValue));
    return;
  }
  rx.bindStream(stream);
}
