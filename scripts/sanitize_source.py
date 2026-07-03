import re

SOURCE_FILE = "assets/data/source.md"

def sanitize_line(pt, en, notes):
    """
    Splits a single row into multiple rows if delimiters are found.
    Returns a list of tuples (pt, en, notes).
    """
    items = []
    
    # 1. Split by '?' if there are multiple questions
    # Regex lookahead to split after '?' but keep it, or just split common patterns
    # Case: "Como está/estás?" -> Don't split "está/estás" strictly if it's just gender/form variant
    # Case: "Porque estás triste? Estás triste? Porquê?" -> Split these
    
    # Heuristic: If multiple '?' exist, split by '?'
    if pt.count('?') > 1:
        # Split by '?' and filter empty
        parts_pt = [p.strip() + "?" for p in pt.split('?') if p.strip()]
        # We need to try to split English too, but it's hard to align. 
        # Strategy: If English also has multiple '?', try to align.
        # If not, repeat English or just Note "See split".
        # For simplicity in this script, we will try to split English if counts match.
        
        parts_en = [p.strip() + "?" for p in en.split('?') if p.strip()]
        
        if len(parts_pt) == len(parts_en):
            for i in range(len(parts_pt)):
                items.append((parts_pt[i], parts_en[i], notes))
            return items
        else:
            # Mismatched counts, just keep original to avoid data loss
            # Or split PT and duplicate EN? Let's keep original for safety unless obvious.
            pass

    # 2. Split by '/'
    # Case: "devagar/depressa" -> "slowly/quickly"
    # Case: "rapido/lento" -> "fast/slow"
    # Only split if both have '/' and counts match roughly
    if '/' in pt and '/' in en:
        # Check if it's a grammar variant like "Onde fica/está" (might be same meaning) or distinct words
        # If it looks like distinct items (no spaces around slash usually), split.
        parts_pt = [p.strip() for p in pt.split('/')]
        parts_en = [p.strip() for p in en.split('/')]
        
        if len(parts_pt) == len(parts_en):
             for i in range(len(parts_pt)):
                items.append((parts_pt[i], parts_en[i], notes))
             return items
    
    # Default: return as is
    items.append((pt, en, notes))
    return items

def main():
    with open(SOURCE_FILE, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    new_lines = []
    in_table = False
    
    print(f"Processing {len(lines)} lines...")

    for line in lines:
        stripped = line.strip()
        if not stripped.startswith("|"):
            new_lines.append(line)
            continue
        
        # Check if it's a separator line
        if ":---" in line:
            new_lines.append(line)
            in_table = True
            continue
            
        # Parse table row
        parts = [p.strip() for p in stripped.split("|")]
        if len(parts) < 4:
            new_lines.append(line)
            continue
            
        # parts[0] is empty, parts[1] is PT, parts[2] is EN, parts[3] is Notes
        pt = parts[1]
        en = parts[2]
        
        # Determine notes: handle if Notes column is missing or empty
        notes = parts[3] if len(parts) > 3 else ""
        
        # Header row check
        if "Portugues" in pt:
            new_lines.append(line)
            continue
            
        # Sanitize
        split_items = sanitize_line(pt, en, notes)
        
        for s_pt, s_en, s_notes in split_items:
            # Reconstruct line
            # Preserve original indentation/spacing style if possible, but standard markdown table is fine
            new_line = f"| {s_pt} | {s_en} | {s_notes} |\n"
            new_lines.append(new_line)

    # Write back
    with open(SOURCE_FILE, 'w', encoding='utf-8') as f:
        f.writelines(new_lines)
    
    print("Sanitization complete.")

if __name__ == "__main__":
    main()
