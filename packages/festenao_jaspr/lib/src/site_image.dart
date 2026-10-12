import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// An image with its size set (no layout shift), lazy loaded unless [eager],
/// with a 2x version when [src2x] is given.
Component siteImage({
  required String src,
  required String alt,
  required int width,
  required int height,
  String? src2x,
  String? classes,
  bool eager = false,
}) => img(
  src: src,
  alt: alt,
  width: width,
  height: height,
  classes: classes,
  loading: eager ? null : MediaLoading.lazy,
  attributes: {if (src2x != null) 'srcset': '$src 1x, $src2x 2x'},
);
