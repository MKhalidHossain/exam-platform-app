import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:get/get.dart';
import '../../utils/app_colors.dart';
import '../../controllers/auth_controller.dart';
import '../../services/storage_service.dart';
import '../widgets/gradient_background.dart';
import '../widgets/app_logo_header.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/primary_button.dart';

class SignUpScreen extends StatefulWidget {
  final String initialReferralCode;

  const SignUpScreen({super.key, this.initialReferralCode = ''});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  late final TextEditingController _referralCodeController;
  final AuthController _authController = Get.find<AuthController>();
  final StorageService _storageService = StorageService();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeToTerms = false;

  @override
  void initState() {
    super.initState();
    _referralCodeController = TextEditingController(
      text: widget.initialReferralCode.trim().toUpperCase(),
    );
    _bootstrapReferralCode();
  }

  Future<void> _bootstrapReferralCode() async {
    final initialCode = widget.initialReferralCode.trim().toUpperCase();
    if (initialCode.isNotEmpty) {
      await _storageService.savePendingReferralCode(initialCode);
      return;
    }

    final storedCode = await _storageService.getPendingReferralCode();
    if (!mounted || storedCode == null || storedCode.isEmpty) return;
    if (_referralCodeController.text.trim().isNotEmpty) return;

    _referralCodeController.text = storedCode;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _referralCodeController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please agree to the Terms & Conditions'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await _authController.register(
      context,
      phone: _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      confirmPassword: _confirmPasswordController.text,
      referralCode: _referralCodeController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: _formKey,
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
                          context.go('/onboarding');
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

                  // Name Field
                  CustomTextField(
                    label: 'Name',
                    hint: 'Enter your Full Name',
                    prefixIcon: Icons.person_outline,
                    controller: _nameController,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your name';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 24),

                  // Email Field
                  CustomTextField(
                    label: 'Email',
                    hint: 'Enter your Email',
                    prefixIcon: Icons.email_outlined,
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!value.contains('@')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 24),

                  // Phone Number Field
                  CustomTextField(
                    label: 'Phone Number (Optional)',
                    hint: 'Enter your Phone Number (Optional)',
                    prefixIcon: Icons.phone_outlined,
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                  ),

                  const SizedBox(height: 24),

                  CustomTextField(
                    label: 'Referral Code',
                    hint: 'Optional referral code',
                    prefixIcon: Icons.sell_outlined,
                    controller: _referralCodeController,
                  ),

                  const SizedBox(height: 24),

                  // Password Field
                  CustomTextField(
                    label: 'Password',
                    hint: 'Enter your Password',
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
                    hint: 'Confirm a Password',
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

                  const SizedBox(height: 16),

                  // Terms and Conditions
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: _agreeToTerms,
                        onChanged: (value) {
                          setState(() {
                            _agreeToTerms = value ?? false;
                          });
                        },
                        activeColor: AppColors.primaryBlue,
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: RichText(
                            text: const TextSpan(
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                              ),
                              children: [
                                TextSpan(text: 'I agree to the '),
                                TextSpan(
                                  text: 'Terms Conditions & Privacy Policy',
                                  style: TextStyle(
                                    color: AppColors.textLink,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                TextSpan(
                                  text: ' *',
                                  style: TextStyle(color: AppColors.textLink),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Sign Up Button
                  Obx(
                    () => PrimaryButton(
                      text: 'Sign up',
                      onPressed: _authController.isLoading.value
                          ? null
                          : _handleSignUp,
                      isLoading: _authController.isLoading.value,
                      borderRadius: 30,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Sign In Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Already have an account? ",
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => context.go('/login'),
                        child: const Text(
                          'Sign in Here',
                          style: TextStyle(
                            color: AppColors.textLink,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
