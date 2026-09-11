import 'dart:convert';

/// Schema.org structured data (JSON-LD) helpers.
///
/// Each builder returns a plain map ready to be serialized in a
/// `<script type="application/ld+json">` block; null values are dropped so a
/// builder can be called with whatever is known.
class CmsStructuredData {
  CmsStructuredData._();

  static Map<String, Object?> _clean(Map<String, Object?> map) {
    var result = <String, Object?>{};
    for (var entry in map.entries) {
      var value = entry.value;
      if (value == null) {
        continue;
      }
      if (value is Map<String, Object?>) {
        value = _clean(value);
        if (value.isEmpty) {
          continue;
        }
      } else if (value is List) {
        value = value.where((item) => item != null).toList();
        if (value.isEmpty) {
          continue;
        }
      } else if (value is String && value.isEmpty) {
        continue;
      }
      result[entry.key] = value;
    }
    return result;
  }

  /// A postal address.
  static Map<String, Object?> postalAddress({
    String? streetAddress,
    String? postalCode,
    String? locality,
    String? region,
    String? country,
  }) => _clean({
    '@type': 'PostalAddress',
    'streetAddress': streetAddress,
    'postalCode': postalCode,
    'addressLocality': locality,
    'addressRegion': region,
    'addressCountry': country,
  });

  /// Geo coordinates.
  static Map<String, Object?> geo({
    required double latitude,
    required double longitude,
  }) => {
    '@type': 'GeoCoordinates',
    'latitude': latitude,
    'longitude': longitude,
  };

  /// A place (a location page).
  static Map<String, Object?> place({
    required String name,
    String? description,
    String? url,
    List<String>? images,
    Map<String, Object?>? address,
    Map<String, Object?>? geo,
    String? telephone,
    String type = 'Place',
  }) => _clean({
    '@context': 'https://schema.org',
    '@type': type,
    'name': name,
    'description': description,
    'url': url,
    'image': images,
    'address': address,
    'geo': geo,
    'telephone': telephone,
  });

  /// An offer (a price).
  static Map<String, Object?> offer({
    required num price,
    required String currency,
    String? url,
    String? availability,
    String? validFrom,
  }) => _clean({
    '@type': 'Offer',
    'price': price,
    'priceCurrency': currency,
    'url': url,
    'availability': availability,
    'validFrom': validFrom,
  });

  /// An event (a dated activity).
  ///
  /// [startDate]/[endDate] are ISO 8601 strings, [location] a [place] map (or
  /// a plain name), [offers] a list of [offer] maps.
  static Map<String, Object?> event({
    required String name,
    required String startDate,
    String? endDate,
    String? description,
    String? url,
    List<String>? images,
    Object? location,
    List<Map<String, Object?>>? offers,
    String? performer,
    String? organizer,
    String eventStatus = 'https://schema.org/EventScheduled',
    String eventAttendanceMode =
        'https://schema.org/OfflineEventAttendanceMode',
  }) => _clean({
    '@context': 'https://schema.org',
    '@type': 'Event',
    'name': name,
    'startDate': startDate,
    'endDate': endDate,
    'description': description,
    'url': url,
    'image': images,
    'location': location is String
        ? {'@type': 'Place', 'name': location}
        : location,
    'offers': offers,
    'performer': performer == null
        ? null
        : {'@type': 'PerformingGroup', 'name': performer},
    'organizer': organizer == null
        ? null
        : {'@type': 'Organization', 'name': organizer},
    'eventStatus': eventStatus,
    'eventAttendanceMode': eventAttendanceMode,
  });

  /// A product or service (an offer page).
  static Map<String, Object?> product({
    required String name,
    String? description,
    String? url,
    List<String>? images,
    Map<String, Object?>? offer,
    String type = 'Product',
  }) => _clean({
    '@context': 'https://schema.org',
    '@type': type,
    'name': name,
    'description': description,
    'url': url,
    'image': images,
    'offers': offer,
  });

  /// A plain web page.
  static Map<String, Object?> webPage({
    required String name,
    String? description,
    String? url,
    String? datePublished,
    String? dateModified,
    List<String>? images,
  }) => _clean({
    '@context': 'https://schema.org',
    '@type': 'WebPage',
    'name': name,
    'description': description,
    'url': url,
    'datePublished': datePublished,
    'dateModified': dateModified,
    'image': images,
  });

  /// Serialize [data] for a `<script type="application/ld+json">` block.
  ///
  /// `</` is escaped so a value can never close the script tag.
  static String toJsonLd(Object data) =>
      jsonEncode(data).replaceAll('</', r'<\/');
}
