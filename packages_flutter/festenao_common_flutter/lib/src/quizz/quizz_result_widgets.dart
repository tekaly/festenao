import 'package:festenao_common/festenao_quizz.dart';
import 'package:flutter/material.dart';

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
    return StreamBuilder<List<FsQuizPlayer>>(
      stream: database.orderedPlayersNoValidityStream(quizId, limit: limit),
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
  List<FsQuizPlayer>? _players;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<FsQuizStatus>(
      stream: widget.database.quizStatusStream(widget.quizId),
      builder: (context, snapshot) {
        var playerCount = snapshot.data?.playersCount.v;
        if (playerCount != null) {
          return StreamBuilder<List<FsQuizPlayer>>(
            stream: widget.database.rankedPlayersStream(widget.quizId),
            builder: (context, snapshot) {
              var players = snapshot.data;
              if (players != null) {
                _players ??= quizzFillTo3Players(
                  players,
                  widget.quizId,
                  avatars: widget.avatars,
                );
                return QuizzPodiumWidget(players: _players!);
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
