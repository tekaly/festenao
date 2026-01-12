import 'package:festenao_common/data/festenao_db.dart';

/// location:`<location_id>`
const schemeLocation = 'location';

/// info scheme
const schemeInfo = 'info';

/// artist scheme
const schemeArtist = 'artist';

/// mailto scheme
const schemeMailto = 'mailto';

/// List of supported attribute schemes.
const attributeSchemes = [schemeLocation, schemeArtist, schemeInfo];

/// Facebook attribute type.
const attributeTypeFacebook = 'facebook';

/// Instagram attribute type.
const attributeTypeInstagram = 'instagram';

/// Car attribute type.
const attributeTypeCar = 'car';

/// Bus attribute type.
const attributeTypeBus = 'bus';

/// Web attribute type.
const attributeTypeWeb = 'web';

/// Youtube attribute type.
const attributeTypeYoutube = 'youtube';

/// Map attribute type.
const attributeTypeMap = 'map';

/// Tel attribute type.
const attributeTypeTel = 'tel';

/// Email attribute type.
const attributeTypeEmail = 'email';

/// Audio attribute type.
const attributeTypeAudio = 'audio';

/// Video attribute type.
const attributeTypeVideo = 'video';

/// Location attribute type.
const attributeTypeLocation = 'location';

/// Price attribute type.
const attributeTypePrice = 'price';

/// Ticket attribute type.
const attributeTypeTicket = 'ticket';

/// Artist attribute type.
const attributeTypeArtist = 'artist';

/// Internal link attribute type.
const attributeTypeLink = 'link'; // internal link

/// List of all supported attribute types.
const attributeTypes = [
  attributeTypeWeb,
  attributeTypeAudio,
  attributeTypeFacebook,
  attributeTypeVideo,
  attributeTypeMap,
  attributeTypeLocation,
  attributeTypePrice,
  attributeTypeTicket,
  attributeTypeEmail,
  attributeTypeTel,
  attributeTypeArtist,
  attributeTypeLink,
  attributeTypeInstagram,
  attributeTypeCar,
  attributeTypeBus,
];

/// Returns the artist ID from the URL if it matches the artist scheme.
String? attrGetArtistId(String url) {
  if (url.startsWith('$schemeArtist:')) {
    return url.substring(schemeArtist.length + 1);
  }
  return null;
}

/// Returns the info ID from the URL if it matches the info scheme.
String? attrGetInfoId(String url) {
  if (url.startsWith('$schemeInfo:')) {
    return url.substring(schemeInfo.length + 1);
  }
  return null;
}

/// Makes an attribute URL from an artist ID.
String attrMakeFromArtistId(String artistId) {
  return '$schemeArtist:$artistId';
}

/// Makes an attribute URL from an info ID.
String attrMakeFromInfoId(String infoId) {
  return '$schemeInfo:$infoId';
}

/// Makes a location attribute URL from an info ID.
String attrMakeLocationFromInfoId(String infoId) {
  return '$schemeLocation:$infoId';
}

/// Link or attribute
class CvAttribute extends CvModelBase {
  /// The name displayed
  final name = CvField<String>('name');

  /// Typically url
  final value = CvField<String>('value');

  /// Type, custom attribute are prefixed with custom_
  final type = CvField<String>('type');

  @override
  List<CvField> get fields => [name, value, type];
}

/// Extension on [CvAttribute].
extension CvAttributeExt on CvAttribute {
  /// The value or null if not set.
  String? get valueOrNull => value.v;

  /// Gets the info ID from the value.
  String? getInfoId() => valueOrNull == null ? null : attrGetInfoId(value.v!);
}
