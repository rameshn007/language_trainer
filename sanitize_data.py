import os

filename = "assets/data/source.md"

replacements = {
    # Line 137: Months
    "| janeiro, fevereiro, março,  abril, maio, junho, julho, agosto, setembro, outubro, novembro, dezembro | January, February, March, April, May, June, July, August, September, October, November, December |  |":
    """| janeiro | January |  |
| fevereiro | February |  |
| março | March |  |
| abril | April |  |
| maio | May |  |
| junho | June |  |
| julho | July |  |
| agosto | August |  |
| setembro | September |  |
| outubro | October |  |
| novembro | November |  |
| dezembro | December |  |""",

    # Line 138: Times (Manual split based on visual mapping)
    "| São 10h30,  13h40,  16h45,  19h15 É meio-dia, é meia-noite,  é 1h00 | Dez e meia (half 10\) or Dez e trinta,  Treze e quarenta,  Um quarto para as cinco da tarde (quarter to 5 in the afternoon),  dezanove e quinze (sete e um quarto da tarde) Midday,  Midnight,  1am | São \- plural é \- singular |":
    """| São 10h30 | Dez e meia (half 10) or Dez e trinta | São \- plural |
| São 13h40 | Treze e quarenta |  |
| São 16h45 | Um quarto para as cinco da tarde (quarter to 5 in the afternoon) |  |
| São 19h15 | dezanove e quinze (sete e um quarto da tarde) |  |
| É meio-dia | Midday | é \- singular |
| É meia-noite | Midnight | é \- singular |
| É 1h00 | 1am | é \- singular |""",

    # Line 143: Prepositions
    "| **a, de, em, para, por, sem, com, até, desde, sobre** | **a \= at/to, de \= of/from, em \= in/on, para \= for/to, por \= by/for(period time)/because,  sem \= without,  com \= With até \= Until, desde \= Since, sobre \= about** | **Be careful to not mix para and por Sem, com, até desde, sobre \- not combined with articles (not modified)** |":
    """| **a** | **at/to** | **Be careful to not mix para and por** |
| **de** | **of/from** |  |
| **em** | **in/on** |  |
| **para** | **for/to** |  |
| **por** | **by/for(period time)/because** |  |
| **sem** | **without** | **Sem, com, até desde, sobre \- not combined with articles (not modified)** |
| **com** | **With** |  |
| **até** | **Until** |  |
| **desde** | **Since** |  |
| **sobre** | **about** |  |""",

    # Line 141: Arrival times (Split by / and 'or')
    "| Chego a casa às 19h30/ao meio-dia/à meia-noite | I arrive at home at 7:30pm or at midday or at midnight | Midday (meio) \- masculine Midnight (meia) \- feimine |":
    """| Chego a casa às 19h30 | I arrive at home at 7:30pm |  |
| Chego a casa ao meio-dia | I arrive at home at midday | Midday (meio) \- masculine |
| Chego a casa à meia-noite | I arrive at home at midnight | Midnight (meia) \- feimine |""",

    # Line 156: Train/Bus (Split by /)
    "| Eu vou de comboio para Lisboa/eu vou de autocarro | I go of train to Lisbon (not specific)/I take the bus | Comboio \- train de comboio \- a train no comboio \- the train |":
    """| Eu vou de comboio para Lisboa | I go of train to Lisbon (not specific) | Comboio \- train de comboio \- a train no comboio \- the train |
| eu vou de autocarro | I take the bus |  |""",

    # Line 154: Watch film (Split by / in notes mostly, but Portuguese has slashes for grammar examples? No, looks like separate sentences)
    # "vi/ver/estou a ver/vou ver" in notes. The main part seems okay?
    # | Na segunda-feira vi um filme ótimo | Last Monday I watched a great film | ...
    # This one seems fine as one row.

    # Line 148: Weekend
    "| No (em+o=no) próximo fim de semana/ No fim de semana passado | The next weekend/The last weekend | No (combo of in the) \- can be last weekend or next weekend, specific weekend |":
    """| No (em+o=no) próximo fim de semana | The next weekend | No (combo of in the) \- can be last weekend or next weekend, specific weekend |
| No fim de semana passado | The last weekend |  |""",
    
    # Line 149
     "| Daqui (de+aqui) a duas semanas | From here two weeks (in two weeks onwards) |  |":
     "| Daqui (de+aqui) a duas semanas | From here two weeks (in two weeks onwards) |  |", # No change needed actually, just checking

     # Line 144: Summer/Spring... + Supermarket
     # Let's split the supermarket part at least.
     "| Eu vou à praia no verão/primavera/outono/inverno Eu vou ao supermercado | I go to the beach in the summer/spring/autumn/winter I go to the supermarket (masculine) | Verão \- summer no \= in+the \- pr. nu à \= to (combo of preposition and article when pointing left) |":
     """| Eu vou à praia no verão/primavera/outono/inverno | I go to the beach in the summer/spring/autumn/winter | Verão \- summer no \= in+the \- pr. nu à \= to |
| Eu vou ao supermercado | I go to the supermarket (masculine) |  |""",
     
     # Line 126: Adverbs
     "| Nunca, raramente, às vezes, normalmente/habitualmente, frequentemente, sempre | Never, rarely, sometimes, normally (usually)/habitually, often, always |  |":
     """| Nunca | Never |  |
| Raramente | Rarely |  |
| Às vezes | Sometimes |  |
| Normalmente/Habitualmente | Normally (usually)/habitually |  |
| Frequentemente | Often |  |
| Sempre | Always |  |"""

}

with open(filename, 'r') as f:
    content = f.read()

count = 0
for old, new in replacements.items():
    if old in content:
        content = content.replace(old, new)
        count += 1
    else:
        # Try finding partial match or warn
        print(f"Warning: Could not find exact line:\n{old[:50]}...")

with open(filename, 'w') as f:
    f.write(content)

print(f"Replaced {count} blocks.")
