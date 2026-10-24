import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/session_controller.dart';
import '../features/auth/sign_in_screen.dart';
import '../features/auth/splash_screen.dart';
import '../features/auth/verify_otp_screen.dart';
import '../features/browse/restaurant_list_screen.dart';
import '../features/browse/restaurant_menu_screen.dart';
import '../features/cart/cart_screen.dart';
import '../features/chat/chat_screen.dart';
import '../features/home/home_screen.dart';
import '../features/home/recommendations_screen.dart';
import '../features/orders/checkout_screen.dart';
import '../features/orders/order_confirmation_screen.dart';
import '../features/orders/orders_list_screen.dart';
import '../features/profile/about_screen.dart';
import '../features/profile/profile_form_screen.dart';
import '../features/tracking/tracking_screen.dart';
import '../widgets/app_shell.dart';

abstract final class AppRoutes {
  static const splash = '/splash';
  static const signIn = '/sign-in';
  static const verify = '/verify';
  static const completeProfile = '/complete-profile';
  static const home = '/home';
  static const recommendations = '/home/recommendations';
  static const restaurants = '/restaurants';
  static const ask = '/ask';
  static const cart = '/cart';
  static const checkout = '/checkout';
  static const orders = '/orders';
  static const profile = '/profile';
  static const about = '/about';

  static String verifyFor(String email) =>
      Uri(path: verify, queryParameters: {'email': email}).toString();

  static String restaurant(String id) => '/restaurant/$id';

  static String trackOrder(String orderId) => '/order/$orderId';

  static String orderConfirmation(String orderId) => '/order/$orderId/confirmed';

  static String recommendationsFor(String moodId) =>
      Uri(path: recommendations, queryParameters: {'mood': moodId}).toString();
}

const _signedOutRoutes = {AppRoutes.signIn, AppRoutes.verify};
const _onboardingRoutes = {
  AppRoutes.splash,
  AppRoutes.signIn,
  AppRoutes.verify,
  AppRoutes.completeProfile,
};

/// Where to send the user for a given session state, or `null` to stay.
/// Pure function so it can be unit tested.
String? sessionRedirect(SessionStatus status, String location) {
  switch (status) {
    case SessionStatus.signedOut:
      return _signedOutRoutes.contains(location) ? null : AppRoutes.signIn;
    case SessionStatus.loading:
    case SessionStatus.error:
      return location == AppRoutes.splash ? null : AppRoutes.splash;
    case SessionStatus.needsProfile:
      return location == AppRoutes.completeProfile ? null : AppRoutes.completeProfile;
    case SessionStatus.ready:
      return _onboardingRoutes.contains(location) ? AppRoutes.home : null;
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final session = ref.watch(sessionControllerProvider);

  final router = GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: session,
    redirect: (context, state) => sessionRedirect(session.status, state.matchedLocation),
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (context, state) => const SplashScreen()),
      GoRoute(path: AppRoutes.signIn, builder: (context, state) => const SignInScreen()),
      GoRoute(
        path: AppRoutes.verify,
        builder: (context, state) =>
            VerifyOtpScreen(email: state.uri.queryParameters['email'] ?? ''),
      ),
      GoRoute(
        path: AppRoutes.completeProfile,
        builder: (context, state) => const ProfileFormScreen(isOnboarding: true),
      ),
      GoRoute(path: AppRoutes.profile, builder: (context, state) => const ProfileFormScreen()),
      GoRoute(path: AppRoutes.about, builder: (context, state) => const AboutScreen()),
      GoRoute(
        path: '/restaurant/:id',
        builder: (context, state) =>
            RestaurantMenuScreen(restaurantId: state.pathParameters['id']!),
      ),
      GoRoute(path: AppRoutes.checkout, builder: (context, state) => const CheckoutScreen()),
      GoRoute(
        path: '/order/:id',
        builder: (context, state) => TrackingScreen(orderId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/order/:id/confirmed',
        builder: (context, state) =>
            OrderConfirmationScreen(orderId: state.pathParameters['id']!),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.home,
              builder: (context, state) => const HomeScreen(),
              routes: [
                GoRoute(
                  path: 'recommendations',
                  builder: (context, state) =>
                      RecommendationsScreen(moodId: state.uri.queryParameters['mood'] ?? ''),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.restaurants,
              builder: (context, state) => const RestaurantListScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.ask, builder: (context, state) => const ChatScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.orders, builder: (context, state) => const OrdersListScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.cart, builder: (context, state) => const CartScreen()),
          ]),
        ],
      ),
    ],
    errorBuilder: (context, state) => const Scaffold(
      body: Center(child: Text('Page not found')),
    ),
  );

  ref.onDispose(router.dispose);
  return router;
});
