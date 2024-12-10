import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class UINavigationBar extends StatelessWidget implements PreferredSizeWidget {
  static FlutterView view =
      WidgetsBinding.instance.platformDispatcher.views.first;
  static double statusBarHeight = view.padding.top / view.devicePixelRatio;
  static double screenWidth = view.physicalSize.width / view.devicePixelRatio;
  static double toolbarHeight = 44;

  const UINavigationBar({
    super.key,
    this.decoration,
    this.backgroundColor,
    this.left,
    this.title,
    this.middle,
    this.right,
    this.clickBack,
    this.systemOverlayStyle,
    this.titleTextStyle,
    this.leadingColor,
    this.safeArea = true,
  });

  final Color? backgroundColor;
  final Decoration? decoration;
  final Widget? left;
  final Widget? middle;
  final Widget? right;
  final String? title;
  final VoidCallback? clickBack;
  final SystemUiOverlayStyle? systemOverlayStyle;
  final TextStyle? titleTextStyle;
  final Color? leadingColor;
  final bool safeArea;

  @override
  Size get preferredSize => Size(
        screenWidth,
        (safeArea ? statusBarHeight : 0) + toolbarHeight,
      );

  Widget renderLeftWidget(BuildContext context) {
    if (left == null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (clickBack == null) {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else if (Navigator.of(context, rootNavigator: true).canPop()) {
              Navigator.of(context, rootNavigator: true).pop();
            } else {
              debugPrint('没有上一页');
            }
          } else {
            clickBack!();
          }
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12.0, 14.0, 19.0, 14.0),
          child: Icon(
            Icons.arrow_back_ios,
            size: 24.0,
            color: leadingColor,
          ),
        ),
      );
    }
    return left!;
  }

  Widget renderMiddleWidget(BuildContext context) {
    if (middle == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 80),
        child: Text(
          title ?? '',
          overflow: TextOverflow.ellipsis,
          style: titleTextStyle,
        ),
      );
    }
    return middle!;
  }

  Widget renderRightWidget(BuildContext context) {
    if (right == null) {
      return const Text('');
    }
    return right!;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final top = statusBarHeight == 0 ? 20.0 : statusBarHeight;
    final tempDecoration = decoration ?? BoxDecoration(color: backgroundColor);
    final child = DecoratedBox(
      decoration: tempDecoration,
      child: Padding(
        padding: EdgeInsets.fromLTRB(0, safeArea ? top : 0, 0, 0),
        child: SizedBox(
          width: size.width,
          height: toolbarHeight,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(left: 0.0, child: renderLeftWidget(context)),
              renderMiddleWidget(context),
              Positioned(
                right: 0.0,
                child: renderRightWidget(context),
              ),
            ],
          ),
        ),
      ),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemOverlayStyle ?? getSystemUiOverlayStyle(context),
      child: child,
    );
  }

  static SystemUiOverlayStyle getSystemUiOverlayStyle(
    BuildContext context, {
    Color lightSystemNavigationBarColor = Colors.white,
    Color darkSystemNavigationBarColor = Colors.black,
  }) {
    final systemUiOverlayStyle = context.isDark
        ? SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: darkSystemNavigationBarColor,
            systemNavigationBarIconBrightness: Brightness.light,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          )
        : SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: lightSystemNavigationBarColor,
            systemNavigationBarIconBrightness: Brightness.light,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          );
    return systemUiOverlayStyle;
  }
}

extension ThemeGetter on BuildContext {
  ThemeData get theme => Theme.of(this);

  bool get isDark => theme.brightness == Brightness.dark;
}
