import 'package:festenao_common/festenao_quizz.dart';
import 'package:material_ui/material_ui.dart';

import 'quizz_player_utils.dart';

/// Completes [players] to 3 with placeholder players (a letter derived from
/// [quizId]), for the podium.
List<FsQuizPlayer> quizzFillTo3Players(
  List<FsQuizPlayer> players,
  String quizId, {
  Avatars? avatars,
}) {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  if (players.length >= 3) {
    return players.sublist(0, 3);
  }
  var value = 0;
  for (var code in quizId.codeUnits) {
    value = (value + code) % 123456789;
  }
  players = List.from(players);
  FsQuizPlayer generatePlayer() {
    var rank = players.length + 1;
    // Any letter will do
    var username = '${chars[(value * rank) % chars.length]}...';
    String? avatar;
    if (avatars != null) {
      avatar = avatars.avatars[(value * rank) % avatars.avatars.length].name;
    }

    return FsQuizPlayer()
      ..avatar.v = avatar
      ..username.v = username
      ..rank.v = rank;
  }

  while (players.length < 3) {
    players.add(generatePlayer());
  }
  return players;
}

/// The top players of a quiz as a list (rank, name, score, time), live.
class QuizzTopPlayersWidget extends StatelessWidget {
  /// The database.
  final QuizzFirestoreDatabase database;

  /// The quiz id.
  final String quizId;

  /// The number of players shown.
  final int limit;

  /// True to show the names even when not validated.
  final bool showNames;

  /// Creates the widget.
  const QuizzTopPlayersWidget({
    super.key,
    required this.database,
    required this.quizId,
    this.limit = 10,
    this.showNames = false,
  });

  @override
  Widget build(BuildContext context) {
    return _OrderedPlayersStreamBuilder(
      database: database,
      quizId: quizId,
      limit: limit,
      builder: (context, snapshot) {
        var players = snapshot.data;
        if (players == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (players.isEmpty) {
          return const Center(child: Text('No player yet'));
        }
        return ListView.builder(
          shrinkWrap: true,
          itemCount: players.length,
          itemBuilder: (context, index) {
            var player = players[index];
            var name = showNames
                ? quizzFixDisplayNameString(player.username.v ?? '')
                : quizzGetPlayerDisplayName(player);
            return ListTile(
              leading: CircleAvatar(
                child: Text('${player.rank.v ?? (index + 1)}'),
              ),
              title: Text(name),
              subtitle: Text(
                'score ${player.score.v ?? 0}, ${quizzFormatMs(player.elapsedMs.v ?? 0)}'
                '${player.validity.v == quizPlayerValidityValid ? ', validated' : ''}',
              ),
            );
          },
        );
      },
    );
  }
}

/// A [StreamBuilder] on [QuizzFirestoreDatabase.orderedPlayersNoValidityStream]
/// whose stream is created once (and again for another quiz, database or
/// limit), not on every build: a new stream is a new Firestore listener and
/// the parents typically rebuild every 100 ms (QuizzStateNowBuilder).
class _OrderedPlayersStreamBuilder extends StatefulWidget {
  final QuizzFirestoreDatabase database;
  final String quizId;
  final int limit;
  final AsyncWidgetBuilder<List<FsQuizPlayer>> builder;

  const _OrderedPlayersStreamBuilder({
    required this.database,
    required this.quizId,
    required this.limit,
    required this.builder,
  });

