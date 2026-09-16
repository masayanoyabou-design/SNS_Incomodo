import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incomodo/models/app_version.dart';
import 'package:incomodo/providers/app_config_provider.dart';
import 'package:incomodo/screens/update_required_screen.dart';

void main() {
  test('the build number matches pubspec.yaml', () {
    // Bumping the version in pubspec.yaml without this constant would make
    // every new build look old to the server, or an old one look new.
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final build = RegExp(
      r'^version:\s*[\d.]+\+(\d+)',
      multiLine: true,
    ).firstMatch(pubspec)?.group(1);
    expect(build, isNotNull, reason: 'version: x.y.z+N not found');
    expect(AppVersion.build, int.parse(build!));
  });

  group('needsUpdate', () {
    test('only when the server asks for a newer build', () {
      expect(needsUpdate(current: 3, minimum: 4), isTrue);
      expect(needsUpdate(current: 4, minimum: 4), isFalse);
      expect(needsUpdate(current: 5, minimum: 4), isFalse);
    });

    test('no setting on the server never blocks anyone', () {
      expect(needsUpdate(current: 1, minimum: null), isFalse);
    });
  });

  group('UpdateGate', () {
    Future<void> pump(WidgetTester tester, Stream<int?> minimum) =>
        tester.pumpWidget(
          ProviderScope(
            overrides: [minimumBuildProvider.overrideWith((ref) => minimum)],
            child: const MaterialApp(
              home: UpdateGate(currentBuild: 3, child: Text('アプリ本体')),
            ),
          ),
        );

    testWidgets('an old build is asked to update', (tester) async {
      await pump(tester, Stream.value(4));
      await tester.pumpAndSettle();

      expect(find.text('アプリを更新してください'), findsOneWidget);
      expect(find.text('アプリ本体'), findsNothing);
    });

    testWidgets('a current build goes straight in', (tester) async {
      await pump(tester, Stream.value(3));
      await tester.pumpAndSettle();

      expect(find.text('アプリ本体'), findsOneWidget);
    });

    testWidgets('a server that cannot be reached locks nobody out', (
      tester,
    ) async {
      await pump(tester, Stream.error(Exception('offline')));
      await tester.pumpAndSettle();

      expect(find.text('アプリ本体'), findsOneWidget);
    });
  });
}
