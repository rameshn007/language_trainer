import json
import os

# 1. Update assets/data/phrases.json
phrases_path = "assets/data/phrases.json"
with open(phrases_path, "r", encoding="utf-8") as f:
    phrases = json.load(f)

new_phrases = [
    {"portuguese": "Para quem é o café?", "english": "Who is the coffee for?"},
    {"portuguese": "É para mim, obrigado!", "english": "It's for me, thank you!"},
    {"portuguese": "Para ti, qual é a melhor praia portuguesa?", "english": "For you, which is the best Portuguese beach?"},
    {"portuguese": "Dr. Pedro, este dossiê é para si.", "english": "Dr. Pedro, this dossier is for you."},
    {"portuguese": "Esta carta chegou para vocês.", "english": "This letter arrived for you."},
    {"portuguese": "Paula, espera por mim.", "english": "Paula, wait for me."},
    {"portuguese": "Lembro-me muitas vezes de ti.", "english": "I often remember you."},
    {"portuguese": "A Sara dá o casaco ao filho.", "english": "Sara gives the coat to her son."},
    {"portuguese": "A Sara dá-lhe o casaco.", "english": "Sara gives him the coat."},
    {"portuguese": "O Peter não telefona à mãe.", "english": "Peter doesn't call his mother."},
    {"portuguese": "O Peter não lhe telefona.", "english": "Peter doesn't call her."}
]

# Avoid duplicates
existing_pt = set(p["portuguese"] for p in phrases)
for p in new_phrases:
    if p["portuguese"] not in existing_pt:
        phrases.append(p)

with open(phrases_path, "w", encoding="utf-8") as f:
    json.dump(phrases, f, ensure_ascii=False, indent=2)

# 2. Update assets/data/exercises/prepositional_pronouns.json
prep_path = "assets/data/exercises/prepositional_pronouns.json"
with open(prep_path, "r", encoding="utf-8") as f:
    prep_quizzes = json.load(f)

new_prep_quizzes = [
    {
      "id": "prep_pron_para_mim",
      "questionText": "É para ____, obrigado! (for me)",
      "options": ["mim", "eu", "me", "minha"],
      "correctAnswer": "mim",
      "type": "cloze",
      "sourceItem": {
        "id": "prep_pron_para_mim_src",
        "portuguese": "para mim",
        "english": "for me",
        "notes": "Prepositional pronoun"
      },
      "category": "Prepositional Pronouns"
    },
    {
      "id": "prep_pron_para_ti",
      "questionText": "Para ____, qual é a melhor praia portuguesa? (for you - informal)",
      "options": ["ti", "tu", "te", "tua"],
      "correctAnswer": "ti",
      "type": "cloze",
      "sourceItem": {
        "id": "prep_pron_para_ti_src",
        "portuguese": "para ti",
        "english": "for you",
        "notes": "Prepositional pronoun"
      },
      "category": "Prepositional Pronouns"
    },
    {
      "id": "prep_pron_para_si",
      "questionText": "Dr. Pedro, este dossiê é para ____. (for you - formal)",
      "options": ["si", "você", "ele", "o senhor"],
      "correctAnswer": "si",
      "type": "cloze",
      "sourceItem": {
        "id": "prep_pron_para_si_src",
        "portuguese": "para si",
        "english": "for you (formal)",
        "notes": "Prepositional pronoun"
      },
      "category": "Prepositional Pronouns"
    },
    {
      "id": "prep_pron_para_voces",
      "questionText": "Esta carta chegou para ____. (for you all)",
      "options": ["vocês", "vós", "vos", "si"],
      "correctAnswer": "vocês",
      "type": "cloze",
      "sourceItem": {
        "id": "prep_pron_para_voces_src",
        "portuguese": "para vocês",
        "english": "for you all",
        "notes": "Prepositional pronoun"
      },
      "category": "Prepositional Pronouns"
    },
    {
      "id": "prep_pron_por_mim",
      "questionText": "Paula, espera por ____. (for me)",
      "options": ["mim", "eu", "me", "comigo"],
      "correctAnswer": "mim",
      "type": "cloze",
      "sourceItem": {
        "id": "prep_pron_por_mim_src",
        "portuguese": "por mim",
        "english": "for me",
        "notes": "Prepositional pronoun"
      },
      "category": "Prepositional Pronouns"
    },
    {
      "id": "prep_pron_de_ti",
      "questionText": "Lembro-me muitas vezes de ____. (of you - informal)",
      "options": ["ti", "tu", "te", "contigo"],
      "correctAnswer": "ti",
      "type": "cloze",
      "sourceItem": {
        "id": "prep_pron_de_ti_src",
        "portuguese": "de ti",
        "english": "of you",
        "notes": "Prepositional pronoun"
      },
      "category": "Prepositional Pronouns"
    }
]

