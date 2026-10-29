import 'package:flutter/material.dart';

import '../../../domain/models/driver_info.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../helpers/l10n_extension.dart';
import '../../themes/colors_frave.dart';

/// OrderTimeline — vertical 5-step progress strip shown inside the
/// tracking bottom sheet.
///
/// Steps that come before [activeStage] render with a green tick and the
/// brand green connector drawn behind them. The active step animates with
/// a subtle pulse so the user can find the current state at a glance, and
/// everything after it stays greyed out.
class OrderTimeline extends StatelessWidget {
  final OrderStage activeStage;

  /// Per-step timestamps shown next to the label. Skipped when null.
  final Map<OrderStage, DateTime?>? timestamps;

  const OrderTimeline({
    super.key,
    required this.activeStage,
    this.timestamps,
  });

  @override
  Widget build(BuildContext context) {
    final steps = OrderStage.values;
    final activeIndex = activeStage.stepIndex;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.stageProgress,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: ColorsFrave.darkText,
          ),
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < steps.length; i++)
          _TimelineRow(
            step: steps[i],
            state: _stateForStep(i, activeIndex),
            isLast: i == steps.length - 1,
            timestamp: timestamps?[steps[i]],
          ),
      ],
    );
  }

  /// Vietnamese label for a stage — the raw enum only knows English.
  static String _labelFor(OrderStage stage, AppLocalizations l10n) =>
      switch (stage) {
        OrderStage.placed => l10n.stagePlaced,
        OrderStage.preparing => l10n.stagePreparing,
        OrderStage.dispatched => l10n.stageDispatched,
        OrderStage.onTheWay => l10n.stageOnTheWay,
        OrderStage.delivered => l10n.stageDelivered,
      };

  /// Vietnamese description for a stage.
  static String _descriptionFor(OrderStage stage, AppLocalizations l10n) =>
      switch (stage) {
        OrderStage.placed => l10n.stagePlacedDescription,
        OrderStage.preparing => l10n.stagePreparingDescription,
        OrderStage.dispatched => l10n.stageDispatchedDescription,
        OrderStage.onTheWay => l10n.stageOnTheWayDescription,
        OrderStage.delivered => l10n.stageDeliveredDescription,
      };

  static _StepState _stateForStep(int stepIndex, int activeIndex) {
    if (stepIndex < activeIndex) return _StepState.done;
    if (stepIndex == activeIndex) return _StepState.active;
    return _StepState.upcoming;
  }
}

enum _StepState { done, active, upcoming }

class _TimelineRow extends StatelessWidget {
  final OrderStage step;
  final _StepState state;
  final bool isLast;
  final DateTime? timestamp;

  const _TimelineRow({
    required this.step,
    required this.state,
    required this.isLast,
    this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      _StepState.done => ColorsFrave.successColor,
      _StepState.active => ColorsFrave.primaryColor,
      _StepState.upcoming => ColorsFrave.greyText,
    };
    final labelColor = state == _StepState.upcoming
        ? ColorsFrave.greyText
        : ColorsFrave.darkText;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                const SizedBox(height: 2),
                _Dot(state: state, color: color),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: state == _StepState.done || state == _StepState.active
                            ? ColorsFrave.successColor.withValues(alpha: 0.4)
                            : ColorsFrave.backgroundColor,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          OrderTimeline._labelFor(step, context.l10n),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: state == _StepState.active
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: labelColor,
                          ),
                        ),
                      ),
                      if (timestamp != null)
                        Text(
                          _formatTimestamp(timestamp!),
                          style: const TextStyle(
                            fontSize: 11,
                            color: ColorsFrave.greyText,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    OrderTimeline._descriptionFor(step, context.l10n),
                    style: const TextStyle(
                      fontSize: 12,
                      color: ColorsFrave.greyText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatTimestamp(DateTime dt) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}

class _Dot extends StatelessWidget {
  final _StepState state;
  final Color color;

  const _Dot({required this.state, required this.color});

  @override
  Widget build(BuildContext context) {
    if (state == _StepState.done) {
      return Container(
        height: 22,
        width: 22,
        decoration: BoxDecoration(
          color: ColorsFrave.successColor,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check, size: 14, color: Colors.white),
      );
    }
    if (state == _StepState.active) {
      return Container(
        height: 22,
        width: 22,
        decoration: BoxDecoration(
          color: ColorsFrave.primaryColor.withValues(alpha: 0.15),
          shape: BoxShape.circle,
          border: Border.all(color: ColorsFrave.primaryColor, width: 2),
        ),
        child: Center(
          child: Container(
            height: 8,
            width: 8,
            decoration: const BoxDecoration(
              color: ColorsFrave.primaryColor,
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
    }
    return Container(
      height: 22,
      width: 22,
      decoration: BoxDecoration(
        color: ColorsFrave.backgroundColor,
        shape: BoxShape.circle,
        border: Border.all(color: ColorsFrave.backgroundColor, width: 2),
      ),
    );
  }
}