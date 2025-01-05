import 'package:flutter/material.dart';

class ActionTile extends StatefulWidget {
  final String? label;
  final String? value;
  final VoidCallback? onTap;
  const ActionTile({super.key, this.label, this.value, this.onTap});

  @override
  State<ActionTile> createState() => _ActionTileState();
}

class _ActionTileState extends State<ActionTile> {
  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(widget.label ?? '-- no label --'),
      subtitle: Text(widget.value ?? ''),
      onTap: widget.onTap,
      trailing: const Icon(Icons.navigate_next),
    );
  }
}
