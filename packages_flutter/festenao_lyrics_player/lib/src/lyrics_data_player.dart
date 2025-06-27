import 'package:festenao_common_flutter/common_utils_widget.dart';
import 'package:festenao_lyrics_player/src/lyrics_data_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart'; // Import the package
import 'package:tekaly_lyrics/utils/lyrics_data_located.dart';
import 'package:tekartik_common_utils/stream/stream_join.dart';

/// LyricsDataPlayerMetaSizeInfo
class LyricsDataPlayerMetaSizeInfo {
  /// Size
  final Size size;

  /// width
  double get width => size.width;

  /// height
  double get height => size.height;

  /// aspect ratio
  double get aspectRatio => size.width / size.height;

  /// font size
  double get fontSize => size.width * 0.05;

  /// Constructor
  LyricsDataPlayerMetaSizeInfo({required this.size});
}

/// LyricsDataPlayerStyle, font size is ignored
class LyricsDataPlayerStyle {
  /// On text style
  final TextStyle onTextStyle;

  /// Off text style
  final TextStyle offTextStyle;

  /// Text scaler (none by default), font size is 1/20th of the available width
  final TextScaler textScaler;

  /// Line count to be displayed
  final int? lineCount;

  /// Scroll duration
  final Duration scrollDuration;

  /// Constructor
  LyricsDataPlayerStyle({
    required this.onTextStyle,
    required this.offTextStyle,
    this.textScaler = TextScaler.noScaling,
    this.scrollDuration = const Duration(milliseconds: 300),
    this.lineCount,
  });

  /// Default style
  static LyricsDataPlayerStyle get defaultDark => LyricsDataPlayerStyle(
    onTextStyle: const TextStyle(
      color: Colors.yellow,
      fontWeight: FontWeight.bold,
    ),
    offTextStyle: const TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.bold,
    ),
  );

  /// Default style
  static LyricsDataPlayerStyle get defaultLight => LyricsDataPlayerStyle(
    onTextStyle: const TextStyle(
      color: Colors.black,
      fontWeight: FontWeight.bold,
    ),
    offTextStyle: const TextStyle(
      color: Colors.grey,
      fontWeight: FontWeight.bold,
    ),
  );

  /// copy with
  LyricsDataPlayerStyle copyWith({
    TextStyle? onTextStyle,
    TextStyle? offTextStyle,
    TextScaler? textScaler,
    int? lineCount,
    Duration? scrollDuration,
  }) {
    return LyricsDataPlayerStyle(
      onTextStyle: onTextStyle ?? this.onTextStyle,
      offTextStyle: offTextStyle ?? this.offTextStyle,
      textScaler: textScaler ?? this.textScaler,
      lineCount: lineCount ?? this.lineCount,
      scrollDuration: scrollDuration ?? this.scrollDuration,
    );
  }
}

/// LyricsDataPlayerMeta
class LyricsDataPlayerMeta {
  /// Controller
  final LyricsDataController controller;

  /// Style
  final LyricsDataPlayerStyle style;

  /// Size info
  final LyricsDataPlayerMetaSizeInfo sizeInfo;

  /// On text style
  TextStyle get onTextStyle => style.onTextStyle.copyWith(
    fontSize: sizeInfo.fontSize,
    fontWeight: FontWeight.bold,
  );

  /// Off text style
  TextStyle get offTextStyle => style.offTextStyle.copyWith(
    fontSize: sizeInfo.fontSize,
    fontWeight: FontWeight.bold,
  );

  /// Constructor
  LyricsDataPlayerMeta({
    required this.controller,
    required this.sizeInfo,
    required this.style,
  });
}

/// LyricsDataPlayer
///
/// Must be bounded in the screen
class LyricsDataPlayer extends StatefulWidget {
  /// LyricsDataController
  final LyricsDataController controller;

  /// Style
  final LyricsDataPlayerStyle style;

  /// Constructor
  const LyricsDataPlayer({
    super.key,
    required this.controller,
    required this.style,
  });

  @override
  State<LyricsDataPlayer> createState() => _LyricsDataPlayerState();
}

class _LyricsDataPlayerState extends State<LyricsDataPlayer> {
  LocatedLyricsData get locatedLyricsData =>
      widget.controller.locatedLyricsData;

  @override
  Widget build(BuildContext context) {
    var lines = locatedLyricsData.lines;
    return LayoutBuilder(
      builder: (context, constraints) {
        var sizeInfo = LyricsDataPlayerMetaSizeInfo(size: constraints.biggest);
        var meta = LyricsDataPlayerMeta(
          controller: widget.controller,
          sizeInfo: sizeInfo,
          style: widget.style,
        );
        return ScrollablePositionedList.builder(
          itemScrollController: widget.controller.itemScrollController,
          itemBuilder: (context, index) {
            return LocatedLyricsDataLineWidget(meta: meta, index: index);
          },
          itemCount: lines.length + (widget.style.lineCount ?? 1) - 1,
        );
      },
    );
  }
}

/// Located lyrics data line widget
class LocatedLyricsDataLineWidget extends StatefulWidget {
  /// LyricsDataPlayerMeta
  final LyricsDataPlayerMeta meta;

