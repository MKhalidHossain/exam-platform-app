import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import 'app_shimmer.dart';

class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double? width;
  final double? height;
  final EdgeInsets? padding;
  final bool useGradient;
  final double borderRadius;

  const PrimaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.width,
    this.height,
    this.padding,
    this.useGradient = false,
    this.borderRadius = 15,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? double.infinity,
      height: height ?? 56,
      child: useGradient
          ? Container(
              decoration: BoxDecoration(
                gradient: AppColors.buttonGradient,
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              child: ElevatedButton(
                onPressed: isLoading ? null : onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: AppColors.textWhite,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(borderRadius),
                  ),
                  elevation: 0,
                  padding: padding ?? const EdgeInsets.symmetric(horizontal: 24),
                ),
                child: isLoading
                    ? const AppShimmerCircle(size: 20)
                    : Text(
                        text,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textWhite,
                        ),
                      ),
              ),
            )
          : Container(
              decoration: BoxDecoration(
                color: AppColors.primaryBlue,
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              child: ElevatedButton(
                onPressed: isLoading ? null : onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: AppColors.textWhite,
                  disabledBackgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(borderRadius),
                  ),
                  elevation: 0,
                  padding: padding ?? const EdgeInsets.symmetric(horizontal: 24),
                ),
                child: isLoading
                    ? const AppShimmerCircle(size: 20)
                    : Text(
                        text,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textWhite,
                        ),
                      ),
              ),
            ),
    );
  }
}
