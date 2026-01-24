import os

filename = "Ramesh __ Filomena - Aula de português (Portuguese class).md"

replacements = {
    # Blocks that failed previously due to escapes
    "| Que..? \+ nome Que comida preferes? | What/Which \+ noun? What food do you prefer? | a que horas \- at what time |":
    "| Que..? \+ nome | What/Which \+ noun? | a que horas \- at what time |\n| Que comida preferes? | What food do you prefer? |  |",

    "| O que…? \+ verbo O que fazes no fim de semana? O que fazes ao fim de semana? | also what \+ verb?  What do you do this weekend? (specific) What do you do on weekends? (general) | Que \- qoo |":
    "| O que…? \+ verbo | Also what \+ verb? | Que \- qoo |\n| O que fazes no fim de semana? | What do you do this weekend? (specific) |  |\n| O que fazes ao fim de semana? | What do you do on weekends? (general) |  |",

    "| Qual…? Qual é a tua cor favorita? | What or which singular What is your favorite color | a tua \- your a tua cor \- your car Qual é \- singular |":
    "| Qual…? | What or which (singular)? | a tua \- your a tua cor \- your car Qual é \- singular |\n| Qual é a tua cor favorita? | What is your favorite color? |  |",

    "| Quais…? Quais são as tuas músicas favoritas? | What or which plural What are your favorite musics \- plural | Quais são \- plural |":
    "| Quais…? | What or which (plural)? | Quais são \- plural |\n| Quais são as tuas músicas favoritas? | What are your favorite musics? |  |",

    "| Quanto..? Quanto custa? Quanto tempo leva a viagem? | How much? How much does it cost How long does the trip take? | leva \- take |":
    "| Quanto..? | How much? | leva \- take |\n| Quanto custa? | How much does it cost? |  |\n| Quanto tempo leva a viagem? | How long does the trip take? |  |",

    "| Quantos..? Quantos anos tens? | How many? How old are you? | Tenho \- I have |":
    "| Quantos..? | How many? | Tenho \- I have |\n| Quantos anos tens? | How old are you? |  |",

    "| Porque…? Porque estás triste? Estás triste? Porquê? | Why? Why are you sad? Are you sad? Why? | Porque \- Porku Porquê \- Porkay |":
    "| Porque…? | Why? | Porque \- Porku Porquê \- Porkay |\n| Porque estás triste? | Why are you sad? |  |\n| Estás triste? | Are you sad? |  |\n| Porquê? | Why? |  |"
}

with open(filename, 'r') as f:
    content = f.read()

count = 0
for old, new in replacements.items():
    if old in content:
        content = content.replace(old, new)
        count += 1
    else:
        print(f"Warning: Could not find exact line:\n{old}")

with open(filename, 'w') as f:
    f.write(content)

print(f"Replaced {count} blocks.")
