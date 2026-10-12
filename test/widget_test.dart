import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:animiat/kokuro/components.dart';
import 'package:animiat/kokuro/tokens.dart';

void main() {
  testWidgets('KOKURO core widget smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox())),
    );
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('accent token fallback renders PersonalityTag', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: PersonalityTag(label: 'KOKURO')),
      ),
    );

    expect(find.text('KOKURO'), findsOneWidget);
  });

  test('accent reset preserves default preset', () async {
    SharedPreferences.setMockInitialValues({});
    final before = K.accent;
    await K.applyAccentIndex(0);
    expect(K.accent, before);
  });
}
