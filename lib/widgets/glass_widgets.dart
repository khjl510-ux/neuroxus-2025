import 'dart:ui';
import 'package:flutter/material.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final Color color;
  final BorderRadius? borderRadius;
  final BoxBorder? border;
  final List<BoxShadow>? boxShadow;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 10.0,
    this.opacity = 0.2,
    this.color = Colors.white,
    this.borderRadius,
    this.border,
    this.boxShadow,
    this.padding = const EdgeInsets.all(10),
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        boxShadow: boxShadow,
        borderRadius: borderRadius,
      ),
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.zero,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: color.withOpacity(opacity),
              borderRadius: borderRadius,
              border: border ?? Border.all(color: Colors.white.withOpacity(0.3), width: 1.0),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class GlassButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Widget icon;
  final String? label;
  final double size;

  const GlassButton({
    super.key,
    required this.onPressed,
    required this.icon,
    this.label,
    this.size = 48.0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: GlassContainer(
        borderRadius: BorderRadius.circular(16),
        padding: const EdgeInsets.all(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
        child: label == null
          ? icon
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                icon,
                const SizedBox(width: 8),
                Text(label!, style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
      ),
    );
  }
}

class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget leading;
  final List<Widget> actions;
  final Widget? title;

  const GlassAppBar({
    super.key,
    required this.leading,
    required this.actions,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    return ExtendBodyBehindAppBar(
      child: Container(
        height: kToolbarHeight + MediaQuery.of(context).padding.top,
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
        child: GlassContainer(
          borderRadius: BorderRadius.zero,
          blur: 15,
          opacity: 0.6,
          border: const Border(bottom: BorderSide(color: Colors.white30, width: 0.5)),
          child: NavigationToolbar(
            leading: leading,
            middle: title,
            trailing: Row(mainAxisSize: MainAxisSize.min, children: actions),
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

// Helper wrapper to allow content behind the glass app bar
class ExtendBodyBehindAppBar extends StatelessWidget {
  final Widget child;
  const ExtendBodyBehindAppBar({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