  @override
  State<_OrderedPlayersStreamBuilder> createState() =>
      _OrderedPlayersStreamBuilderState();
}

class _OrderedPlayersStreamBuilderState
    extends State<_OrderedPlayersStreamBuilder> {
  late Stream<List<FsQuizPlayer>> _players;

  Stream<List<FsQuizPlayer>> _playersStream() => widget.database
      .orderedPlayersNoValidityStream(widget.quizId, limit: widget.limit);

  @override
  void initState() {
    super.initState();
    _players = _playersStream();
  }

  @override
  void didUpdateWidget(covariant _OrderedPlayersStreamBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.database != widget.database ||
        oldWidget.quizId != widget.quizId ||
        oldWidget.limit != widget.limit) {
      _players = _playersStream();
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<FsQuizPlayer>>(
    stream: _players,
    builder: widget.builder,
  );
}

/// A podium column.
class QuizzPodiumColumnWidget extends StatelessWidget {
  /// The player.
  final FsQuizPlayer player;

  /// The width.
  final double width;

  /// The height.
  final double height;

  /// The color.
  final Color color;

  /// Creates the column.
  const QuizzPodiumColumnWidget({
    super.key,
    required this.player,
    required this.width,
    required this.height,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: width * .02),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(width * .2),
          color: color,
        ),
        child: Column(
          children: [
            SizedBox(height: width * .15),
            Text(
              (player.rank.v ?? 1).toString(),
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: width * .6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The podium of the 3 first players (2nd, 1st, 3rd).
class QuizzPodiumWidget extends StatelessWidget {
  /// The 3 players, see [quizzFillTo3Players].
  final List<FsQuizPlayer> players;

  /// The names color.
  final Color nameColor;

  /// The 3 columns colors (1st, 2nd, 3rd).
  final List<Color> colors;

  /// Creates the podium.
  const QuizzPodiumWidget({
    super.key,
    required this.players,
    this.nameColor = Colors.black,
    this.colors = const [Colors.red, Colors.blue, Colors.black],
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        var height = constraints.maxHeight;
        var width = constraints.maxWidth;
        var columnWidth = height * .26;
        Widget nameWidget(FsQuizPlayer player) {
          return Text(
            quizzGetPlayerDisplayName(player),
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              color: nameColor,
              fontSize: columnWidth * 0.28,
              fontWeight: FontWeight.w900,
            ),
          );
        }

        return Stack(
          children: [
            Positioned(
              top: height * .30,
              left: 0,
              right: width * .616,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [nameWidget(players[1])],
              ),
            ),
            Positioned(
              top: height * .18,
              right: 0,
              left: 0,
              child: Center(child: nameWidget(players[0])),
            ),
            Positioned(
              top: height * .42,
              left: width * .613,
              child: nameWidget(players[2]),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    QuizzPodiumColumnWidget(
                      player: players[1],
                      width: columnWidth,
                      height: height * .57,
                      color: colors[1],
                    ),
                    QuizzPodiumColumnWidget(
                      player: players[0],
                      width: columnWidth,
                      height: height * .7,
                      color: colors[0],
                    ),
                    QuizzPodiumColumnWidget(
                      player: players[2],
                      width: columnWidth,
                      height: height * .45,
                      color: colors[2],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The live podium of a quiz, once its ranks are computed (a progress
/// indicator before).
class QuizzResultPodiumWidget extends StatefulWidget {
  /// The database.
  final QuizzFirestoreDatabase database;

  /// The quiz id.
  final String quizId;

  /// The avatars if any (placeholder players).
  final Avatars? avatars;

  /// Creates the widget.
  const QuizzResultPodiumWidget({
    super.key,
    required this.database,
    required this.quizId,
    this.avatars,
  });

  @override
  State<QuizzResultPodiumWidget> createState() =>
      _QuizzResultPodiumWidgetState();
}

class _QuizzResultPodiumWidgetState extends State<QuizzResultPodiumWidget> {
  /// Created once (and again for another quiz or database), not in build:
  /// the tv screen rebuilds every 100 ms and a new stream is a new Firestore
  /// listener.
  late Stream<FsQuizStatus> _status;

  /// Created when the ranks are first known, then kept.
  Stream<List<FsQuizPlayer>>? _rankedPlayers;

  @override
  void initState() {
    super.initState();
    _status = widget.database.quizStatusStream(widget.quizId);
  }

  @override
  void didUpdateWidget(covariant QuizzResultPodiumWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.database != widget.database ||
        oldWidget.quizId != widget.quizId) {
      _status = widget.database.quizStatusStream(widget.quizId);
      _rankedPlayers = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<FsQuizStatus>(
      stream: _status,
      builder: (context, snapshot) {
        var playerCount = snapshot.data?.playersCount.v;
        if (playerCount != null) {
          return StreamBuilder<List<FsQuizPlayer>>(
            stream: _rankedPlayers ??= widget.database.rankedPlayersStream(
              widget.quizId,
            ),
            builder: (context, snapshot) {
              var players = snapshot.data;
              if (players != null) {
                // Every snapshot: the ranks and validities may change after
                // (a forced compute); the placeholders are the same each
                // time (seeded by the quiz id).
                return QuizzPodiumWidget(
                  players: quizzFillTo3Players(
                    players,
                    widget.quizId,
                    avatars: widget.avatars,
                  ),
                );
              }
              return const Text('No Players');
            },
          );
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }
}
