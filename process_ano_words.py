import re

input_file = "assets/ano_words_phrases.md"
output_file = "assets/data/source.md"

generated_phrases = [
    ("Eu moro aqui há dois anos", "I have lived here for two years", "Generated from há"),
    ("Estou à espera há uma hora", "I have been waiting for an hour", "Generated from há"),
    ("Trabalho aqui desde janeiro", "I have worked here since January", "Generated from desde"),
    ("Ela vive no Porto desde 2010", "She has lived in Porto since 2010", "Generated from desde"),
    ("Eles vão casar-se no próximo ano", "They are going to get married next year", "Generated from casar-se"),
    ("O avô deixou uma grande herança", "The grandfather left a big inheritance", "Generated from herança"),
    ("Vem cá, por favor", "Come here, please", "Generated from cá/lá"),
    ("Ela está lá em cima", "She is up there", "Generated from cá/lá"),
    ("Este carro é tão rápido como o outro", "This car is as fast as the other", "Generated from tao"),
    ("Eu tenho tanta fome como tu", "I am as hungry as you", "Generated from tanto"),
    ("Não faças tanto barulho", "Don't make so much noise", "Generated from tanto"),
    ("As reuniões presenciais são melhores", "Face-to-face meetings are better", "Generated from presencial")
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
    f.write("\n# New Words and Phrases from assets/ano_words_phrases.md\n\n")
    f.write("| Portugues | English | Notes |\n")
    f.write("| :---- | :---- | :---- |\n")
    
    # Write original items
    for pt, en, note in new_items:
        f.write(f"| {pt} | {en} | {note} |\n")
        
    # Write generated items
    for pt, en, note in generated_phrases:
        f.write(f"| {pt} | {en} | {note} |\n")

print(f"Appended {len(new_items)} original items and {len(generated_phrases)} generated phrases to {output_file}")
