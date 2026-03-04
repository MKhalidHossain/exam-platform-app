import 'package:flutter/material.dart';

import 'api_disclaimer_dialog.dart';

class ApiDisclaimerSection extends StatelessWidget {
  const ApiDisclaimerSection({
    super.key,
    this.bottomSpacing = 0,
    this.baseStyle = const TextStyle(
      fontSize: 12.5,
      color: Color(0xFF6B7280),
      fontWeight: FontWeight.w500,
    ),
    this.linkStyle = const TextStyle(
      color: Color(0xFF2F6DE0),
      fontWeight: FontWeight.w600,
    ),
  });

  final double bottomSpacing;
  final TextStyle baseStyle;
  final TextStyle linkStyle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text.rich(
            TextSpan(
              text: 'Not affiliated with or endorsed by API. ',
              style: baseStyle,
              children: <InlineSpan>[
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: GestureDetector(
                    onTap: () => showApiDisclaimerDialog(context),
                    child: Text('See full disclaimer.', style: linkStyle),
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          if (bottomSpacing > 0) SizedBox(height: bottomSpacing),
        ],
      ),
    );
  }
}
