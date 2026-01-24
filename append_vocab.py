
NEW_CONTENT = """
# Fri 24 Jan 2026 (AI Expansion)

| Portugues | English | Notes |
| :---- | :---- | :---- |
| O avô | The grandfather | Family |
| A avó | The grandmother | Family |
| O tio | The uncle | Family |
| A tia | The aunt | Family |
| O primo | The cousin (male) | Family |
| A prima | The cousin (female) | Family |
| O marido | The husband | Family |
| A mulher / A esposa | The wife | Family |
| O irmão | The brother | Family |
| A irmã | The sister | Family |
| O menu, por favor | The menu, please | Restaurant |
| A conta, por favor | The bill, please | Restaurant |
| Água (sem gás / com gás) | Water (still / sparking) | Drinks |
| Vinho tinto | Red wine | Drinks |
| Vinho branco | White wine | Drinks |
| Uma cerveja (imperial) | A beer (draught) | Drinks - Imperial is common for draught beer |
| Pão com manteiga | Bread with butter | Food |
| Queijo | Cheese | Food |
| Onde é a casa de banho? | Where is the bathroom? | Directions |
| Vire à esquerda | Turn left | Directions |
| Vire à direita | Turn right | Directions |
| Siga em frente | Go straight ahead | Directions |
| Fica perto | It is near | Directions |
| Fica longe | It is far | Directions |
| A rua | The street | City |
| A praça | The square | City |
| Eu tenho fome | I am hungry (have hunger) | Common Phrase |
| Eu tenho sede | I am thirsty (have thirst) | Common Phrase |
| Eu preciso de ajuda | I need help | Common Phrase |
| Eu não sei | I don't know | Common Phrase |
| Eu posso? | Can I? | Common Phrase |
"""

filename = "assets/data/source.md"

with open(filename, "a", encoding="utf-8") as f:
    f.write(NEW_CONTENT)

print("Successfully appended AI vocabulary.")
