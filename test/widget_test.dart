import 'package:flutter_test/flutter_test.dart';

import 'package:searchly/main.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SearchlyApp(showOnboarding: false, firebaseReady: false));
    expect(find.text('Searchly'), findsOneWidget);
  });
}
