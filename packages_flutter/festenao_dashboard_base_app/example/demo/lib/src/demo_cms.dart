import 'package:festenao_cms_flutter/festenao_cms_flutter.dart';

export 'demo_cms_data.dart';

/// The items of the (pretend) festival database the pages present: what the
/// "Presents" picker of the page editor offers.
const demoCmsLinkableItems = [
  CmsLinkableItem(
    kind: cmsItemKindEvent,
    id: 'opening-night',
    name: 'Opening night concert',
  ),
  CmsLinkableItem(
    kind: cmsItemKindEvent,
    id: 'closing-parade',
    name: 'Closing parade',
  ),
  CmsLinkableItem(
    kind: cmsItemKindLocation,
    id: 'main-stage',
    name: 'The main stage',
  ),
  CmsLinkableItem(
    kind: cmsItemKindActivity,
    id: 'night-workshops',
    name: 'Night workshops',
  ),
  CmsLinkableItem(
    kind: cmsItemKindOffer,
    id: 'weekend-pass',
    name: 'Weekend pass',
  ),
];
