import 'dart:io';

import 'package:mason/mason.dart';

/// mason cannot leave a file out on a variable. Runs in the caller repo, so the path is relative.
void run(HookContext context) {
  if (context.vars['codegen'] == true) return;
  final caller = File('.github/workflows/codegen.yml');
  if (caller.existsSync()) caller.deleteSync();
}
