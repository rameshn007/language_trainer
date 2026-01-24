import json
import random
import re

SOURCE_FILE = "assets/data/source.md"
OUTPUT_FILE = "assets/data/questions.json"

def parse_markdown(file_path):
    items = []
    with open(file_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    # Simple table parser
    # Looking for lines starting with | and containing at least 2 pipes
    for line in lines:
        line = line.strip()
        if not line.startswith("|"):
            continue
        
        parts = [p.strip() for p in line.split("|")]
        # parts[0] is empty (before first |)
        # parts[1] is Portuguese
        # parts[2] is English
        # parts[3] is Notes (optional)
        
        if len(parts) >= 4:
            pt = parts[1]
            en = parts[2]
            
            # Skip header and separator lines
            if "Portugues" in pt or "---" in pt:
                continue
            
            # Skip empty lines
            if not pt and not en:
                continue

            # Basic cleanup of markdown bold/italics if necessary
            pt = pt.replace("**", "").replace("*", "")
            en = en.replace("**", "").replace("*", "")

            # If there are notes, we stick them in 'notes' field but we mainly use pt/en
            notes = parts[3] if len(parts) > 3 else ""
            
            items.append({
                "pt": pt,
                "en": en,
                "notes": notes
            })
    return items

def get_distractors(correct_item, all_items, key_type="en"):
    """
    Selects 3 random distractors.
    """
    options = [correct_item[key_type]]
    max_attempts = 50
    attempts = 0
    
    while len(options) < 4 and attempts < max_attempts:
        attempts += 1
        random_item = random.choice(all_items)
        candidate = random_item[key_type]
        
        # Avoid duplicates, empty strings, and identical content
        if candidate not in options and candidate.strip() != "":
            options.append(candidate)
            
    # If we couldn't find enough unique distractors, fill with placeholders (unlikely in large set)
    while len(options) < 4:
        options.append("---")
        
    random.shuffle(options)
    return options

def main():
    raw_data = parse_markdown(SOURCE_FILE)
    print(f"Parsed {len(raw_data)} items from {SOURCE_FILE}")
    
    questions = []
    id_counter = 1

    for item in raw_data:
        # 1. PT -> EN (Multiple Choice)
        # "What is the English translation of '...'"
        q_obj = {
            "id": f"q_{id_counter:03}",
            "type": "multipleChoice",
            "question": f"What is the English translation of '{item['pt']}'?",
            "options": get_distractors(item, raw_data, "en"),
            "answer": item["en"],
            "sourceItem": item["pt"]
        }
        questions.append(q_obj)
        id_counter += 1

        # 2. EN -> PT (Multiple Choice)
        # "How do you say '...' in Portuguese?"
        q_obj_rev = {
            "id": f"q_{id_counter:03}",
            "type": "multipleChoice",
            "question": f"How do you say '{item['en']}' in Portuguese?",
            "options": get_distractors(item, raw_data, "pt"),
            "answer": item["pt"],
            "sourceItem": item["pt"]
        }
        questions.append(q_obj_rev)
        id_counter += 1
        
        # 3. CLOZE (Fill in the blank) for phrases longer than 2 words
        # Only if it's a sentence/phrase, not single words
        pt_text = item['pt']
        words = pt_text.split()
        
        # Filter out very short words or punctuation tokens for masking
        valid_indices = []
        for i, w in enumerate(words):
            clean_w = w.strip(".,?!();:/")
            if len(clean_w) > 3: # Only mask words > 3 chars
                valid_indices.append(i)
                
        if len(words) > 2 and valid_indices:
            # Create a cloze question
            idx = random.choice(valid_indices)
            target_word_raw = words[idx]
            target_word_clean = target_word_raw.strip(".,?!();:/")
            
            # Create sentence with blank
            words_clone = list(words)
            words_clone[idx] = "______"
            cloze_sentence = " ".join(words_clone)
            
            # Generate distractors that are single words from other Portuguese items
            # We want distractors that look like words, not full phrases
            distractors = [target_word_clean]
            
            # Collect all single words from dataset to use as distractors
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
                "sourceItem": item["pt"]
            }
            questions.append(q_obj_cloze)
            id_counter += 1

    # Save to file
    with open(OUTPUT_FILE, 'w', encoding='utf-8') as f:
        json.dump(questions, f, indent=2, ensure_ascii=False)

    print(f"Successfully generated {len(questions)} questions in '{OUTPUT_FILE}'")

if __name__ == "__main__":
    main()