  /// Index
  final int index;

  /// Constructor
  const LocatedLyricsDataLineWidget({
    super.key,
    required this.meta,
    required this.index,
  });

  @override
  State<LocatedLyricsDataLineWidget> createState() =>
      _LocatedLyricsDataLineWidgetState();
}

class _LocatedLyricsDataLineWidgetState
    extends State<LocatedLyricsDataLineWidget> {
  var _current = false;
  LyricsDataPlayerMeta get meta => widget.meta;
  LocatedLyricsDataLine get line =>
      widget.meta.controller.locatedLyricsData.getLine(widget.index);
  List<LocatedLyricsDataPart> get parts => line.parts;
  LyricsDataController get controller => widget.meta.controller;
  int get lineIndex => widget.index;
  double? get lineHeight => meta.style.lineCount == null
      ? null
      : meta.sizeInfo.height / meta.style.lineCount!;

  void _scrollToMe() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      meta.controller.itemScrollController.scrollTo(
        index: lineIndex,
        duration: widget.meta.style.scrollDuration,
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget wrap(Widget child) {
      return SizedBox(height: lineHeight, child: child);
    }

    if (lineIndex >= widget.meta.controller.locatedLyricsData.lines.length) {
      return wrap(Container());
    }

    var parts = line.parts;
    if (parts.isNotEmpty) {
      var itemRefs = parts
          .map(
            (part) => LocatedLyricsDataItemRef(lineIndex, parts.indexOf(part)),
          )
          .toList();
      var streams = itemRefs
          .map((itemRef) => widget.meta.controller.getItemStatusStream(itemRef))
          .toList();
      var stream = streamJoinAll(streams);

      var initialData = streams
          .map((stream) => stream.valueOrNull ?? ControllerDataItemState())
          .toList();
      return StreamBuilder(
        stream: stream,
        initialData: initialData,
        builder: (context, snapshot) {
          var states = snapshot.data ?? initialData;
          var on = states.any((state) => state.on);
          if (on && !_current) {
            _scrollToMe();
          }
          _current = on;
          // devPrint('scaler: ${meta.style.textScaler}');
          return wrap(
            RichText(
              textAlign: TextAlign.center,
              textScaler: widget.meta.style.textScaler,
              text: TextSpan(
                children: [
                  for (var i = 0; i < parts.length; i++)
                    TextSpan(
                      text: parts[i].partData.text,
                      style: states[i].on
                          ? widget.meta.onTextStyle
                          : widget.meta.offTextStyle,
                    ),
                ],
              ),
            ),
          );
        },
      );
    }
    var itemRef = LocatedLyricsDataItemRef(lineIndex, -1);
    return ValueStreamBuilder(
      stream: widget.meta.controller.getItemStatusStream(itemRef),
      builder: (context, snapshot) {
        var state = snapshot.data ?? ControllerDataItemState();
        var on = state.on;
        var current = state.current;
        if (current && !_current) {
          _scrollToMe();
        }
        _current = current;
        // devPrint('scaler: ${meta.style.textScaler}');
        return wrap(
          Text(
            textScaler: meta.style.textScaler,
            line.text,
            style: on ? widget.meta.onTextStyle : widget.meta.offTextStyle,
            textAlign: TextAlign.center,
          ),
        );
      },
    );
  }
}

/// Internal part widget
class LocatedLyricsDataPartWidget extends StatefulWidget {
  /// LyricsDataPlayerMeta
  final LyricsDataPlayerMeta meta;

  /// LyricsDataItemRef
  final LocatedLyricsDataItemRef itemRef;

  /// Constructor
  const LocatedLyricsDataPartWidget({
    super.key,
    required this.meta,
    required this.itemRef,
  });

  @override
  State<LocatedLyricsDataPartWidget> createState() =>
      _LocatedLyricsDataPartWidgetState();
}

class _LocatedLyricsDataPartWidgetState
    extends State<LocatedLyricsDataPartWidget> {
  LyricsDataPlayerMeta get meta => widget.meta;
  LyricsDataPlayerStyle get style => meta.style;
  LocatedLyricsDataItemRef get itemRef => widget.itemRef;
  LocatedLyricsDataItemInfo get itemInfo =>
      meta.controller.locatedLyricsData.getItemInfo(widget.itemRef);
  var _current = false;
  @override
  Widget build(BuildContext context) {
    var controller = widget.meta.controller;

    return ValueStreamBuilder(
      stream: controller.getItemStatusStream(itemRef),
      builder: (context, snapshot) {
        var state = snapshot.data ?? ControllerDataItemState();
        var on = state.on;
        var current = state.current;
        if (current && !_current) {
          _current = true;
          SchedulerBinding.instance.addPostFrameCallback((_) {
            meta.controller.itemScrollController.scrollTo(
              index: itemRef.lineIndex,
              duration: style.scrollDuration,
              curve: Curves.easeInOut,
            );
          });
        }
        // ignore: avoid_unnecessary_containers
        return Text(
          itemInfo.text,
          textScaler: widget.meta.style.textScaler,
          style: on ? widget.meta.onTextStyle : widget.meta.offTextStyle,
          textAlign: TextAlign.center,
        );
      },
    );
  }
}
