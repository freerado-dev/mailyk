import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType, Rect;

import 'package:flutter/widgets.dart';

/// Triedy veľkosti okna (podľa Material 3). Ráta sa so skutočnou šírkou okna,
/// nie so zariadením, takže funguje aj v rozdelenej obrazovke a v DeX.
enum WindowClass { compact, medium, expanded }

WindowClass windowClassOf(double width) {
  if (width < 600) return WindowClass.compact;
  if (width < 840) return WindowClass.medium;
  return WindowClass.expanded;
}

/// Rozdelenie obrazovky pre Flex režim (telefón napoly zložený ako notebook).
class FlexSplit {
  const FlexSplit(this.top, this.gap);

  /// Výška hornej polovice (po pozíciu ohybu).
  final double top;

  /// Hrúbka ohybu (môže byť 0).
  final double gap;
}

/// Informácie o ohybe displeja (Galaxy Z Fold: Jetpack WindowManager).
class FoldInfo {
  const FoldInfo({this.tabletop = false, this.book = false, this.bounds = Rect.zero});

  /// Polozložený s vodorovným ohybom (Flex režim, „notebook“).
  final bool tabletop;

  /// Polozložený so zvislým ohybom („kniha“).
  final bool book;
  final Rect bounds;

  static FoldInfo of(BuildContext context) {
    final List<DisplayFeature> features = MediaQuery.of(context).displayFeatures;
    for (final f in features) {
      if (f.type != DisplayFeatureType.fold && f.type != DisplayFeatureType.hinge) {
        continue;
      }
      if (f.state != DisplayFeatureState.postureHalfOpened) continue;
      final horizontalLine = f.bounds.width > f.bounds.height;
      return FoldInfo(
        tabletop: horizontalLine,
        book: !horizontalLine,
        bounds: f.bounds,
      );
    }
    return const FoldInfo();
  }
}
