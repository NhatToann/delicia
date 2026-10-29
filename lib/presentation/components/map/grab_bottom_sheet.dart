import 'package:flutter/material.dart';

import '../../themes/colors_frave.dart';

/// GrabBottomSheet — the draggable sheet that sits over the map.
///
/// Uses Flutter's built-in [DraggableScrollableSheet] rather than
/// `sliding_up_panel`: that package is pinned to a Dart 2 SDK constraint
/// (`<3.0.0`) and won't resolve on this project's Dart 3.13 toolchain.
/// The built-in widget gives us the same three-stop snap behaviour Grab
/// uses.
///
/// Sizes are fractions of the available height, so the collapsed stop can
/// peek just above the safe area to reveal the ETA bar while the expanded
/// stop reaches the top of the screen.
///
/// Drive it from outside with a [GlobalKey]:
/// ```dart
/// final sheetKey = GlobalKey<GrabBottomSheetState>();
/// sheetKey.currentState?.expand();
/// ```
class GrabBottomSheet extends StatefulWidget {
  /// Content rendered at every stop. Must be scrollable — the sheet drives
  /// [DraggableScrollableSheet]'s controller through it.
  final Widget Function(BuildContext context, ScrollController controller)
      builder;

  /// Header row pinned above the scrollable content (e.g. [EtaBar]).
  /// Kept out of [builder] so it stays put while the body scrolls.
  final Widget? pinnedHeader;

  final double minSize;
  final double initialSize;
  final double maxSize;

  /// Intermediate snap points. `initialSize` is always included.
  final List<double> snapSizes;

  const GrabBottomSheet({
    super.key,
    required this.builder,
    this.pinnedHeader,
    this.minSize = 0.12,
    this.initialSize = 0.32,
    this.maxSize = 0.86,
    this.snapSizes = const [0.32, 0.58],
  });

  @override
  State<GrabBottomSheet> createState() => GrabBottomSheetState();
}

class GrabBottomSheetState extends State<GrabBottomSheet> {
  final DraggableScrollableController _controller =
      DraggableScrollableController();

  /// Current size fraction, tracked via the notifier so the handle can
  /// show the right affordance (chevron up vs down).
  late final ValueNotifier<double> _currentSize;

  @override
  void initState() {
    super.initState();
    _currentSize = ValueNotifier<double>(widget.initialSize);
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _currentSize.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (!_controller.isAttached) return;
    final size = _controller.size;
    if ((size - _currentSize.value).abs() < 0.01) return;
    _currentSize.value = size;
  }

  /// Whether the sheet is currently open past its initial snap.
  bool get isExpanded => _currentSize.value > widget.initialSize + 0.02;

  /// Animates to the largest snap point.
  Future<void> expand() => _animateTo(widget.maxSize);

  /// Animates to the smallest snap point.
  Future<void> collapse() => _animateTo(widget.minSize);

  /// Bounces between the collapsed and expanded stops.
  Future<void> toggle() =>
      _animateTo(isExpanded ? widget.minSize : widget.maxSize);

  Future<void> _animateTo(double size) {
    if (!_controller.isAttached) return Future<void>.value();
    return _controller.animateTo(
      size.clamp(widget.minSize, widget.maxSize),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _dragBy(double deltaY) {
    if (!_controller.isAttached) return;
    final height = MediaQuery.sizeOf(context).height;
    if (height <= 0) return;
    _controller.jumpTo(
      (_controller.size - deltaY / height)
          .clamp(widget.minSize, widget.maxSize),
    );
  }

  void _settleAfterDrag(double velocityY) {
    if (!_controller.isAttached) return;
    final snaps = _effectiveSnaps;
    final projectedSize = (_controller.size - velocityY / 4000)
        .clamp(widget.minSize, widget.maxSize);
    final target = snaps.reduce(
      (a, b) => (a - projectedSize).abs() <= (b - projectedSize).abs() ? a : b,
    );
    _animateTo(target);
  }

  List<double> get _effectiveSnaps {
    final values = <double>{
      widget.minSize,
      widget.initialSize,
      widget.maxSize,
      ...widget.snapSizes,
    }
        .map((s) => s.clamp(widget.minSize, widget.maxSize))
        .toList()
      ..sort();
    return values;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      controller: _controller,
      initialChildSize: widget.initialSize,
      minChildSize: widget.minSize,
      maxChildSize: widget.maxSize,
      snap: true,
      snapSizes: _effectiveSnaps,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            boxShadow: [
              BoxShadow(
                color: Color(0x26000000),
                blurRadius: 18,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              ValueListenableBuilder<double>(
                valueListenable: _currentSize,
                builder: (context, size, _) => GrabHandle(
                  isExpanded: size > widget.initialSize + 0.02,
                  onTap: toggle,
                  onDrag: _dragBy,
                  onDragEnd: _settleAfterDrag,
                ),
              ),
              if (widget.pinnedHeader != null) widget.pinnedHeader!,
              Expanded(child: widget.builder(context, scrollController)),
            ],
          ),
        );
      },
    );
  }
}

/// The grab handle — a short pill centred at the top of the sheet. Doubles
/// as a tap target so the sheet can be toggled without hunting for the
/// screen edge.
class GrabHandle extends StatelessWidget {
  final bool isExpanded;
  final VoidCallback onTap;
  final ValueChanged<double> onDrag;
  final ValueChanged<double> onDragEnd;

  const GrabHandle({
    super.key,
    required this.isExpanded,
    required this.onTap,
    required this.onDrag,
    required this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onVerticalDragUpdate: (details) => onDrag(details.primaryDelta ?? 0),
      onVerticalDragEnd: (details) => onDragEnd(details.primaryVelocity ?? 0),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 5,
              width: 42,
              decoration: BoxDecoration(
                color: ColorsFrave.greyText.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 6),
            AnimatedRotation(
              turns: isExpanded ? 1 : 0,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: Icon(
                Icons.keyboard_arrow_down,
                size: 18,
                color: ColorsFrave.greyText.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
