import 'package:flutter_test/flutter_test.dart';
import 'package:moodbite/core/router.dart';
import 'package:moodbite/features/auth/session_controller.dart';

void main() {
  test('signed-out users can only see sign-in and verify', () {
    expect(sessionRedirect(SessionStatus.signedOut, AppRoutes.signIn), isNull);
    expect(sessionRedirect(SessionStatus.signedOut, AppRoutes.verify), isNull);
    expect(sessionRedirect(SessionStatus.signedOut, AppRoutes.home), AppRoutes.signIn);
    expect(sessionRedirect(SessionStatus.signedOut, AppRoutes.cart), AppRoutes.signIn);
  });

  test('loading and error states wait on the splash screen', () {
    expect(sessionRedirect(SessionStatus.loading, AppRoutes.verify), AppRoutes.splash);
    expect(sessionRedirect(SessionStatus.error, AppRoutes.home), AppRoutes.splash);
    expect(sessionRedirect(SessionStatus.loading, AppRoutes.splash), isNull);
  });

  test('an incomplete profile must be completed first', () {
    expect(sessionRedirect(SessionStatus.needsProfile, AppRoutes.home), AppRoutes.completeProfile);
    expect(sessionRedirect(SessionStatus.needsProfile, AppRoutes.completeProfile), isNull);
  });

  test('ready users skip onboarding screens but can go anywhere else', () {
    for (final onboarding in [AppRoutes.splash, AppRoutes.signIn, AppRoutes.verify, AppRoutes.completeProfile]) {
      expect(sessionRedirect(SessionStatus.ready, onboarding), AppRoutes.home);
    }
    for (final page in [AppRoutes.home, AppRoutes.orders, AppRoutes.cart, AppRoutes.profile, AppRoutes.restaurant('r001')]) {
      expect(sessionRedirect(SessionStatus.ready, page), isNull);
    }
  });

  test('route helpers build the expected locations', () {
    expect(AppRoutes.verifyFor('a+b@x.com'), '/verify?email=a%2Bb%40x.com');
    expect(AppRoutes.restaurant('r007'), '/restaurant/r007');
    expect(AppRoutes.recommendationsFor('happy'), '/home/recommendations?mood=happy');
  });
}
