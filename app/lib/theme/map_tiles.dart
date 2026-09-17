/// Where the map's pictures come from. Changing provider — to MapTiler or
/// another host with a free tier once there are real users — is a change to
/// this file alone (see MANUAL 39).
///
/// OpenStreetMap's own tile servers are fine while testing, but their usage
/// policy doesn't allow heavy use by an app, and asks that every request
/// names the app and that the map credits OpenStreetMap.
abstract final class MapTiles {
  static const urlTemplate = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// Sent with every tile request, as the tile policy requires.
  static const userAgentPackageName = 'app.incomodo.incomodo';

  static const attribution = 'OpenStreetMap contributors';

  static const maxZoom = 19.0;
}
