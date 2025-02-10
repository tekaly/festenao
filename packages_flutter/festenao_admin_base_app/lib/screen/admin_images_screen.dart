import 'dart:async';
import 'dart:math';

import 'package:festenao_admin_base_app/layout/admin_screen_layout.dart';
import 'package:festenao_admin_base_app/screen/screen_bloc_import.dart';

import 'package:flutter/material.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';
import 'package:tekartik_app_rx_bloc/auto_dispose_state_base_bloc.dart';

import 'admin_image_edit_screen.dart';
import 'admin_image_screen.dart';

class AdminImagesScreenBlocState {
  final List<DbImage> list;

  AdminImagesScreenBlocState(this.list);
}

class AdminImagesScreenBloc
    extends AutoDisposeStateBaseBloc<AdminImagesScreenBlocState> {
  late final _dbBloc = audiAddDisposable(
      AdminAppProjectContextDbBloc(projectContext: projectContext));
  final FestenaoAdminAppProjectContext projectContext;
  AdminImagesScreenBloc({required this.projectContext}) {
    () async {
      var db = await _dbBloc.grabDatabase();
      audiAddStreamSubscription(
          dbImageStoreRef.query().onRecords(db).listen((records) {
        add(AdminImagesScreenBlocState(records));
      }));
    }();
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
                    goToAdminImageScreen(context,
                        imageId: image.id, projectContext: bloc.projectContext);
                  },
                );
              });
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          var result = await goToAdminImageEditScreen(context,
              imageId: null, projectContext: bloc.projectContext);
          if (result != null) {}
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

Future<void> goToAdminImagesScreen(BuildContext context,
    {required FestenaoAdminAppProjectContext projectContext}) async {
  await Navigator.of(context).push<void>(MaterialPageRoute(builder: (context) {
    return BlocProvider(
        blocBuilder: () =>
            AdminImagesScreenBloc(projectContext: projectContext),
        child: const AdminImagesScreen());
  }));
}
