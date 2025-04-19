import 'package:festenao_base_app/form/src/view/app_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:tekartik_app_flutter_widget/delayed_display.dart';
import 'package:tekartik_app_navigator_flutter/page_route.dart';
import 'package:tkcms_user_app/view/body_container.dart';
import 'package:tkcms_user_app/view/busy_screen_state_mixin.dart';

class ThankYouScreen extends StatefulWidget {
  const ThankYouScreen({super.key});

  @override
  State<ThankYouScreen> createState() => _ThankYouScreenState();
}

class _ThankYouScreenState extends State<ThankYouScreen>
    with BusyScreenStateMixin<ThankYouScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    busyDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return DelayedDisplay(
            child: Stack(
              children: [
                Center(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      BodyContainer(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Text(
                                'Merci pour votre participation',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 64),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

Future<void> goToThankYouScreen(BuildContext context) async {
  await Navigator.of(context).push(
    NoAnimationMaterialPageRoute<void>(
      builder: (context) {
        return const ThankYouScreen();
      },
    ),
  );
}
