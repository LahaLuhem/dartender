import 'package:flutter/foundation.dart';

/// Counts up from 0, telling its listeners each time.
class Counter() extends ValueNotifier<int> {
  /// Creates it.
  this : super(0);

  /// Adds 1.
  void increment() => value++;
}
