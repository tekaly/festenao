import 'package:flutter/material.dart';
import 'package:tekartik_app_flutter_widget/mini_ui.dart';
import 'package:tkcms_user_app/view/body_container.dart';

class SondageScreen extends StatefulWidget {
  const SondageScreen({super.key});

  @override
  State<SondageScreen> createState() => _SondageScreenState();
}

class _SondageScreenState extends State<SondageScreen> {
  final formKey = GlobalKey<FormState>();
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Form(
          key: formKey,
          child: Scaffold(
            appBar: AppBar(title: const Text('Sondage WTF #6')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    BodyContainer(
                      width: 480,
                      child: Column(
                        children: [
                          Text(
                            'Sondage mobilité WTF\u{00A0}#6',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 32),
                          TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'Votre nom',
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'Votre âge',
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            decoration: const InputDecoration(
                              labelText:
                                  'D\'où venez-vous (Département, ex: 30)',
                            ),
                          ),
                          const SizedBox(height: 32),
                          Center(
                            child: ElevatedButton(
                              onPressed: () {
                                muiSnack(context, 'Non implémenté');
                              },
                              child: const Text('Valider'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
