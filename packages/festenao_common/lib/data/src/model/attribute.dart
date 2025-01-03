import 'package:festenao_common/data/festenao_db.dart';

/// location:`<location_id>`
const schemeLocation = 'location';
const schemeInfo = 'info';
const schemeArtist = 'artist';

const schemeMailto = 'mailto';

const attributeSchemes = [schemeLocation, schemeArtist, schemeInfo];
const attributeTypeFacebook = 'facebook';
const attributeTypeInstagram = 'instagram';
const attributeTypeCar = 'car';
const attributeTypeBus = 'bus';
const attributeTypeWeb = 'web';
const attributeTypeYoutube = 'youtube';
const attributeTypeMap = 'map';
const attributeTypeTel = 'tel';
const attributeTypeEmail = 'email';
const attributeTypeAudio = 'audio';
const attributeTypeVideo = 'video';
const attributeTypeLocation = 'location';
const attributeTypePrice = 'price';
const attributeTypeTicket = 'ticket';
const attributeTypeArtist = 'artist';
const attributeTypeLink = 'link'; // internal link
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

String? attrGetArtistId(String url) {
  if (url.startsWith('$articleKindArtist:')) {
    return url.substring(articleKindArtist.length + 1);
  }
  return null;
}

String? attrGetInfoId(String url) {
  if (url.startsWith('$articleKindInfo:')) {
    return url.substring(articleKindInfo.length + 1);
  }
  return null;
}

String attrMakeFromArtistId(String artistId) {
  return '$articleKindArtist:$artistId';
}

String attrMakeFromInfoId(String infoId) {
  return '$articleKindInfo:$infoId';
}

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

extension CvAttributeExt on CvAttribute {
  String? get valueOrNull => value.v;
  String? getInfoId() => valueOrNull == null ? null : attrGetInfoId(value.v!);
}
