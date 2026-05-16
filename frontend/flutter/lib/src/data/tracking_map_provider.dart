import 'live_tracking_models.dart';

abstract class IMapProvider {
  String get providerKey;

  Uri? staticMapSnapshotUrl({
    required ValleyGeoPoint courier,
    required ValleyGeoPoint pickup,
    required ValleyGeoPoint destination,
    required String accessToken,
    int width = 960,
    int height = 520,
  });
}

abstract class IRouteService {
  String get providerKey;

  Uri routeUrl({
    required ValleyGeoPoint origin,
    required ValleyGeoPoint destination,
    required String accessToken,
  });
}

class MapboxMapProvider implements IMapProvider, IRouteService {
  const MapboxMapProvider();

  @override
  String get providerKey => 'mapbox';

  @override
  Uri? staticMapSnapshotUrl({
    required ValleyGeoPoint courier,
    required ValleyGeoPoint pickup,
    required ValleyGeoPoint destination,
    required String accessToken,
    int width = 960,
    int height = 520,
  }) {
    if (accessToken.isEmpty) {
      return null;
    }
    final String pins = <String>[
      'pin-s-v+008053(${courier.longitude},${courier.latitude})',
      'pin-s-p+233d7e(${pickup.longitude},${pickup.latitude})',
      'pin-s-c+0e2d22(${destination.longitude},${destination.latitude})',
    ].join(',');
    final double centerLng =
        (courier.longitude + pickup.longitude + destination.longitude) / 3;
    final double centerLat =
        (courier.latitude + pickup.latitude + destination.latitude) / 3;
    final String path =
        '/styles/v1/mapbox/streets-v12/static/$pins/$centerLng,$centerLat,12/$widthx$height';
    return Uri.https('api.mapbox.com', path, <String, String>{
      'access_token': accessToken,
    });
  }

  @override
  Uri routeUrl({
    required ValleyGeoPoint origin,
    required ValleyGeoPoint destination,
    required String accessToken,
  }) {
    return Uri.https(
      'api.mapbox.com',
      '/directions/v5/mapbox/driving/${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}',
      <String, String>{
        'geometries': 'geojson',
        'overview': 'full',
        'access_token': accessToken,
      },
    );
  }
}

class OsmOsrmRouteService implements IRouteService {
  const OsmOsrmRouteService();

  @override
  String get providerKey => 'osm_osrm';

  @override
  Uri routeUrl({
    required ValleyGeoPoint origin,
    required ValleyGeoPoint destination,
    required String accessToken,
  }) {
    return Uri.https(
      'router.project-osrm.org',
      '/route/v1/driving/${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}',
      <String, String>{'overview': 'full', 'geometries': 'geojson'},
    );
  }
}

class ValleyMapProviderFactory {
  const ValleyMapProviderFactory();

  IMapProvider activeMapProvider({String provider = 'mapbox'}) =>
      const MapboxMapProvider();

  IRouteService activeRouteService({String provider = 'mapbox'}) {
    if (provider == 'osm_osrm') {
      return const OsmOsrmRouteService();
    }
    return const MapboxMapProvider();
  }
}
