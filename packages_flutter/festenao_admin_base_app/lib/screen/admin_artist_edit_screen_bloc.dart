import 'dart:async';

import 'package:festenao_common/data/src/model/db_article.dart';
import 'package:festenao_common/data/src/model/db_artist.dart';
import 'package:festenao_common/data/src/model/db_paths.dart';
import 'package:tekartik_app_cv_sembast/app_cv_sembast.dart';

import 'admin_article_edit_screen_bloc_mixin.dart';
import 'admin_screen_bloc_mixin.dart';

class AdminArtistEditScreenBlocState {
  late final String? artistId;
  final DbArtist? artist;
  final Database db;

  AdminArtistEditScreenBlocState({
    String? artistId,
    this.artist,
    required this.db,
  }) {
    this.artistId = artistId ?? artist?.id;
  }
}

class AdminArtistEditScreenResult {
  final bool? deleted;

  AdminArtistEditScreenResult({this.deleted});
}

class AdminArtistEditScreenBloc
    extends AdminAppProjectScreenBlocBase<AdminArtistEditScreenBlocState>
    with AdminArticleEditScreenBlocMixin {
  final String? artistId;
  final DbArtist? artist;

  AdminArtistEditScreenBloc({
    required this.artistId,
    this.artist,
    required super.projectContext,
  }) {
    () async {
      var db = await projectDb;
      if (artistId == null) {
        // Creation
        add(AdminArtistEditScreenBlocState(artist: artist, db: db));
      } else {
        var artist = (await dbArtistStoreRef.record(artistId!).get(db));

        add(
          AdminArtistEditScreenBlocState(
            artist: artist,
            artistId: artistId,
            db: db,
          ),
        );
      }
    }();
  }

  Future<void> delete() async {
    var db = await projectDb;
    await dbArtistStoreRef.record(artistId!).delete(db);
  }

  @override
  CvStoreRef<String, DbArticle> get articleStore => dbArtistStoreRef;
}
