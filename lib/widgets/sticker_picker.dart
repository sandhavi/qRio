import 'package:flutter/material.dart';

class StickerPicker extends StatelessWidget {
  final Function(String stickerPath) onStickerSelected;
  
  const StickerPicker({
    super.key,
    required this.onStickerSelected,
  });

  static const List<Map<String, String>> stickers = [
    {'id': 'happy', 'emoji': '😊', 'name': 'Happy'},
    {'id': 'love', 'emoji': '❤️', 'name': 'Love'},
    {'id': 'sad', 'emoji': '😢', 'name': 'Sad'},
    {'id': 'laugh', 'emoji': '😂', 'name': 'Laugh'},
    {'id': 'thumbsup', 'emoji': '👍', 'name': 'Thumbs Up'},
    {'id': 'heart', 'emoji': '💕', 'name': 'Heart'},
    {'id': 'fire', 'emoji': '🔥', 'name': 'Fire'},
    {'id': 'party', 'emoji': '🎉', 'name': 'Party'},
    {'id': 'cool', 'emoji': '😎', 'name': 'Cool'},
    {'id': 'wink', 'emoji': '😉', 'name': 'Wink'},
    {'id': 'angry', 'emoji': '😠', 'name': 'Angry'},
    {'id': 'kiss', 'emoji': '😘', 'name': 'Kiss'},
    {'id': 'thinking', 'emoji': '🤔', 'name': 'Thinking'},
    {'id': 'celebrate', 'emoji': '🥳', 'name': 'Celebrate'},
    {'id': 'hug', 'emoji': '🤗', 'name': 'Hug'},
    {'id': 'star', 'emoji': '⭐', 'name': 'Star'},
    {'id': 'rocket', 'emoji': '🚀', 'name': 'Rocket'},
    {'id': 'rainbow', 'emoji': '🌈', 'name': 'Rainbow'},
    {'id': 'sun', 'emoji': '☀️', 'name': 'Sun'},
    {'id': 'moon', 'emoji': '🌙', 'name': 'Moon'},
    {'id': 'gift', 'emoji': '🎁', 'name': 'Gift'},
    {'id': 'cake', 'emoji': '🎂', 'name': 'Cake'},
    {'id': 'pizza', 'emoji': '🍕', 'name': 'Pizza'},
    {'id': 'coffee', 'emoji': '☕', 'name': 'Coffee'},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Stickers',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: stickers.length,
              itemBuilder: (context, index) {
                final sticker = stickers[index];
                return GestureDetector(
                  onTap: () {
                    onStickerSelected(sticker['id']!);
                    Navigator.pop(context);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.grey[300]!,
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        sticker['emoji']!,
                        style: const TextStyle(fontSize: 28),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue[700],
                          size: 14,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Tap a sticker to send',
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontSize: 12,
                            ),
                          ),
                        ),
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
  }
  
  static void show(BuildContext context, Function(String) onStickerSelected) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StickerPicker(
        onStickerSelected: onStickerSelected,
      ),
    );
  }
}