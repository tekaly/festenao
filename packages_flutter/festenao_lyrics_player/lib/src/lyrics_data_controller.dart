import 'package:festenao_common_flutter/common_utils.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:tekaly_lyrics/utils/lyrics_data_located.dart';

class _LocatedLyricsDataItemRefControllerInfo extends AutoDisposerableBase
    implements ControllerDataItemInfo {
  final LocatedLyricsDataItemInfo itemInfo;
  late final state = audiAddBehaviorSubject(
    BehaviorSubject<ControllerDataItemState>.seeded(ControllerDataItemState()),
  );

  _LocatedLyricsDataItemRefControllerInfo({required this.itemInfo});

  @override
  ValueStream<ControllerDataItemState> get stateStream => state.stream;

  ControllerDataItemState get _state => state.value;

  bool get on => _state.on;
  bool get current => _state.current;

  set on(bool on) {
    if (on == _state.on) {
      return;
    }
    state.add(state.value.copyWith(on: on));
  }

  set current(bool current) {
    if (current == _state.current) {
      return;
    }
    state.add(state.value.copyWith(current: current));
  }
}

/// Interface for item info
abstract class ControllerDataItemInfo {
  /// Item info state stream
  ValueStream<ControllerDataItemState> get stateStream;
}

/// State
class ControllerDataItemState {
  /// True if past up to current
  final bool on;

  /// True if current
  final bool current;

  /// True if past up to current
  ControllerDataItemState({this.on = false, this.current = false});

  /// Copy with
  ControllerDataItemState copyWith({bool? on, bool? current}) {
    return ControllerDataItemState(
      on: on ?? this.on,
      current: current ?? this.current,
    );
  }

  @override
  String toString() => 'State(on: $on, current: $current)';
}

/// Lyrics data player controller
abstract class LyricsDataController {
  /// Lyrics data
  LyricsData get lyricsData;

  /// Lyrics data player controller
  factory LyricsDataController({required LyricsData lyricsData}) {
    return _LyricsDataController(lyricsData: lyricsData);
  }

  /// 1 is normal

  void play({double speed = 1});

  /// Update the controller at a given time
  void update(Duration time);
}

/// Lyrics data controller extension (private)
extension LyricsDataControllerPrvExt on LyricsDataController {
  _LyricsDataController get _self => this as _LyricsDataController;

  /// Located lyrics data
  LocatedLyricsData get locatedLyricsData => _self.locatedLyricsData;

  /// Item scroll controller
  ItemScrollController get itemScrollController => _self.itemScrollController;

  /// Item status stream
  ValueStream<ControllerDataItemState> getItemStatusStream(
    LocatedLyricsDataItemRef itemRef,
  ) {
    var ctlrInfo = _self._map[itemRef];
    if (ctlrInfo != null) {
      return ctlrInfo.stateStream;
    } else {
      return BehaviorSubject.seeded(ControllerDataItemState());
    }
  }
}

class _LyricsDataController implements LyricsDataController {
  @override
  final LyricsData lyricsData;
  late final LocatedLyricsData locatedLyricsData;
  final itemScrollController = ItemScrollController();

  final _list = <_LocatedLyricsDataItemRefControllerInfo>[];
  final _map =
      <LocatedLyricsDataItemRef, _LocatedLyricsDataItemRefControllerInfo>{};
  void _add(_LocatedLyricsDataItemRefControllerInfo info) {
    var ref = info.itemInfo.ref;
    _list.add(info);
    _map[ref] = info;
  }

  void _addRef(LocatedLyricsDataItemRef ref) {
    var itemInfo = locatedLyricsData.getItemInfo(ref);
    var ctlrInfo = _LocatedLyricsDataItemRefControllerInfo(itemInfo: itemInfo);
    _add(ctlrInfo);
  }

  final _sw = Stopwatch();
  _LyricsDataController({required this.lyricsData}) {
    locatedLyricsData = LocatedLyricsData(lyricsData: lyricsData);
    var ref = LocatedLyricsDataItemRef.before();
    while (true) {
      _addRef(ref);
      var nextRef = locatedLyricsData.getNextRef(ref);
      if (nextRef == ref) {
        break;
      }
      ref = nextRef;
    }
  }

  void _setOn(LocatedLyricsDataItemRef ref, bool on) {
    var info = _map[ref];
    if (info != null) {
      info.on = on;
    }
  }

  void _setCurrent(LocatedLyricsDataItemRef ref, bool current) {
    var info = _map[ref];
    if (info != null) {
      info.current = current;
    }
  }

  var currentRef = LocatedLyricsDataItemRef.before();
  @override
  void update(Duration time) {
    var newItemInfo = locatedLyricsData.locateItemInfo(time);
    var newRef = newItemInfo.ref;
    if (newRef != currentRef) {
      var cmp = newRef.compareTo(currentRef);
      if (cmp < 0) {
        var ref = currentRef;
        do {
          _setOn(ref, false);
          ref = locatedLyricsData.getPreviousRef(ref);
        } while (newRef.compareTo(ref) < 0);
      } else if (cmp > 0) {
        var ref = currentRef;
        do {
          ref = locatedLyricsData.getNextRef(ref);
          _setOn(ref, true);
        } while (newRef.compareTo(ref) > 0);
      }
      _setCurrent(currentRef, false);
      // print('$newRef update: $time');
      currentRef = newRef;
      _setCurrent(currentRef, true);
    }
  }

  var _playing = false;
  void pause() {
    if (!_playing) {
      return;
    }
    _playing = false;
    _sw.stop();
  }

  final _lock = Lock();
  @override
  void play({double speed = 1}) {
    if (_playing) {
      return;
    }
    _sw.start();
    _playing = true;
    _lock.synchronized(() async {
      while (_playing) {
        await sleep(10);
        update(_sw.elapsed * speed);
      }
    });
  }
}
