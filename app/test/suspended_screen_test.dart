import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incomodo/screens/suspended_screen.dart';

void main() {
  testWidgets('a suspended account is told why, and where to ask',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: SuspendedScreen()),
    ));

    expect(find.text('このアカウントは利用停止中です'), findsOneWidget);
    expect(find.text(SuspendedScreen.contact), findsOneWidget);
    expect(find.text('ログアウト'), findsOneWidget);
  });
}
