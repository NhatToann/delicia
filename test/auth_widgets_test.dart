import 'package:delicia/presentation/components/auth_text_field.dart';
import 'package:delicia/presentation/components/auth_widgets.dart';
import 'package:delicia/presentation/themes/colors_frave.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phone sizes the auth screens must survive — the kit design is 393x852 and
/// these are the smallest/largest devices we support.
const _sizes = <Size>[
  Size(393, 852), // design reference
  Size(360, 640), // small Android
  Size(320, 568), // iPhone SE — smallest supported
  Size(412, 915), // large Android
];

Future<void> _pumpAt(WidgetTester tester, Size size, Widget child) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: Scaffold(body: child),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('AuthTextField', () {
    for (final size in _sizes) {
      testWidgets('renders without overflow on ${size.width}x${size.height}', (
        tester,
      ) async {
        final controller = TextEditingController();
        addTearDown(controller.dispose);

        await _pumpAt(
          tester,
          size,
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const FieldCaption('Email Address'),
              AuthTextField(
                controller: controller,
                label: 'Email',
                icon: Icons.alternate_email_rounded,
              ),
            ],
          ),
        );

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('obscures the text when [obscure] is true', (tester) async {
      final controller = TextEditingController(text: 'secret123');
      addTearDown(controller.dispose);

      await _pumpAt(
        tester,
        _sizes.first,
        AuthTextField(controller: controller, label: 'Password', obscure: true),
      );

      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byType(AuthTextField),
          matching: find.byType(TextField),
        ),
      );
      expect(field.obscureText, isTrue);
    });
  });

  group('AuthPrimaryButton', () {
    testWidgets('renders the label and fires onPressed', (tester) async {
      var taps = 0;
      await _pumpAt(
        tester,
        _sizes.first,
        AuthPrimaryButton(
          label: 'Sign In',
          icon: Icons.login_rounded,
          onPressed: () => taps++,
        ),
      );

      expect(find.text('Sign In'), findsOneWidget);

      await tester.tap(find.byType(AuthPrimaryButton));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('a very long label ellipsises instead of overflowing', (
      tester,
    ) async {
      await _pumpAt(
        tester,
        _sizes.first,
        AuthPrimaryButton(
          label: 'Create An Account With A Very Long Label Indeed',
          onPressed: () {},
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('busy shows a spinner and ignores taps', (tester) async {
      var taps = 0;
      tester.view.physicalSize = _sizes.first;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AuthPrimaryButton(
              label: 'Sign In',
              busy: true,
              onPressed: () => taps++,
            ),
          ),
        ),
      );
      // A single pump — never pumpAndSettle, because the spinner animates
      // forever and would hang the test.
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.tap(find.byType(AuthPrimaryButton));
      await tester.pump();
      expect(taps, 0);
    });
  });

  group('AuthDivider', () {
    testWidgets('renders the centred label', (tester) async {
      await _pumpAt(
        tester,
        _sizes.first,
        const AuthDivider(label: 'Or continue with'),
      );

      expect(find.text('Or continue with'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('AuthSocialRow', () {
    testWidgets('renders three social chips', (tester) async {
      await _pumpAt(
        tester,
        _sizes.first,
        const AuthSocialRow(
          onFacebook: _noop,
          onGoogle: _noop,
          onApple: _noop,
        ),
      );

      expect(find.text('f'), findsOneWidget);
      expect(find.text('G'), findsOneWidget);
      expect(find.byIcon(Icons.apple_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('AuthFooterLink', () {
    testWidgets('wraps onto a second line without overflowing', (tester) async {
      var tapped = false;
      await _pumpAt(
        tester,
        Size(320, 568),
        AuthFooterLink(
          prompt: "Don't have an account?",
          actionLabel: 'Sign Up',
          onTap: () => tapped = true,
        ),
      );

      expect(find.text("Don't have an account?"), findsOneWidget);
      expect(find.text('Sign Up'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Sign Up'));
      await tester.pump();
      expect(tapped, isTrue);
    });
  });

  group('AuthHeader', () {
    for (final size in _sizes) {
      testWidgets('renders without overflow on ${size.width}x${size.height}', (
        tester,
      ) async {
        await _pumpAt(
          tester,
          size,
          AuthHeader(title: 'Sign In', onBack: () {}),
        );

        expect(find.text('Sign In'), findsOneWidget);
        expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('back button invokes onBack', (tester) async {
      var backs = 0;
      await _pumpAt(
        tester,
        _sizes.first,
        AuthHeader(title: 'Sign In', onBack: () => backs++),
      );

      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pump();
      expect(backs, 1);
    });
  });

  group('auth palette', () {
    test('brand colour is softened ~10% from the original UI-kit orange', () {
      const original = Color(0xFFE95322);
      expect(ColorsFrave.primaryColor, isNot(original));
      // Red channel drops by ~10%; the softened colour stays in the same hue
      // family (warm orange) rather than shifting hue entirely.
      expect(ColorsFrave.primaryColor.r, lessThan(original.r));
      expect(
        ColorsFrave.primaryColor.r,
        greaterThanOrEqualTo(original.r - 30),
      );
      // Green/blue also come down, which is what removes the harshness.
      expect(ColorsFrave.primaryColor.g, lessThan(original.g));
      expect(ColorsFrave.primaryColor.b, lessThan(original.b));
    });

    test('auth surfaces are light and the ink is a warm dark brown', () {
      expect(
        ColorsFrave.authBg.computeLuminance(),
        greaterThan(0.85), // near-white backdrop
      );
      expect(ColorsFrave.authInk.computeLuminance(), lessThan(0.12));
    });
  });
}

void _noop() {}