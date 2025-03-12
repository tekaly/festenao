import 'package:flutter/material.dart';

class InfoTile extends StatelessWidget {
  final String? value;
  final String? label;
  final bool showIfValueEmpty;
  final VoidCallback? onTap;

  const InfoTile({
    super.key,
    this.value,
    this.label,
    this.showIfValueEmpty = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!showIfValueEmpty) {
      if (value?.isEmpty ?? true) {
        return Container();
      }
    }
    return ListTile(
      onTap: onTap,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null)
            Text(label!, style: Theme.of(context).textTheme.bodySmall),
          if (value != null) Text(value!),
        ],
      ),
    );
  }
}
