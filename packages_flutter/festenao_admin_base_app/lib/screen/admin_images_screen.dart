import 'dart:async';
import 'dart:math';

import 'package:festenao_admin_base_app/layout/admin_screen_layout.dart';
import 'package:festenao_admin_base_app/screen/screen_bloc_import.dart';

import 'package:flutter/material.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';

import 'admin_image_edit_screen.dart';
import 'admin_image_screen.dart';

class AdminImagesScreenBlocState {
  final List<DbImage> list;

  AdminImagesScreenBlocState(this.list);
}

class AdminImagesScreenBloc extends BaseBloc {
  final _state = BehaviorSubject<AdminImagesScreenBlocState>();

  ValueStream<AdminImagesScreenBlocState> get state => _state;
  late StreamSubscription _imageSubscription;
  late var db = globalBookletsDb.db;
  AdminImagesScreenBloc() {
    () async {
      _imageSubscription =
          dbImageStoreRef.query().onRecords(db).listen((records) {
        _state.add(AdminImagesScreenBlocState(records));
      });
    }();
  }

  @override
  void dispose() {
    _imageSubscription.cancel();
    _state.close();
    super.dispose();
  }
}

class AdminImagesScreen extends StatefulWidget {
  const AdminImagesScreen({super.key});

  @override
  State<AdminImagesScreen> createState() => _AdminImagesScreenState();
}

class _AdminImagesScreenState extends State<AdminImagesScreen> {
  @override
  Widget build(BuildContext context) {
    var bloc = BlocProvider.of<AdminImagesScreenBloc>(context);
    return AdminScreenLayout(
      appBar: AppBar(
        title: const Text('Images'),
      ),
      body: ValueStreamBuilder<AdminImagesScreenBlocState>(
        stream: bloc.state,
        builder: (context, snapshot) {
          var list = snapshot.data?.list;
          if (list == null) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          return ListView.builder(
              itemCount: list.length,
              itemBuilder: (context, index) {
                var image = list[index];
                var aspectRatio = max(.25,
                        min(4, (image.width.v ?? 1) / (image.height.v ?? 1)))
                    .toDouble();
                return ListTile(
                  leading: SizedBox(
                      width: 32,
                      height: 32,
                      child: image.blurHash.v != null
                          ? AspectRatio(
                              aspectRatio: aspectRatio,
                              child: BlurHash(hash: image.blurHash.v!))
                          : null),
                  title: Text(image.id),
                  subtitle: Text(image.name.v ?? '?'),
                  onTap: () {
                    goToAdminImageScreen(context, imageId: image.id);
                  },
                );
              });
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          var result = await goToAdminImageEditScreen(context, imageId: null);
          if (result != null) {}
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

Future<void> goToAdminImagesScreen(BuildContext context) async {
  await Navigator.of(context).push<void>(MaterialPageRoute(builder: (context) {
    return BlocProvider(
        blocBuilder: () => AdminImagesScreenBloc(),
        child: const AdminImagesScreen());
  }));
}
