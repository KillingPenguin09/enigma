#!/usr/bin/env python3
import json
import os
import sys

def get_emojis():
    # Only load emojis once and output all of them
    emoji_file = os.path.expanduser("~/.local/share/bemoji/emojis.txt")
    if not os.path.exists(emoji_file):
        print("[]")
        return

    items = []
    with open(emoji_file, 'r', encoding='utf-8') as f:
        for i, line in enumerate(f):
            line = line.strip()
            if not line: continue
            parts = line.split(" ", 1)
            if len(parts) == 2:
                items.append({
                    "id": str(i),
                    "emojiChar": parts[0],
                    "content": line,
                    "type": "text",
                    "pinned": False,
                    "sectionCategory": "Emojis"
                })

    print(json.dumps(items))

if __name__ == "__main__":
    get_emojis()
