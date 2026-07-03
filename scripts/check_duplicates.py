
def check_duplicates():
    source_file = "assets/data/source.md"
    seen = {}
    duplicates = []
    
    with open(source_file, 'r', encoding='utf-8') as f:
        lines = f.readlines()
        
    for i, line in enumerate(lines):
        line = line.strip()
        if not line.startswith("|"): continue
        if "Portugues" in line or ":---" in line: continue
        
        parts = [p.strip() for p in line.split("|")]
        if len(parts) < 3: continue
        
        # parts[0] is empty
        pt = parts[1]
        en = parts[2]
        
        # Emulate MarkdownParser ID generation logic (conceptually unique key)
        key = f"{pt}_{en}"
        
        if key in seen:
            duplicates.append((i+1, key))
        else:
            seen[key] = i+1
            
    if duplicates:
        print(f"Found {len(duplicates)} duplicates:")
        for line_num, key in duplicates:
            print(f"Line {line_num}: {key} (First seen at Line {seen[key]})")
    else:
        print("No duplicates found based on PT_EN key.")

if __name__ == "__main__":
    check_duplicates()
