import 'package:flutter/material.dart';

class SaveChatDialog extends StatefulWidget {
  final int messageCount;
  
  const SaveChatDialog({
    super.key,
    required this.messageCount,
  });

  @override
  State<SaveChatDialog> createState() => _SaveChatDialogState();
}

class _SaveChatDialogState extends State<SaveChatDialog> {
  final TextEditingController _titleController = TextEditingController();
  bool _saveChat = true;
  
  @override
  void initState() {
    super.initState();
    _titleController.text = 'Chat ${DateTime.now().toString().substring(0, 10)}';
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          Icon(
            Icons.save_alt,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          const Text('Save Chat Messages?'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This chat contains ${widget.messageCount} messages. Would you like to save them for future reference?',
            style: TextStyle(color: Colors.grey[700]),
          ),
          const SizedBox(height: 20),
          SwitchListTile(
            value: _saveChat,
            onChanged: (value) {
              setState(() {
                _saveChat = value;
              });
            },
            title: const Text('Save this chat'),
            subtitle: Text(
              _saveChat 
                ? 'Messages will be saved locally on both devices'
                : 'Messages will be deleted',
              style: TextStyle(
                fontSize: 12,
                color: _saveChat ? Colors.green : Colors.orange,
              ),
            ),
            activeColor: Theme.of(context).colorScheme.primary,
            contentPadding: EdgeInsets.zero,
          ),
          if (_saveChat) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Chat Title',
                hintText: 'Enter a name for this chat',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.label_outline),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              maxLength: 50,
            ),
          ],
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.blue[700],
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Both users will be notified when the chat is saved',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(null);
          },
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_saveChat) {
              final title = _titleController.text.trim();
              Navigator.of(context).pop({
                'save': true,
                'title': title.isNotEmpty ? title : null,
              });
            } else {
              Navigator.of(context).pop({'save': false});
            }
          },
          child: Text(_saveChat ? 'Save' : 'Don\'t Save'),
        ),
      ],
    );
  }
}