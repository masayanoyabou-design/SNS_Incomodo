import 'package:flutter/material.dart';

import '../models/stamp_design.dart';
import 'incomodo_theme.dart';

/// How a stamp design is drawn: a colored panel, the ink printed on it and
/// a motif. Provisional — MANUAL 23 has the designs being worked out later,
/// and this is the one file to replace when real artwork arrives.
class StampArt {
  const StampArt({
    required this.panel,
    required this.ink,
    required this.motif,
  });

  final Color panel;
  final Color ink;
  final IconData motif;

  static StampArt of(StampDesign design) =>
      _art[design.id] ?? _art[StampDesign.defaultId]!;

  static const _art = <String, StampArt>{
    'basic': StampArt(
      panel: IncomodoColors.redDeep,
      ink: IncomodoColors.paper,
      motif: Icons.mail_outline,
    ),
    'sakura': StampArt(
      panel: Color(0xFFE8B4B0),
      ink: Color(0xFF6B2E2A),
      motif: Icons.local_florist,
    ),
    'aozora': StampArt(
      panel: Color(0xFF9DB7C9),
      ink: Color(0xFF22394A),
      motif: Icons.cloud_outlined,
    ),
    'yoru': StampArt(
      panel: Color(0xFF2E3552),
      ink: Color(0xFFF3E9C8),
      motif: Icons.nights_stay_outlined,
    ),
    'konoha': StampArt(
      panel: IncomodoColors.moss,
      ink: IncomodoColors.paper,
      motif: Icons.eco_outlined,
    ),
  };
}
