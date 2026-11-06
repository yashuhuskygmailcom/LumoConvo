import 'package:flutter_test/flutter_test.dart';
import 'package:lumoconvo/firebase_bootstrap.dart';
import 'package:lumoconvo/haychat_app.dart';

void main() {
  testWidgets('shows Firebase setup state when configuration is missing', (
    tester,
  ) async {
    await tester.pumpWidget(
      const HayChatApp(
        firebase: FirebaseBootstrapResult.failed('Firebase not configured'),
      ),
    );

    expect(find.text('Connect Firebase'), findsOneWidget);
    expect(find.text('HayChat', findRichText: true), findsOneWidget);
  });
}
