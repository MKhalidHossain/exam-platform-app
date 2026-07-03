import 'package:ej_flutter/controllers/auth_controller.dart';
import 'package:ej_flutter/views/screens/sign_up_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthController extends AuthController {
  int registerCalls = 0;
  String? capturedPhone;

  @override
  Future<void> register(
    BuildContext context, {
    String? phone,
    required String name,
    required String email,
    required String password,
    required String confirmPassword,
    String? referralCode,
  }) async {
    registerCalls++;
    capturedPhone = phone;
  }
}

void main() {
  late _FakeAuthController authController;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Get.testMode = true;
    Get.reset();
    authController = _FakeAuthController();
    Get.put<AuthController>(authController);
  });

  tearDown(Get.reset);

  Future<void> pumpSignUpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      const GetMaterialApp(home: Scaffold(body: SignUpScreen())),
    );
    await tester.pump();
  }

  Future<void> enterValidRequiredFields(
    WidgetTester tester, {
    String email = 'learner@example.com',
    String password = 'password123',
    String confirmPassword = 'password123',
    String phone = '',
  }) async {
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Test Learner');
    await tester.enterText(fields.at(1), email);
    await tester.enterText(fields.at(2), phone);
    await tester.enterText(fields.at(4), password);
    await tester.enterText(fields.at(5), confirmPassword);
  }

  Future<void> acceptTerms(WidgetTester tester) async {
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
  }

  Future<void> tapSignUp(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Sign up'));
    await tester.tap(find.text('Sign up'));
    await tester.pump();
  }

  testWidgets('allows sign up submission with empty optional phone', (
    tester,
  ) async {
    await pumpSignUpScreen(tester);
    await enterValidRequiredFields(tester);
    await acceptTerms(tester);
    await tapSignUp(tester);

    expect(authController.registerCalls, 1);
    expect(authController.capturedPhone, isNull);
    expect(find.text('Please enter your phone number'), findsNothing);
  });

  testWidgets('allows sign up submission with phone provided', (tester) async {
    await pumpSignUpScreen(tester);
    await enterValidRequiredFields(tester, phone: '+1-555-111-2222');
    await acceptTerms(tester);
    await tapSignUp(tester);

    expect(authController.registerCalls, 1);
    expect(authController.capturedPhone, '+1-555-111-2222');
  });

  testWidgets('keeps validation for invalid email', (tester) async {
    await pumpSignUpScreen(tester);
    await enterValidRequiredFields(tester, email: 'not-an-email');
    await acceptTerms(tester);
    await tapSignUp(tester);

    expect(authController.registerCalls, 0);
    expect(find.text('Please enter a valid email'), findsOneWidget);
  });

  testWidgets('keeps validation for password mismatch', (tester) async {
    await pumpSignUpScreen(tester);
    await enterValidRequiredFields(tester, confirmPassword: 'password456');
    await acceptTerms(tester);
    await tapSignUp(tester);

    expect(authController.registerCalls, 0);
    expect(find.text('Passwords do not match'), findsOneWidget);
  });

  testWidgets('keeps validation for terms agreement', (tester) async {
    await pumpSignUpScreen(tester);
    await enterValidRequiredFields(tester);
    await tapSignUp(tester);

    expect(authController.registerCalls, 0);
    expect(find.text('Please agree to the Terms & Conditions'), findsOneWidget);
    expect(find.text('Please enter your phone number'), findsNothing);
  });
}
