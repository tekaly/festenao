import 'package:flutter/material.dart';

class EntryTile extends StatefulWidget {
  final String? label;
  final String? value;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  const EntryTile({
    super.key,
    this.label,
    this.value,
    this.onTap,
    this.onLongPress,
  });

  @override
  State<EntryTile> createState() => _EntryTileState();
}

class _EntryTileState extends State<EntryTile> {
  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(widget.label ?? '-- no label --'),
      subtitle: Text(widget.value ?? ''),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      trailing: const Icon(Icons.navigate_next),
    );
  }
}
