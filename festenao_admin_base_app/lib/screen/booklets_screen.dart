import 'package:festenao_admin_base_app/view/booklet_leading.dart';
import 'package:flutter/material.dart';
import 'package:tekartik_app_flutter_widget/view/body_container.dart';
import 'package:tekartik_app_flutter_widget/view/body_h_padding.dart';
import 'package:tekartik_app_flutter_widget/view/with_header_footer_list_view.dart';
import 'package:tkcms_admin_app/audi/tkcms_audi.dart';
import 'booklets_screen_bloc.dart';

/// Booklets screen
class BookletsScreen extends StatefulWidget {
  /// Booklets screen
  const BookletsScreen({super.key});

  @override
  State<BookletsScreen> createState() => _BookletsScreenState();
}

class _BookletsScreenState extends State<BookletsScreen> {
  @override
  Widget build(BuildContext context) {
    var bloc = BlocProvider.of<BookletsScreenBloc>(context);
    return ValueStreamBuilder(
        stream: bloc.state,
        builder: (context, snapshot) {
          var state = snapshot.data;
          return Scaffold(
            appBar: AppBar(
                title: const Text('Booklet') // appIntl(context).bookletsTitle),
                /*actions: [
                IconButton(
                    onPressed: () {
                      ContentNavigator.of(context)
                          .pushPath<void>(SettingsContentPath());
                    },
                    icon: const Icon(Icons.settings)),
              ],*/
                // automaticallyImplyLeading: false,
                ),
            body: Builder(builder: (context) {
              if (state == null) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }
              var booklets = state.booklets;
              return WithHeaderFooterListView.builder(
                  footer: state.user == null
                      ? const BodyContainer(
                          child: BodyHPadding(
                              child: Center(
                                  child: Column(
                          children: [
                            Text(
                                'Not signed in'), // appIntl(context).notSignedInInfo),
                            SizedBox(height: 8),
                            /*
                            ElevatedButton(
                                onPressed: () {
                                  Navigator.of(context).push<void>(
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              globalAuthFlutterUiService
                                                  .loginScreen(
                                                      firebaseAuth:
                                                          globalFirebaseContext
                                                              .auth)));
                                },
                                child:
                                    Text(appIntl(context).signInButtonLabel)),*/
                          ],
                        ))))
                      : null,
                  itemCount: booklets.length,
                  itemBuilder: (context, index) {
                    var booklet = booklets[index];
                    return BodyContainer(
                      child: ListTile(
                        leading: BookletLeading(booklet: booklet),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                                onPressed: () {
                                  //goToNotesScreen(context, booklet.ref);
                                },
                                icon: const Icon(Icons.arrow_forward_ios)),
                            /*  IconButton(
                                onPressed: () {
                                  //_goToNotes(context, booklet.id);
                                },
                                icon: Icon(Icons.edit))*/
                          ],
                        ),
                        title: Text(booklet.name.v ?? booklet.uid.v ?? ''),
                        onTap: () async {
                          //  await goToNotesScreen(context, booklet.ref);
                        },
                      ),
                    );
                  });
            }),
            floatingActionButton: FloatingActionButton(
              onPressed: () async {
                //await goToCreateBookletScreen(context);
              },
              child: const Icon(Icons.add),
            ),
          );
        });
  }
}

/// Go to booklets screen
Future<Object?> goToBookletsScreen(
  BuildContext context,
) async {
  return await Navigator.of(context).push<Object?>(MaterialPageRoute(
      builder: (_) => BlocProvider(
          blocBuilder: () => BookletsScreenBloc(),
          child: const BookletsScreen())));
}
