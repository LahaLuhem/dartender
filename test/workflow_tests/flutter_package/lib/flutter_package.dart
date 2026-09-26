import 'package:flutter/foundation.dart';

class Counter extends ValueNotifier<int> {
  Counter() : super(0);

  void increment() => value++;
}
