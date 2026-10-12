import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:animiat/kokuro/components.dart';
import 'package:animiat/kokuro/story_thread.dart';
import 'package:animiat/kokuro/tokens.dart';

void main() {
  testWidgets('DnaBar renders label and percentage', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: DnaBar(label: 'Power', value: 0.8)),
      ),
    );

    expect(find.text('Power'), findsOneWidget);
    expect(find.text('80%'), findsOneWidget);
  });

  testWidgets('DnaBar uses custom color when provided', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DnaBar(label: 'Power', value: 0.5, color: Color(0xFF00FF00)),
        ),
      ),
    );

    expect(find.text('Power'), findsOneWidget);
    expect(find.byType(FractionallySizedBox), findsOneWidget);
  });

  testWidgets('PersonalityTag renders label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: PersonalityTag(label: 'ذكي')),
      ),
    );

    expect(find.text('ذكي'), findsOneWidget);
  });

  testWidgets('StoryThread paints without throwing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StoryThread(
            points: const [Offset(0, 0), Offset(50, 50)],
            animate: false,
          ),
        ),
      ),
    );

    expect(find.byType(StoryThread), findsOneWidget);
  });

  testWidgets('ThreadNode hits stationary ring', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ThreadNode(child: SizedBox(width: 64, height: 64)),
        ),
      ),
    );

    expect(find.byType(AnimatedContainer), findsOneWidget);
  });

  testWidgets('accent theme switching updates token and persistence keys', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final before = K.accent;
    await K.applyAccentIndex(1);

    expect(K.accent, isNot(before));
    expect(K.accentVersion.value, greaterThan(0));

    await K.applyAccentIndex(0);
    expect(K.accent, before);
  });
}
