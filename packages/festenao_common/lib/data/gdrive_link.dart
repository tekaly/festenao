/// Google Drive links: the id of a folder or a file from what a user pastes,
/// and the Drive pages of an id.
///
/// The apps reading Drive through the api (`ObjectStorageGdrive` behind
/// `FestenaoObjectStorageHandler`, a folder shared with the service
/// account or public by link) take a folder from a pasted link.
library;

final _driveIdRegExp = RegExp(r'^[a-zA-Z0-9_-]{10,}$');

/// Extract a Google Drive folder/file id from a pasted text: either a bare
/// id or any drive url form:
/// - `https://drive.google.com/drive/folders/<id>?usp=sharing`
/// - `https://drive.google.com/drive/u/0/folders/<id>`
/// - `https://drive.google.com/file/d/<id>/view`
/// - `https://drive.google.com/open?id=<id>`
///
/// Returns null when no id can be extracted.
String? driveIdFromText(String text) {
  text = text.trim();
  if (text.isEmpty) {
    return null;
  }
  // Bare id.
  if (_driveIdRegExp.hasMatch(text)) {
    return text;
  }
  var uri = Uri.tryParse(text);
  if (uri == null || !uri.hasAuthority) {
    return null;
  }
  // ?id=<id> form.
  var queryId = uri.queryParameters['id'];
  if (queryId != null && _driveIdRegExp.hasMatch(queryId)) {
    return queryId;
  }
  // /folders/<id> or /d/<id> forms.
  var segments = uri.pathSegments;
  for (var i = 0; i < segments.length - 1; i++) {
    if (segments[i] == 'folders' || segments[i] == 'd') {
      var candidate = segments[i + 1];
      if (_driveIdRegExp.hasMatch(candidate)) {
        return candidate;
      }
    }
  }
  return null;
}

/// The Google Drive page of a folder, to open it in a browser.
String driveFolderUrl(String folderId) =>
    'https://drive.google.com/drive/folders/$folderId';

/// The Google Drive page of a file, to open it in a browser.
String driveFileViewUrl(String fileId) =>
    'https://drive.google.com/file/d/$fileId/view';

/// A direct download url of a Google Drive file.
///
/// Only works for a file anyone with the link can read (a public folder): the
/// request carries no credentials. Big files (above the virus scan limit) get
/// an interstitial page instead of the bytes.
String driveFileDownloadUrl(String fileId) =>
    'https://drive.google.com/uc?export=download&id=$fileId';
