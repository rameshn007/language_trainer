def check_missing_translations(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    missing = []
    for i, line in enumerate(lines):
        line = line.strip()
        if not line.startswith("|"):
            continue
        
        parts = [p.strip() for p in line.split("|")]
        # parts[0] is empty, parts[1] is PT, parts[2] is EN
        if len(parts) >= 3:
            pt = parts[1]
            en = parts[2]
            
            # Skip headers and separators
            if "Portugues" in pt or "---" in pt:
                continue
                
            if pt and not en:
                missing.append((i + 1, pt))
                
    return missing

if __name__ == "__main__":
    missing = check_missing_translations("assets/data/source.md")
    if missing:
        print(f"Found {len(missing)} rows with missing English translations:")
        for line_num, text in missing:
            print(f"Line {line_num}: {text}")
    else:
        print("No missing translations found.")
