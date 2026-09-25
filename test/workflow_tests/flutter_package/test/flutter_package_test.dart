import 'package:flutter_package/flutter_package.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('greets by name', (tester) async {
    await tester.pumpWidget(const Greeting(name: 'dartender'));

    expect(find.text('Hello, dartender'), findsOneWidget);
  });
}
