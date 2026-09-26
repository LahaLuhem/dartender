import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_package/flutter_package.dart';

void main() {
  test('counts up by one', () {
    final counter = Counter()..increment();
    expect(counter.value, 1);
  });
}
