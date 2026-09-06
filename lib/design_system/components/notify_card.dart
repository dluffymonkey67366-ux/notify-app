import 'package:flutter/material.dart';
import '../notify_spacing.dart';
import '../notify_theme.dart';

/// Premium Notify Card Component with subtle borders and smooth feedback
class NotifyCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? borderColor;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;
  final bool isElevated;
  final Color? accentStripeColor;

  const NotifyCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.margin,
    this.borderColor,
    this.backgroundColor,
    this.borderRadius,
    this.isElevated = false,
    this.accentStripeColor,
  });

  @override
  State<NotifyCard> createState() => _NotifyCardState();
}

class _NotifyCardState extends State<NotifyCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.notifyTheme;
    final radius = widget.borderRadius ?? NotifyRadius.lg;

    final effectiveBg = widget.backgroundColor ??
        (_isHovered
            ? theme.cardElevatedBg
            : (widget.isElevated ? theme.cardElevatedBg : theme.cardBg));

    final effectiveBorder = widget.borderColor ??
        (_isHovered ? theme.accentAmber.withOpacity(0.4) : theme.borderSubtle);

    Widget content = Material(
      color: effectiveBg,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: Container(
        padding: widget.padding ?? NotifySpacing.paddingCard,
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: effectiveBorder, width: 1.0),
          boxShadow: widget.isElevated ? theme.cardShadows : null,
        ),
        child: widget.child,
      ),
    );

    if (widget.accentStripeColor != null) {
      content = ClipRRect(
        borderRadius: radius,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4.5,
                color: widget.accentStripeColor,
              ),
              Expanded(child: content),
            ],
          ),
        ),
      );
    }

    if (widget.onTap != null) {
      return Container(
        margin: widget.margin,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              transform: _isHovered
                  ? (Matrix4.identity()..translate(0, -2))
                  : Matrix4.identity(),
              child: content,
            ),
          ),
        ),
      );
    }

    return Container(
      margin: widget.margin,
      child: content,
    );
  }
}
