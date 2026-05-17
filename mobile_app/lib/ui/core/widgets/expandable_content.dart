import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ExpandableBody extends StatelessWidget {
  const ExpandableBody({
    required this.expanded,
    required this.child,
    super.key,
  });

  final bool expanded;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return expanded ? child : const SizedBox.shrink();
  }
}

class CollapseIconButton extends StatelessWidget {
  const CollapseIconButton({
    required this.expanded,
    required this.onPressed,
    this.tooltip,
    super.key,
  });

  final bool expanded;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return IconButton(
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
      splashRadius: 18,
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(
        expanded ? Icons.expand_less : Icons.expand_more,
        color: palette.textSecondary,
        size: 18,
      ),
    );
  }
}
