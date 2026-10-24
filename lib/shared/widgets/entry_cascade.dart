import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// Entry animation from design.md: each child fades in and rises 16px over
/// 420ms, staggered by 80ms.
class EntryCascade extends StatefulWidget {
  const EntryCascade({
    super.key,
    required this.children,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
  });

  final List<Widget> children;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  State<EntryCascade> createState() => _EntryCascadeState();
}

class _EntryCascadeState extends State<EntryCascade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  Duration get _total =>
      AppMotion.entry + AppMotion.stagger * (widget.children.length - 1);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _total)..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: widget.crossAxisAlignment,
        children: widget.children,
      );
    }
    final totalMs = _total.inMilliseconds;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: widget.crossAxisAlignment,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          _EntryItem(
            animation: CurvedAnimation(
              parent: _controller,
              curve: Interval(
                AppMotion.stagger.inMilliseconds * i / totalMs,
                (AppMotion.stagger.inMilliseconds * i +
                        AppMotion.entry.inMilliseconds) /
                    totalMs,
                curve: AppMotion.curve,
              ),
            ),
            child: widget.children[i],
          ),
      ],
    );
  }
}

class _EntryItem extends AnimatedWidget {
  const _EntryItem({required Animation<double> animation, required this.child})
    : super(listenable: animation);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final value = (listenable as Animation<double>).value;
    return Opacity(
      opacity: value,
      child: Transform.translate(
        offset: Offset(0, AppMotion.entryOffset * (1 - value)),
        child: child,
      ),
    );
  }
}
