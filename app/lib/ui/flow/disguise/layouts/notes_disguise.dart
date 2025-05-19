import 'package:flutter/material.dart';

class NotesDisguise extends StatefulWidget {
  final String correctPin;
  final VoidCallback onAuthSuccess;
  final Future<bool> Function(String) verifyPin;

  const NotesDisguise({
    super.key,
    required this.correctPin,
    required this.onAuthSuccess,
    required this.verifyPin,
  });

  @override
  State<NotesDisguise> createState() => _NotesDisguiseState();
}

class _NotesDisguiseState extends State<NotesDisguise> {
  final TextEditingController _textController = TextEditingController();
  final List<Note> _notes = [
    Note(
      title: 'Welcome to Notes',
      content:
          'This is your secure notes app. Create and manage your notes here.',
      dateTime: DateTime.now().subtract(const Duration(days: 2)),
    ),
    Note(
      title: 'Shopping List',
      content: '1. Milk\n2. Eggs\n3. Bread\n4. Fruits',
      dateTime: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _checkForPin(String text) async {
    // Extract possible pin before '='
    final regex = RegExp(r'^(\d+)=');
    final match = regex.firstMatch(text);
    if (match != null) {
      final enteredPin = match.group(1) ?? '';
      final isCorrect = await widget.verifyPin(enteredPin);
      if (isCorrect) {
        widget.onAuthSuccess();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notes'),
        backgroundColor: Colors.amber.shade700,
      ),
      body: _notes.isEmpty
          ? const Center(child: Text('No notes yet. Create your first note!'))
          : ListView.builder(
              itemCount: _notes.length,
              itemBuilder: (context, index) {
                return _buildNoteCard(_notes[index]);
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.amber.shade700,
        onPressed: () => _showNoteEditor(null),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildNoteCard(Note note) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () => _showNoteEditor(note),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                note.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                note.content.length > 100
                    ? '${note.content.substring(0, 100)}...'
                    : note.content,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                _formatDate(note.dateTime),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showNoteEditor(Note? note) {
    final bool isEditing = note != null;
    final titleController =
        TextEditingController(text: isEditing ? note.title : '');
    final contentController =
        TextEditingController(text: isEditing ? note.content : '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 16,
                left: 16,
                right: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    isEditing ? 'Edit Note' : 'New Note',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: contentController,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Content',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    onChanged: _checkForPin,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (isEditing)
                        TextButton.icon(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          label: const Text('Delete',
                              style: TextStyle(color: Colors.red)),
                          onPressed: () {
                            Navigator.pop(context);
                            setState(() {
                              _notes.remove(note);
                            });
                          },
                        )
                      else
                        const SizedBox(),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber.shade700,
                            ),
                            onPressed: () {
                              if (titleController.text.isEmpty ||
                                  contentController.text.isEmpty) {
                                return;
                              }

                              if (isEditing) {
                                note.title = titleController.text;
                                note.content = contentController.text;
                                note.dateTime = DateTime.now();
                              } else {
                                _notes.add(
                                  Note(
                                    title: titleController.text,
                                    content: contentController.text,
                                    dateTime: DateTime.now(),
                                  ),
                                );
                              }

                              Navigator.pop(context);
                              setState(() {});
                            },
                            child: Text(isEditing ? 'Save' : 'Add'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatDate(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return 'Today, ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday, ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}

class Note {
  String title;
  String content;
  DateTime dateTime;

  Note({
    required this.title,
    required this.content,
    required this.dateTime,
  });
}
