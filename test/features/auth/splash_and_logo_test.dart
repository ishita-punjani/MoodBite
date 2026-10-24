import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodbite/core/theme.dart';
import 'package:moodbite/features/auth/session_controller.dart';
import 'package:moodbite/features/auth/splash_screen.dart';
import 'package:moodbite/widgets/brand.dart';

class _LoadingSession extends ChangeNotifier implements SessionController {
  @override
  SessionStatus get status => SessionStatus.loading;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('the splash screen shows the MoodBite logo above the loading quip', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(ProviderScope(
      overrides: [sessionControllerProvider.overrideWithValue(_LoadingSession())],
      child: MaterialApp(theme: AppTheme.light, home: const SplashScreen()),
    ));
    await tester.pump();
    expect(find.byType(BrandLogo), findsOneWidget);
    expect(find.bySemanticsLabel('MoodBite logo'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('BrandTitle puts the logo next to the title text', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: Scaffold(appBar: AppBar(title: const BrandTitle('Orders')))));
    expect(find.byType(BrandLogo), findsOneWidget);
    expect(find.text('Orders'), findsOneWidget);
    expect(tester.getTopLeft(find.byType(BrandLogo)).dx, lessThan(tester.getTopLeft(find.text('Orders')).dx));
  });
}
