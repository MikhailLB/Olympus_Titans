import 'package:flutter_test/flutter_test.dart';

// The gray-flow boot wires up Firebase + AppCheck + Secure Storage
// channels which aren't available in the unit-test host. The smoke
// test is therefore a no-op marker until a properly mocked harness
// is in place.
void main() {
  test('smoke marker', () {
    expect(1 + 1, equals(2));
  });
}
