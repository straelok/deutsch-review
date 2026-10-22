import 'package:flutter/material.dart';

abstract final class AppLayout {
  static const double contentMaxWidth = 1080;
  static const double wideContentMaxWidth = 1240;

  static EdgeInsets pagePadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return EdgeInsets.fromLTRB(
      width < 600 ? 16 : 24,
      20,
      width < 600 ? 16 : 24,
      32 + MediaQuery.paddingOf(context).bottom,
    );
  }
}

class ResponsiveBody extends StatelessWidget {
  const ResponsiveBody({
    required this.child,
    this.maxWidth = AppLayout.contentMaxWidth,
    this.padding,
    super.key,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding ?? AppLayout.pagePadding(context),
          child: child,
        ),
      ),
    );
  }
}
