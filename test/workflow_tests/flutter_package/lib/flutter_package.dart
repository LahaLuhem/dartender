import 'package:flutter/widgets.dart';

/// Says hello, so the tests have a widget to cover.
class Greeting extends StatelessWidget {
  /// Greets [name].
  const Greeting({required this.name, super.key});

  /// Who gets greeted.
  final String name;

  @override
  Widget build(BuildContext context) =>
      Text('Hello, $name', textDirection: TextDirection.ltr);
}
