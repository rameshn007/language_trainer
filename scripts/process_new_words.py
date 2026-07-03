import json
import os

SOURCE_FILE = "assets/data/source.md"
VERB_PHRASES_FILE = "assets/data/verb_phrases.json"
INTERROGATIVES_FILE = "assets/data/interrogatives.json"

# Data for expansion (I'll fill this with phrases generated from my knowledge)
EXPANSIONS = {
    "chinelos": [
        ("Vou calçar os meus chinelos", "I'm going to put on my flip flops"),
        ("Perdi um chinelo na praia", "I lost a flip flop at the beach"),
        ("Estes chinelos são muito confortáveis", "These flip flops are very comfortable")
    ],
    "chinelos de quarto": [
        ("Uso chinelos de quarto no inverno", "I use house slippers in winter"),
        ("Onde estão os meus chinelos de quarto?", "Where are my house slippers?")
    ],
    "curto dos lados e atrás": [
        ("Quero o cabelo curto dos lados e atrás, por favor", "I want the hair short on the sides and back, please"),
        ("Он prefere o corte curto dos lados e atrás", "He prefers the short cut on the sides and back")
    ],
    "respirar": [
        ("É importante respirar ar fresco", "It is important to breathe fresh air"),
        ("Eu respiro fundo quando estou calmo", "I breathe deeply when I am calm"),
        ("Ele não consegue respirar bem", "He cannot breathe well")
    ],
    "verão": [
        ("Eu gosto de ir à praia no verão", "I like to go to the beach in summer"),
        ("O verão em Portugal é muito quente", "The summer in Portugal is very hot"),
        ("No verão os dias são mais longos", "In summer the days are longer")
    ],
    "comboio": [
        ("Vou para Lisboa de comboio", "I'm going to Lisbon by train"),
        ("A que horas parte o comboio?", "What time does the train depart?"),
        ("O comboio está atrasado dez minutos", "The train is ten minutes late")
    ],
    "lavar": [
        ("Vou lavar as mãos antes de comer", "I'm going to wash my hands before eating"),
        ("Ela lava a loiça depois do jantar", "She washes the dishes after dinner"),
        ("Precisas de lavar o teu carro", "You need to wash your car")
    ],
    "vestir": [
        ("Tenho de me vestir para a festa", "I have to get dressed for the party"),
        ("Eu visto uma camisola azul", "I wear a blue sweater"),
        ("Ajuda o menino a vestir o casaco", "Help the boy put on his coat")
    ],
    # ... I'll add more in the final script
}

def main():
    with open("extracted_words.json", "r") as f:
        words = json.load(f)

    # Update source.md
    with open(SOURCE_FILE, "a") as f:
        f.write("\n# Expansion from more_words_1.md\n\n")
        f.write("| Portugues | English | Notes |\n")
        f.write("| :---- | :---- | :---- |\n")
        for item in words:
            pt = item['pt']
            en = item['en']
            f.write(f"| {pt} | {en} | New Vocabulary |\n")
            
            # Add expansions if defined
            if pt in EXPANSIONS:
                for exp_pt, exp_en in EXPANSIONS[pt]:
                    f.write(f"| {exp_pt} | {exp_en} | Expansion |\n")

    # Update verb_phrases.json
    verbs_to_add = [
        {"verb": "respirar", "pt": "Eu respiro fundo.", "en": "I breathe deeply."},
        {"verb": "lavar", "pt": "Eu lavo as mãos.", "en": "I wash my hands."},
        {"verb": "vestir", "pt": "Eu visto-me rapidamente.", "en": "I get dressed quickly."},
        {"verb": "despir", "pt": "Ele despe o casaco.", "en": "He takes off his coat."},
        {"verb": "sentir", "pt": "Eu sinto-me feliz hoje.", "en": "I feel happy today."},
        {"verb": "sentar", "pt": "Nós sentamo-nos na sala.", "en": "We sit in the living room."},
        {"verb": "levantar", "pt": "Eu levanto-me às sete horas.", "en": "I get up at seven o'clock."},
        {"verb": "deitar", "pt": "A que horas te deitas?", "en": "What time do you go to bed?"},
        {"verb": "estimar", "pt": "Eu estimo muito a sua ajuda.", "en": "I greatly value your help."},
        {"verb": "resumir", "pt": "Podes resumir a história?", "en": "Can you summarize the story?"},
    ]
    
    if os.path.exists(VERB_PHRASES_FILE):
        with open(VERB_PHRASES_FILE, "r") as f:
            verb_data = json.load(f)
        
        for v in verbs_to_add:
            verb_data.append({
                "verb": v["verb"],
                "portuguese": v["pt"],
                "english": v["en"]
            })
            
        with open(VERB_PHRASES_FILE, "w") as f:
            json.dump(verb_data, f, indent=2, ensure_ascii=False)

    print("Processed words and updated source/verb_phrases.")

if __name__ == "__main__":
    main()
