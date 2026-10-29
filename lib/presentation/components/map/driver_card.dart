import 'package:flutter/material.dart';

import '../../../domain/models/driver_info.dart';
import '../../helpers/l10n_extension.dart';
import '../../themes/colors_frave.dart';

/// DriverCard — the courier summary at the top of the tracking sheet.
///
/// Deliberately tolerant of a null [driver]: the client can open the live
/// map a beat before the realtime layer tells us who the courier is, and
/// an empty row reads better than a crash.
class DriverCard extends StatelessWidget {
  final DriverInfo? driver;

  /// Shown under the name when we have no assigned courier yet.
  final String? fallbackSubtitle;

  /// Invoked by the call / message affordances.
  final VoidCallback? onCall;

  final VoidCallback? onMessage;

  const DriverCard({
    super.key,
    this.driver,
    this.fallbackSubtitle,
    this.onCall,
    this.onMessage,
  });

  @override
  Widget build(BuildContext context) {
    final info = driver;

    return Row(
      children: [
        _Avatar(initials: _initialsOf(info)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                info?.name ?? context.l10n.driverCourierTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: ColorsFrave.darkText,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                info == null
                    ? (fallbackSubtitle ?? context.l10n.driverOnlyMoment)
                    : '${_vehicleLabel(context, info.vehicle)} · ${info.plate}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: ColorsFrave.greyText,
                ),
              ),
            ],
          ),
        ),
        if (info != null) ...[
          if (info.rating > 0) _RatingBadge(rating: info.rating),
          const SizedBox(width: 8),
        ],
        _ActionButton(
          icon: Icons.phone_outlined,
          tooltip: context.l10n.actionCallCourier,
          onPressed: info == null ? null : onCall,
        ),
        const SizedBox(width: 6),
        _ActionButton(
          icon: Icons.chat_bubble_outline,
          tooltip: context.l10n.actionMessageCourier,
          onPressed: info == null ? null : onMessage,
        ),
      ],
    );
  }

  /// Vietnamese label for the courier's vehicle.
  static String _vehicleLabel(BuildContext context, DriverVehicle vehicle) {
    switch (vehicle) {
      case DriverVehicle.motorbike:
        return context.l10n.driverVehicleMotorbike;
      case DriverVehicle.car:
        return context.l10n.driverVehicleCar;
      case DriverVehicle.bicycle:
        return context.l10n.driverVehicleBicycle;
    }
  }

  /// Falls back to a generic glyph when the name isn't available yet.
  static String _initialsOf(DriverInfo? info) {
    final name = info?.name.trim() ?? '';
    if (name.isEmpty) return '';
    final parts = name
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }
}

class _Avatar extends StatelessWidget {
  final String initials;

  const _Avatar({required this.initials});

  @override
  Widget build(BuildContext context) {
    final hasInitials = initials.isNotEmpty;
    return Container(
      height: 46,
      width: 46,
      decoration: BoxDecoration(
        color: ColorsFrave.primaryColor.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(
          color: ColorsFrave.primaryColor.withValues(alpha: 0.25),
        ),
      ),
      alignment: Alignment.center,
      child: hasInitials
          ? Text(
              initials,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: ColorsFrave.primaryColor,
              ),
            )
          : const Icon(
              Icons.person_outline,
              color: ColorsFrave.primaryColor,
              size: 24,
            ),
    );
  }
}

class _RatingBadge extends StatelessWidget {
  final double rating;

  const _RatingBadge({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: ColorsFrave.successColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star, size: 13, color: ColorsFrave.successColor),
          const SizedBox(width: 3),
          Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: ColorsFrave.successColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _ActionButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: ColorsFrave.backgroundColor,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox(
            height: 38,
            width: 38,
            child: Icon(
              icon,
              size: 19,
              color: onPressed == null
                  ? ColorsFrave.greyText.withValues(alpha: 0.4)
                  : ColorsFrave.primaryColor,
            ),
          ),
        ),
      ),
    );
  }
}
