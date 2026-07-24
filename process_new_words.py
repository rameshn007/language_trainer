import re

input_file = "assets/new_words_phrases.md"
output_file = "assets/data/source.md"

generated_phrases = [
    ("Eu envio um presente", "I send a present", "Generated from Enviar"),
    ("Eles enviam cartas todos os dias", "They send letters every day", "Generated from Enviar"),
    ("A diretora está na escola", "The director is in the school", "Generated from A Diretora"),
    ("O diretor fala com os alunos", "The director speaks with the students", "Generated from O Diretor"),
    ("Podes emprestar-me a tua caneta?", "Can you lend me your pen?", "Generated from Emprestar"),
    ("Vou pedir um livro emprestado", "I am going to borrow a book", "Generated from pedir emprestado"),
    ("Escreve no teu caderno", "Write in your notebook", "Generated from Caderno"),
    ("A minha sobrinha é muito simpática", "My niece is very nice", "Generated from a sobrinha"),
    ("Ele pede um café", "He asks for a coffee", "Generated from pede"),
    ("Você pode ajudar-me?", "Can you help me?", "Generated from pode"),
    ("O que lhe dizes?", "What do you say to him/her?", "Generated - Indirect Pronoun"),
    ("Nós compramos-lhes um carro", "We buy a car for them", "Generated - Indirect Pronoun"),
    ("Isso é apenas um mito", "That is just a myth", "Generated from um mito"),
    ("Eu gosto de jogar com as palavras", "I like to play on words", "Generated from jogar com as palavras")
]

new_items = []
with open(input_file, "r", encoding="utf-8") as f:
    lines = f.readlines()
    for line in lines:
        if "|" in line:
            parts = [p.strip() for p in line.split("|")]
            if len(parts) >= 3:
                pt = parts[1]
                en = parts[2]
                if pt and pt.lower() != "portugues" and not pt.startswith(":--"):
                    new_items.append((pt, en, "New Vocabulary"))

with open(output_file, "a", encoding="utf-8") as f:
    f.write("\n# New Words and Phrases from assets/new_words_phrases.md\n\n")
    f.write("| Portugues | English | Notes |\n")
    f.write("| :---- | :---- | :---- |\n")
    
    # Write original items
    for pt, en, note in new_items:
        f.write(f"| {pt} | {en} | {note} |\n")
        
    # Write generated items
    for pt, en, note in generated_phrases:
        f.write(f"| {pt} | {en} | {note} |\n")

print(f"Appended {len(new_items)} original items and {len(generated_phrases)} generated phrases to {output_file}")
