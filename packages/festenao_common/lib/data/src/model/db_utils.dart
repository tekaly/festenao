import 'package:festenao_common/data/festenao_db.dart';

DbArtist? dbArtistFromSnapshot(
  RecordSnapshot<String, Map<String, Object?>>? snapshot,
) => snapshot?.cv<DbArtist>();

class AttributeInfo {
  // artist:<xxx>
  String? artistId;

  // location:<xxx>
  String? locationInfoId;

  // Containing https://goo.gl/maps/
  String? mapLink;

  /// Scheme mailto:
  String? email;

  var noLinkFound = false;

  @override
  String toString() {
    var sb = StringBuffer();
    void sbAdd(String text) {
      if (sb.isNotEmpty) {
        sb.write(', ');
      }
      sb.write(text);
    }

    if (locationInfoId != null) {
      sbAdd('location: $locationInfoId');
    }
    if (mapLink != null) {
      sbAdd('mapLink: $mapLink');
    }
    if (artistId != null) {
      sbAdd('artist: $artistId');
    }
    return sb.toString();
  }
}

extension AttributeInfoExt on CvAttribute {
  AttributeInfo getAttributeInfo() {
    String? locationInfoId;
    String? artistId;
    String? mapLink;
    String? email;
    var noLinkFound = false;
    var attrValue = value.v;
    var attributeInfo = AttributeInfo();

    if (attrValue != null) {
      if (attrValue.startsWith('https://goo.gl/maps/')) {
        mapLink = attrValue;
      } else {
        try {
          var uri = Uri.parse(attrValue);
          if (uri.scheme == schemeLocation) {
            locationInfoId = uri.path;
          } else if (uri.scheme == schemeArtist) {
            artistId = uri.path;
          } else if (uri.scheme == schemeMailto) {
            email = uri.path;
          } else if (uri.scheme == '') {
            noLinkFound = true;
          }
        } catch (_) {
          noLinkFound = true;
        }
      }
    }

    return attributeInfo
      ..locationInfoId = locationInfoId
      ..mapLink = mapLink
      ..artistId = artistId
      ..email = email
      ..noLinkFound = noLinkFound;
  }
}
