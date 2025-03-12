import 'package:festenao_admin_base_app/admin_app/admin_app_project_context.dart';
import 'package:festenao_admin_base_app/screen/admin_attribute_edit_screen.dart';
import 'package:festenao_admin_base_app/view/tile_padding.dart';
import 'package:festenao_common/data/festenao_db.dart';
import 'package:flutter/material.dart';

class AttributesTileOptions {
  final bool readOnly;
  final ValueNotifier<List<CvAttribute>?> attributes;

  AttributesTileOptions({this.readOnly = false, required this.attributes});
}

class AttributesTile extends StatefulWidget {
  final FestenaoAdminAppProjectContext projectContext;
  final AttributesTileOptions options;
  const AttributesTile({
    super.key,
    required this.options,
    required this.projectContext,
  });

  @override
  State<AttributesTile> createState() => _AttributesTileState();
}

class _AttributesTileState extends State<AttributesTile> {
  ValueNotifier<List<CvAttribute>?> get attributes => widget.options.attributes;
  List<CvAttribute> get attributeList => attributes.value ?? <CvAttribute>[];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<CvAttribute>?>(
      valueListenable: attributes,
      builder: (context, value, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!widget.options.readOnly)
              TilePadding(
                child: ElevatedButton(
                  onPressed: () async {
                    var result = await goToAdminAttributeEditScreen(
                      context,
                      param: AdminAttributeEditScreenParam(),
                      projectContext: widget.projectContext,
                    );
                    var attribute = result?.attribute;
                    if (attribute != null) {
                      attributes.value = [
                        ...attributes.value ?? <CvAttribute>[],
                        attribute,
                      ];
                    }
                  },
                  child: const Text('Add attribute'),
                ),
              ),
            for (var i = 0; i < attributeList.length; i++)
              AdminAttributeTile(
                options: widget.options,
                index: i,
                projectContext: widget.projectContext,
              ),
          ],
        );
      },
    );
  }
}

class AdminAttributeTile extends StatelessWidget {
  final FestenaoAdminAppProjectContext projectContext;
  final AttributesTileOptions options;
  final int index;
  ValueNotifier<List<CvAttribute>?> get attributes => options.attributes;
  List<CvAttribute> get attributeList =>
      options.attributes.value ?? <CvAttribute>[];
  const AdminAttributeTile({
    super.key,
    required this.options,
    required this.index,
    required this.projectContext,
  });

  @override
  Widget build(BuildContext context) {
    var attribute = attributeList[index];
    return ListTile(
      onTap:
          options.readOnly
              ? null
              : () async {
                var result = await goToAdminAttributeEditScreen(
                  context,
                  param: AdminAttributeEditScreenParam(attribute: attribute),
                  projectContext: projectContext,
                );
                var newAttribute = result?.attribute;
                if (newAttribute != null) {
                  attributes.value = [
                    ...attributeList.sublist(0, index),
                    newAttribute,
                    ...attributeList.sublist(index + 1),
                  ];
                }
              },
      title: Row(
        children: [
          Expanded(child: Text(attribute.name.v ?? '')),
          Expanded(child: Text(attribute.type.v ?? '')),
          Expanded(child: Text(attribute.value.v ?? '')),
          if (!options.readOnly)
            Column(
              children: [
                SizedBox(
                  height: 24,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      if (index > 0) {
                        attributes.value = [
                          ...attributeList.sublist(0, index - 1),
                          attributeList[index],
                          attributeList[index - 1],
                          ...attributeList.sublist(index + 1),
                        ];
                      }
                    },
                    icon: const Icon(Icons.keyboard_arrow_up),
                  ),
                ),
                SizedBox(
                  height: 24,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      if (index < attributeList.length - 1) {
                        attributes.value = [
                          ...attributeList.sublist(0, index),
                          attributeList[index + 1],
                          attributeList[index],
                          ...attributeList.sublist(index + 2),
                        ];
                      }
                    },
                    icon: const Icon(Icons.keyboard_arrow_down),
                  ),
                ),
              ],
            ),
          if (!options.readOnly)
            IconButton(
              onPressed: () {
                attributes.value = [
                  ...attributeList.sublist(0, index),
                  ...attributeList.sublist(index + 1),
                ];
              },
              icon: const Icon(Icons.delete),
            ),
        ],
      ),
    );
  }
}
