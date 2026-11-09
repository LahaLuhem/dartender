import 'package:dart_package/dart_package.dart';
import 'package:test/test.dart';

void main() {
  test('a profile survives a round trip through JSON', () {
    const profile = Profile(name: 'Dash', isAwesome: true);

    final restored = Profile.fromJson(profile.toJson());

    expect(restored.name, profile.name);
    expect(restored.isAwesome, profile.isAwesome);
  });
}
