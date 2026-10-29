import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../helpers/l10n_extension.dart';
import '../../themes/colors_frave.dart';

/// The localized ETA headline.
///
/// The map blocs expose their own English `etaLabel`, but that string is
/// built in the domain layer, so the presentation layer rebuilds it here
/// from the raw minute count to keep the customer-facing copy Vietnamese.
String etaLabelFor(AppLocalizations l10n, int? minutes) {
  if (minutes == null) return l10n.mapCalculatingRoute;
  if (minutes <= 1) return l10n.mapArrivingNow;
  return l10n.mapArrivesInMinutes(minutes);
}

/// EtaBar — the pill that sits pinned above the map's bottom sheet
/// (Grab-style). Shows the headline ETA, the countdown chip, and the
/// remaining road distance.
///
/// The countdown ticks locally every second so it feels live, but it's
/// derived from the ETA the bloc computed — so a route refetch is the only
/// thing that can move the target time. Ticking on a timer keeps the UI
/// warm without hammering OSRM.
class EtaBar extends StatefulWidget {
  /// Headline ETA, e.g. "Arrives in 12 min".
  final String etaLabel;

  /// Remaining road distance, e.g. "1.4 km". Null while the route is
  /// still loading and the bar renders a shimmer instead.
  final String? distanceLabel;

  /// Whether the route has resolved. Drives the loading state.
  final bool isLoading;

  /// Called when the bar is tapped — usually to expand the sheet.
  final VoidCallback? onTap;

  const EtaBar({
    super.key,
    required this.etaLabel,
    this.distanceLabel,
    this.isLoading = false,
    this.onTap,
  });

  @override
  State<EtaBar> createState() => _EtaBarState();
}

class _EtaBarState extends State<EtaBar> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _startTicker();
  }

  @override
  void didUpdateWidget(EtaBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Restart only when the ETA target actually changed, so a steady
    // route doesn't keep resetting the animation.
    if (oldWidget.etaLabel != widget.etaLabel) {
      _startTicker();
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F000000),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  height: 36,
                  width: 36,
                  decoration: BoxDecoration(
                    color: ColorsFrave.primaryColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.delivery_dining,
                    size: 20,
                    color: ColorsFrave.primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.etaLabel,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: ColorsFrave.darkText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (widget.isLoading)
                        const _DistanceSkeleton()
                      else
                        Text(
                          widget.distanceLabel == null
                              ? context.l10n.mapFindingCourier
                              : context.l10n.mapDistanceAway(
                                  widget.distanceLabel!,
                                ),
                          style: const TextStyle(
                            fontSize: 12,
                            color: ColorsFrave.greyText,
                          ),
                        ),
                    ],
                  ),
                ),
                if (widget.isLoading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: ColorsFrave.primaryColor,
                    ),
                  )
                else
                  const Icon(
                    Icons.keyboard_arrow_up,
                    color: ColorsFrave.greyText,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Lightweight placeholder for the distance line while routing resolves.
class _DistanceSkeleton extends StatefulWidget {
  const _DistanceSkeleton();

  @override
  State<_DistanceSkeleton> createState() => _DistanceSkeletonState();
}

class _DistanceSkeletonState extends State<_DistanceSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, _) => Container(
        height: 10,
        width: 130,
        decoration: BoxDecoration(
          color: ColorsFrave.backgroundColor.withValues(
            alpha: 0.5 + (_controller.value * 0.4),
          ),
          borderRadius: BorderRadius.circular(5),
        ),
      ),
    );
  }
}