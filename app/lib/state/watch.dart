import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:skidsense_core/skidsense_core.dart';

/// Rebuilds [builder] with [value]'s current value, whenever it changes.
class Watch<T> extends StatefulWidget {
  const Watch(this.value, {super.key, required this.builder});

  final StateValue<T> value;
  final Widget Function(BuildContext context, T value) builder;

  @override
  State<Watch<T>> createState() => _WatchState<T>();
}

class _WatchState<T> extends State<Watch<T>> {
  StreamSubscription<T>? _subscription;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(Watch<T> old) {
    super.didUpdateWidget(old);
    if (!identical(old.value, widget.value)) {
      unawaited(_subscription?.cancel());
      _listen();
    }
  }

  void _listen() => _subscription = widget.value.changes.listen((_) {
        if (mounted) setState(() {});
      });

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, widget.value.value);
}

/// Rebuilds only when [select] of [value] changes (by `==`), for widgets
/// that care about one field of a large state.
class WatchSelect<T, S> extends StatefulWidget {
  const WatchSelect(this.value, {super.key, required this.select, required this.builder});

  final StateValue<T> value;
  final S Function(T value) select;
  final Widget Function(BuildContext context, S selected) builder;

  @override
  State<WatchSelect<T, S>> createState() => _WatchSelectState<T, S>();
}

class _WatchSelectState<T, S> extends State<WatchSelect<T, S>> {
  StreamSubscription<T>? _subscription;
  late S _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.select(widget.value.value);
    _subscription = widget.value.changes.listen((value) {
      final next = widget.select(value);
      if (next != _selected && mounted) setState(() => _selected = next);
    });
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _selected);
}
