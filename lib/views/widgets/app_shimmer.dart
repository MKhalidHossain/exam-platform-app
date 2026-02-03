import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class AppShimmer extends StatelessWidget {
  const AppShimmer({
    super.key,
    required this.child,
  });

  final Widget child;

  static Color get baseColor => Colors.grey[300]!;
  static Color get highlightColor => Colors.grey[100]!;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: child,
    );
  }
}

class AppShimmerBox extends StatelessWidget {
  const AppShimmerBox({
    super.key,
    this.width,
    this.height,
    this.radius = 6,
    this.shape = BoxShape.rectangle,
  });

  final double? width;
  final double? height;
  final double radius;
  final BoxShape shape;

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: shape,
          borderRadius:
              shape == BoxShape.circle ? null : BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

class AppShimmerCircle extends StatelessWidget {
  const AppShimmerCircle({
    super.key,
    required this.size,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    return AppShimmerBox(
      width: size,
      height: size,
      shape: BoxShape.circle,
    );
  }
}
