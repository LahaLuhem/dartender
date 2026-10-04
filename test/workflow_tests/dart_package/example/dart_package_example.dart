import 'dart:io';

import 'package:dart_package/dart_package.dart';

void main() {
  final awesome = Awesome();
  stdout.writeln('awesome: ${awesome.isAwesome}');
}
