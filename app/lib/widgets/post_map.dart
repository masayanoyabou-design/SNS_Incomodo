import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/post.dart';
import '../models/post_map.dart';
import '../theme/map_tiles.dart';

/// The map itself. The only file that knows about flutter_map: replacing the
/// map package means rewriting this widget and nothing else.
class PostMap extends StatelessWidget {
  const PostMap({
    super.key,
    required this.pins,
    this.here,
    this.showTiles = true,
  });

  final List<PostPin> pins;
  final ({double latitude, double longitude})? here;

  /// Off in tests, which have no network to fetch map pictures from.
  final bool showTiles;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final points = [
      for (final p in pointsToShow(pins, here)) LatLng(p.latitude, p.longitude),
    ];

    return FlutterMap(
      options: MapOptions(
        // Tokyo Station until there is something of the user's to look at.
        initialCenter:
            points.isEmpty ? const LatLng(35.6812, 139.7671) : points.first,
        initialZoom: 16,
        initialCameraFit: points.length < 2
            ? null
            : CameraFit.coordinates(
                coordinates: points,
                padding: const EdgeInsets.all(64),
                maxZoom: 17,
              ),
        maxZoom: MapTiles.maxZoom,
        interactionOptions: const InteractionOptions(
          // Turning the map adds nothing here and is easy to do by accident.
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        if (showTiles)
          TileLayer(
            urlTemplate: MapTiles.urlTemplate,
            userAgentPackageName: MapTiles.userAgentPackageName,
            maxZoom: MapTiles.maxZoom,
          ),
        // How close you have to be to open letters — the part of the map
        // that matters most.
        CircleLayer(
          circles: [
            for (final pin in pins)
              CircleMarker(
                point: LatLng(pin.latitude, pin.longitude),
                radius: Post.unlockRadiusMeters,
                useRadiusInMeter: true,
                color: (pin.active ? colors.error : colors.tertiary)
                    .withValues(alpha: 0.12),
                borderColor: pin.active ? colors.error : colors.tertiary,
                borderStrokeWidth: 1.5,
              ),
          ],
        ),
        MarkerLayer(
          markers: [
            for (final pin in pins)
              Marker(
                point: LatLng(pin.latitude, pin.longitude),
                width: 40,
                height: 40,
                alignment: Alignment.topCenter,
                child: Semantics(
                  label: '${pin.name}、${pin.statusLabel}',
                  excludeSemantics: true,
                  child: Icon(
                    Icons.local_post_office,
                    size: 36,
                    color: pin.active ? colors.error : colors.tertiary,
                  ),
                ),
              ),
            if (here case final here?)
              Marker(
                point: LatLng(here.latitude, here.longitude),
                width: 22,
                height: 22,
                child: Semantics(
                  label: '現在地',
                  excludeSemantics: true,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SimpleAttributionWidget(source: Text(MapTiles.attribution)),
      ],
    );
  }
}
