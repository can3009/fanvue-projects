import 'package:flutter/material.dart';

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.expand = false,
  });

  final String title;
  final Widget child;
  final List<Widget>? actions;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                if (actions != null) ...actions!,
              ],
            ),
            const SizedBox(height: 12),
            if (expand) Expanded(child: child) else child,
          ],
        ),
      ),
    );
  }
}