existing_prep_ids = set(q["id"] for q in prep_quizzes)
for q in new_prep_quizzes:
    if q["id"] not in existing_prep_ids:
        prep_quizzes.append(q)

with open(prep_path, "w", encoding="utf-8") as f:
    json.dump(prep_quizzes, f, ensure_ascii=False, indent=2)

# 3. Create assets/data/exercises/indirect_object_pronouns.json
ind_path = "assets/data/exercises/indirect_object_pronouns.json"
new_ind_quizzes = [
  {
    "id": "indir_pron_1",
    "questionText": "A Sara dá o casaco ao filho. -> A Sara dá-____ o casaco.",
    "options": ["lhe", "o", "lo", "lhe a"],
    "correctAnswer": "lhe",
    "type": "cloze",
    "sourceItem": {
      "id": "indir_pron_1_src",
      "portuguese": "lhe",
      "english": "to him/her",
      "notes": "Indirect Object Pronoun"
    },
    "category": "Indirect Object Pronouns"
  },
  {
    "id": "indir_pron_2",
    "questionText": "O Peter não telefona à mãe. -> O Peter não ____ telefona.",
    "options": ["lhe", "a", "la", "lha"],
    "correctAnswer": "lhe",
    "type": "cloze",
    "sourceItem": {
      "id": "indir_pron_2_src",
      "portuguese": "lhe",
      "english": "to him/her",
      "notes": "Indirect Object Pronoun"
    },
    "category": "Indirect Object Pronouns"
  },
  {
    "id": "indir_pron_3",
    "questionText": "Eu dou um presente a ti. -> Eu dou-____ um presente.",
    "options": ["te", "ti", "lhe", "me"],
    "correctAnswer": "te",
    "type": "cloze",
    "sourceItem": {
      "id": "indir_pron_3_src",
      "portuguese": "te",
      "english": "to you",
      "notes": "Indirect Object Pronoun"
    },
    "category": "Indirect Object Pronouns"
  },
  {
    "id": "indir_pron_4",
    "questionText": "Eles explicam a lição a nós. -> Eles explicam-____ a lição.",
    "options": ["nos", "nós", "vos", "lhes"],
    "correctAnswer": "nos",
    "type": "cloze",
    "sourceItem": {
      "id": "indir_pron_4_src",
      "portuguese": "nos",
      "english": "to us",
      "notes": "Indirect Object Pronoun"
    },
    "category": "Indirect Object Pronouns"
  },
  {
    "id": "indir_pron_5",
    "questionText": "Nós escrevemos aos nossos amigos. -> Nós escrevemos-____.",
    "options": ["lhes", "os", "los", "lhes a"],
    "correctAnswer": "lhes",
    "type": "cloze",
    "sourceItem": {
      "id": "indir_pron_5_src",
      "portuguese": "lhes",
      "english": "to them",
      "notes": "Indirect Object Pronoun"
    },
    "category": "Indirect Object Pronouns"
  }
]
with open(ind_path, "w", encoding="utf-8") as f:
    json.dump(new_ind_quizzes, f, ensure_ascii=False, indent=2)

print("Content successfully updated.")
