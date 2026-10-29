import 'package:delicia/presentation/screens/intro/widgets/launch_first_view.dart';
import 'package:delicia/presentation/screens/intro/widgets/launch_welcome_view.dart';
import 'package:delicia/presentation/themes/colors_frave.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wraps [child] in an always-animated controller so entrance transitions are
/// completed without pumping frames by hand.
Widget harness(Widget child, AnimationController controller) {
  return MaterialApp(
    home: AnimatedBuilder(
      animation: controller,
      builder: (_, __) => child,
    ),
  );
}

void main() {
  // A few common phone sizes — including the short ones that used to trigger
  // "RenderFlex overflowed by N pixels".
  const sizes = <Size>[
    Size(393, 852), // iPhone 15 / design reference
    Size(360, 640), // small Android
    Size(320, 568), // iPhone SE 1st gen — smallest supported
    Size(412, 915), // large Android
  ];

  group('LaunchFirstView', () {
    for (final size in sizes) {
      testWidgets('renders without overflow on ${size.width}x${size.height}', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final controller = AnimationController(
          vsync: const TestVSync(),
          duration: const Duration(seconds: 1),
        )..value = 1;
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          harness(
            LaunchFirstView(animation: controller, onContinue: () {}),
            controller,
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('DELICIA'), findsOneWidget);
        expect(find.byType(LaunchRoundCta), findsOneWidget);
      });
    }

    testWidgets('CTA tap invokes the callback', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final controller = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(seconds: 1),
      )..value = 1;
      addTearDown(controller.dispose);

      var tapped = false;
      await tester.pumpWidget(
        harness(
          LaunchFirstView(
            animation: controller,
            onContinue: () => tapped = true,
          ),
          controller,
        ),
      );

      await tester.tap(find.byType(LaunchRoundCta));
      expect(tapped, isTrue);
    });
  });

  group('LaunchWelcomeView', () {
    for (final size in sizes) {
      testWidgets('renders without overflow on ${size.width}x${size.height}', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final controller = AnimationController(
          vsync: const TestVSync(),
          duration: const Duration(seconds: 1),
        )..value = 1;
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          harness(LaunchWelcomeView(animation: controller), controller),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Đăng nhập'), findsOneWidget);
        expect(find.text('Tạo tài khoản'), findsOneWidget);
      });
    }

    testWidgets('both pills are visible and tappable', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final controller = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(seconds: 1),
      )..value = 1;
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        harness(LaunchWelcomeView(animation: controller), controller),
      );
      await tester.pumpAndSettle();

      expect(find.byType(WelcomePill), findsNWidgets(2));
      // The cream pill uses the secondary colour, the yellow one the accent.
      expect(find.widgetWithText(WelcomePill, 'Đăng nhập'), findsOneWidget);
      expect(
        find.widgetWithText(WelcomePill, 'Tạo tài khoản'),
        findsOneWidget,
      );
    });
  });

  group('brand palette', () {
    test('matches the UI kit colours', () {
      expect(ColorsFrave.launchBg, const Color(0xFFF5CB58));
      expect(ColorsFrave.launchAccent, const Color(0xFFFF642F));
      expect(ColorsFrave.welcomeBg, const Color(0xFFE95322));
      expect(ColorsFrave.welcomeAccent, const Color(0xFFF5CB58));
      expect(ColorsFrave.welcomeSecondary, const Color(0xFFF3E9B5));
    });
  });
}