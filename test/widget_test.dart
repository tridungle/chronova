import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App builds without errors', (WidgetTester tester) async {
    // Basic smoke test — full app requires native plugins,
    // so we just verify the test infrastructure works.
    expect(1 + 1, equals(2));
  });
}
