import os

INBOX_FILE = "assets/data/inbox.md"
SOURCE_FILE = "assets/data/source.md"

def main():
    if not os.path.exists(INBOX_FILE):
        print("No inbox file found.")
        return

    with open(INBOX_FILE, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    new_items = []
    for line in lines:
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
            
        parts = [p.strip() for p in stripped.split("|")]
        pt = parts[0]
        en = parts[1] if len(parts) > 1 else ""
        notes = "Inbox Item"
        
        new_items.append((pt, en, notes))
    
    if not new_items:
        print("No new items in inbox.")
        return

    with open(SOURCE_FILE, 'a', encoding='utf-8') as f:
        f.write("\n# Inbox Ingested Items\n")
        
        # Check if we need to write header (if file was empty?) assumed file exists and has table
        # We just append rows
        for pt, en, note in new_items:
            f.write(f"| {pt} | {en} | {note} |\n")
            
    # Clear inbox
    with open(INBOX_FILE, 'w', encoding='utf-8') as f:
        f.write("# Vocabulary Inbox\n# Add new words or phrases here (one per line).\n# Format: Portuguese phrase (or just the word)\n# You can also add English translation separated by '|' if you know it.\n")
        
    print(f"Ingested {len(new_items)} items from inbox to {SOURCE_FILE}")

if __name__ == "__main__":
    main()
