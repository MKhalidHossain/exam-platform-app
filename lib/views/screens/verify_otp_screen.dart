import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:get/get.dart';
import '../../utils/app_colors.dart';
import '../../core/error/error_handler.dart';
import '../../controllers/auth_controller.dart';
import '../widgets/gradient_background.dart';
import '../widgets/app_logo_header.dart';
import '../widgets/otp_input_field.dart';
import '../widgets/primary_button.dart';
import '../widgets/custom_text_field.dart';

class VerifyOtpScreen extends StatefulWidget {
  final String? email;
  final bool isForPasswordReset;

  const VerifyOtpScreen({
    super.key,
    this.email,
    this.isForPasswordReset = false,
  });

  @override
  State<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends State<VerifyOtpScreen> {
  final AuthController _authController = Get.find<AuthController>();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String _otp = '';

  @override
  void dispose() {
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleVerifyOtp() async {
    if (widget.email == null || widget.email!.isEmpty) {
      ErrorHandler.showSnackBar('Email is required', isError: true, context: context);
      return;
    }

    if (_otp.isEmpty || _otp.length != 6) {
      ErrorHandler.showSnackBar('Please enter a valid 6-digit OTP', isError: true, context: context);
      return;
    }

    // If password reset, validate password fields
    if (widget.isForPasswordReset) {
      if (_passwordController.text.isEmpty) {
        ErrorHandler.showSnackBar('Please enter your new password', isError: true, context: context);
        return;
      }

      if (_passwordController.text.length < 8) {
        ErrorHandler.showSnackBar('Password must be at least 8 characters', isError: true, context: context);
        return;
      }

      if (_passwordController.text != _confirmPasswordController.text) {
        ErrorHandler.showSnackBar('Passwords do not match', isError: true, context: context);
        return;
      }
    }

    if (widget.isForPasswordReset) {
      await _authController.resetPasswordWithOtp(
        context,
        email: widget.email!,
        otp: _otp,
        password: _passwordController.text,
      );
    } else {
      // keep UI only; other OTP flows can be added later
      ErrorHandler.showSnackBar('OTP verification flow is not implemented yet', isError: true, context: context);
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                
                // Back Button
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: AppColors.textPrimary,
                    ),
                    onPressed: () {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      } else {
                        // If coming from password reset flow, go to forget password
                        if (widget.isForPasswordReset) {
                          context.go('/forget-password');
                        } else {
                          context.go('/login');
                        }
                      }
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ),
                
                const SizedBox(height: 20),

                // Logo and App Name
                const AppLogoHeader(),

                const SizedBox(height: 60),

                // Title
                const Text(
                  'Enter OTP',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),

                const SizedBox(height: 40),

                // OTP Input Field
                OtpInputField(
                  length: 6,
                  onChanged: (value) {
                    setState(() {
                      _otp = value;
                    });
                  },
                  onCompleted: (value) {
                    setState(() {
                      _otp = value;
                    });
                    // Auto-submit if password reset and password is entered
                    if (widget.isForPasswordReset && 
                        _passwordController.text.isNotEmpty &&
                        _confirmPasswordController.text.isNotEmpty) {
                      _handleVerifyOtp();
                    }
                  },
                ),

                // Password fields (only for password reset)
                if (widget.isForPasswordReset) ...[
                  const SizedBox(height: 24),
                  
                  // New Password Field
                  CustomTextField(
                    label: 'New Password',
                    hint: 'Enter your new password',
                    prefixIcon: Icons.lock_outline,
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      if (value.length < 8) {
                        return 'Password must be at least 8 characters';
                      }
                      return null;
                    },
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Confirm Password Field
                  CustomTextField(
                    label: 'Confirm Password',
                    hint: 'Confirm your new password',
                    prefixIcon: Icons.lock_outline,
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm your password';
                      }
                      if (value != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Resend OTP
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Didn't Receive OTP? ",
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    GestureDetector(
                      onTap:() async {
                      },
                      child: const Text(
                        'RESEND OTP',
                        style: TextStyle(
                          color: AppColors.textLink,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 40),

                // Verify Now Button
                Obx(
                  () => PrimaryButton(
                    text: widget.isForPasswordReset ? 'Reset Password' : 'Verify Now',
                    onPressed: _authController.isLoading.value
                        ? null
                        : _handleVerifyOtp,
                    isLoading: _authController.isLoading.value,
                    useGradient: true,
                    borderRadius: 30,
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
