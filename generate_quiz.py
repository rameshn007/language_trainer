import argparse
import json
import os
import random
import re
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent
SOURCE_FILE = REPO_ROOT / "assets/data/source.md"
OUTPUT_FILE = REPO_ROOT / "assets/data/questions.json"

def parse_markdown(file_path):
    items = []
    with open(file_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    # Table parser: looks for lines starting with | and containing at least 2 pipes
    for line in lines:
        line = line.strip()
        if not line.startswith("|"):
            continue
        
        parts = [p.strip() for p in line.split("|")]
        # parts[0] is empty, parts[1] is PT, parts[2] is EN, parts[3] is Notes (optional)
        if len(parts) >= 4:
            pt = parts[1]
            en = parts[2]
            
            # Skip header and separator lines
            if "Portugues" in pt or "---" in pt:
                continue
            
            # Skip empty lines
            if not pt and not en:
                continue

            pt = pt.replace("**", "").replace("*", "")
            en = en.replace("**", "").replace("*", "")

            notes = parts[3].strip() if len(parts) > 3 else "General"
            
            # Standardized category mapping
            category = "General"
            notes_lower = notes.lower()
            
            if "family" in notes_lower or "life events" in notes_lower:
                category = "Family"
            elif "food" in notes_lower or "restaurant" in notes_lower or "drinks" in notes_lower:
                category = "Food & Drink"
            elif "directions" in notes_lower or "city" in notes_lower or "location" in notes_lower or "travel" in notes_lower:
                category = "Travel & Directions"
            elif "work" in notes_lower or "office" in notes_lower or "meeting" in notes_lower:
                category = "Office & Work"
            elif "sport" in notes_lower or "hobby" in notes_lower or "culture" in notes_lower or "free time" in notes_lower:
                category = "Hobbies & Leisure"
            elif "time" in notes_lower or "month" in notes_lower or "day" in notes_lower or "number" in notes_lower or "duration" in notes_lower or "há vs desde" in notes_lower:
                category = "Time & Numbers"
            elif "comparative" in notes_lower or "verb" in notes_lower or "action" in notes_lower or "grammar" in notes_lower or "pronoun" in notes_lower:
                category = "Grammar & Verbs"
            elif "intro" in notes_lower or "greeting" in notes_lower:
                category = "Basics"

            items.append({
                "pt": pt,
                "en": en,
                "notes": notes,
                "cat": category
            })
    return items

def get_distractors(correct_item, all_items, key_type="en"):
    """
    Selects 3 random distractors deterministically using seeded random.
    """
    options = [correct_item[key_type]]
    max_attempts = 100
    attempts = 0
    
    while len(options) < 4 and attempts < max_attempts:
        attempts += 1
        random_item = random.choice(all_items)
        candidate = random_item[key_type]
        
        # Avoid duplicates, empty strings, and identical content
        if candidate not in options and candidate.strip() != "":
            options.append(candidate)
            
    # Fallback placeholders if not enough unique distractors
    while len(options) < 4:
        options.append("---")
        
    random.shuffle(options)
    return options

def main():
    random.seed(42)

    parser = argparse.ArgumentParser(description="Generate quiz questions from source markdown.")
    parser.add_argument("--rebuild-all", action="store_true", help="Rebuild entire questions bank from scratch")
    args = parser.parse_args()

    raw_data = parse_markdown(SOURCE_FILE)
    print(f"Parsed {len(raw_data)} items from {SOURCE_FILE}")
    
    existing_questions = []
    seen_source_pts = set()
    max_id = 0

    if os.path.exists(OUTPUT_FILE) and not args.rebuild_all:
        with open(OUTPUT_FILE, 'r', encoding='utf-8') as f:
            existing_questions = json.load(f)
        for q in existing_questions:
            src = q.get('sourceItem', '').strip().lower()
            if src:
                seen_source_pts.add(src)
            m = re.match(r'q_(\d+)', q['id'])
            if m:
                max_id = max(max_id, int(m.group(1)))
        print(f"Loaded {len(existing_questions)} existing questions (max ID: q_{max_id:03})")

    questions = list(existing_questions)
    id_counter = max_id + 1

    items_to_process = []
    if args.rebuild_all or not existing_questions:
        items_to_process = raw_data
        questions = []
        id_counter = 1
    else:
        for item in raw_data:
            if item['pt'].strip().lower() not in seen_source_pts:
                items_to_process.append(item)
                seen_source_pts.add(item['pt'].strip().lower())

    print(f"Generating questions for {len(items_to_process)} new items...")

    for item in items_to_process:
        # 1. PT -> EN (Multiple Choice)
        q_obj = {
            "id": f"q_{id_counter:03}",
            "type": "multipleChoice",
            "question": f"What is the English translation of '{item['pt']}'?",
            "options": get_distractors(item, raw_data, "en"),
            "answer": item["en"],
            "sourceItem": item["pt"],
            "cat": item["cat"]
        }
        questions.append(q_obj)
        id_counter += 1

        # 2. EN -> PT (Multiple Choice)
        q_obj_rev = {
            "id": f"q_{id_counter:03}",
            "type": "multipleChoice",
            "question": f"How do you say '{item['en']}' in Portuguese?",
            "options": get_distractors(item, raw_data, "pt"),
            "answer": item["pt"],
            "sourceItem": item["pt"],
            "cat": item["cat"]
        }
        questions.append(q_obj_rev)
        id_counter += 1
        
        # 3. CLOZE (Fill in the blank) for phrases longer than 2 words
        pt_text = item['pt']
        words = pt_text.split()
        
        valid_indices = []
        for i, w in enumerate(words):
            clean_w = w.strip(".,?!();:/")
            if len(clean_w) > 3:
                valid_indices.append(i)
                
        if len(words) > 2 and valid_indices:
            idx = random.choice(valid_indices)
            target_word_raw = words[idx]
            target_word_clean = target_word_raw.strip(".,?!();:/")
            
            words_clone = list(words)
            words_clone[idx] = "______"
            cloze_sentence = " ".join(words_clone)
            
            distractors = [target_word_clean]
            
            all_pt_words = []
            for r in raw_data:
                for w in r['pt'].split():
                    clean_w = w.strip(".,?!();:/")
                    if len(clean_w) > 3:
                        all_pt_words.append(clean_w)
            
            attempt_count = 0
            while len(distractors) < 4 and attempt_count < 100:
                attempt_count += 1
                cand = random.choice(all_pt_words)
                if cand not in distractors:
                    distractors.append(cand)
            
            random.shuffle(distractors)

            q_obj_cloze = {
                "id": f"q_{id_counter:03}",
                "type": "cloze",
                "question": f"Fill in the blank: '{cloze_sentence}' ({item['en']})",
                "options": distractors,
                "answer": target_word_clean,
                "sourceItem": item["pt"],
                "cat": item["cat"]
            }
            questions.append(q_obj_cloze)
            id_counter += 1

    # Save to file
    with open(OUTPUT_FILE, 'w', encoding='utf-8') as f:
        json.dump(questions, f, indent=2, ensure_ascii=False)

    print(f"Successfully wrote {len(questions)} questions to '{OUTPUT_FILE}' (added {len(questions) - len(existing_questions)} new)")

if __name__ == "__main__":
    main()
