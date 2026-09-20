import 'package:flutter/material.dart';

class NoteListScreen extends StatelessWidget {
  final String folder;

  const NoteListScreen({super.key, required this.folder});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(folder),
      ),
      body: Center(
        child: Text('Notes for $folder will appear here.'),
      ),
    );
  }
}
