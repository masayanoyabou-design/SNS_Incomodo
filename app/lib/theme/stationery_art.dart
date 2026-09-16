import 'package:flutter/material.dart';

import '../models/stationery.dart';
import 'incomodo_theme.dart';

/// How each envelope design is drawn. Add an entry here when adding an
/// EnvelopeDesign (see StationeryDesign for the full steps).
class EnvelopeArt {
  const EnvelopeArt({
    required this.paper,
    required this.flap,
    required this.line,
    required this.ink,
  });

  /// The body of the envelope.
  final Color paper;

  /// The triangular flap, a shade off the body so it reads as a fold.
  final Color flap;

  /// Edges and folds.
  final Color line;

  /// The sender's name written on it.
  final Color ink;

  static EnvelopeArt of(EnvelopeDesign design) =>
      _art[design.id] ?? _art[EnvelopeDesign.defaultId]!;

  static const _art = <String, EnvelopeArt>{
    'plain': EnvelopeArt(
      paper: IncomodoColors.card,
      flap: IncomodoColors.paperAlt,
      line: IncomodoColors.inkFaintest,
      ink: IncomodoColors.ink,
    ),
  };
}

/// How each paper design is drawn. Add an entry here when adding a
/// PaperDesign.
class PaperArt {
  const PaperArt({
    required this.paper,
    required this.rule,
    required this.ink,
    this.ruled = true,
  });

  final Color paper;

  /// The ruled lines and the dashed margin.
  final Color rule;

  /// The writing.
  final Color ink;

  /// Plain paper leaves the lines off.
  final bool ruled;

  static PaperArt of(PaperDesign design) =>
      _art[design.id] ?? _art[PaperDesign.defaultId]!;

  static const _art = <String, PaperArt>{
    'ruled': PaperArt(
      paper: IncomodoColors.card,
      rule: IncomodoColors.inkFaintest,
      ink: IncomodoColors.ink,
    ),
  };
}
