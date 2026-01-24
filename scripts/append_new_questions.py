
NEW_ITEMS = [
    # Daily Routine (20)
    ("Eu acordo às 7 horas", "I wake up at 7 o'clock", "Daily Routine - New"),
    ("Eu tomo duche", "I take a shower", "Daily Routine - New"),
    ("Eu escovo os dentes", "I brush my teeth", "Daily Routine - New"),
    ("Eu visto-me", "I get dressed", "Daily Routine - New"),
    ("Eu penteio o cabelo", "I comb my hair", "Daily Routine - New"),
    ("Eu saio de casa", "I leave the house", "Daily Routine - New"),
    ("Eu vou para o trabalho", "I go to work", "Daily Routine - New"),
    ("Eu começo a trabalhar", "I start working", "Daily Routine - New"),
    ("Eu almoço ao meio-dia", "I have lunch at midday", "Daily Routine - New"),
    ("Eu acabo o trabalho às 18h", "I finish work at 6pm", "Daily Routine - New"),
    ("Eu vou às compras", "I go shopping", "Daily Routine - New"),
    ("Eu faço o jantar", "I make dinner", "Daily Routine - New"),
    ("Eu lavo a loiça", "I wash the dishes", "Daily Routine - New"),
    ("Eu vejo televisão", "I watch television", "Daily Routine - New"),
    ("Eu leio um livro", "I read a book", "Daily Routine - New"),
    ("Eu vou para a cama", "I go to bed", "Daily Routine - New"),
    ("Eu adormeço", "I fall asleep", "Daily Routine - New"),
    ("Eu limpo a casa", "I clean the house", "Daily Routine - New"),
    ("Eu lavo a roupa", "I wash the clothes", "Daily Routine - New"),
    ("Eu descanso", "I rest", "Daily Routine - New"),

    # Shopping (20)
    ("Quanto custa isto?", "How much does this cost?", "Shopping - New"),
    ("É muito caro", "It is very expensive", "Shopping - New"),
    ("É barato", "It is cheap", "Shopping - New"),
    ("Posso pagar com cartão?", "Can I pay with card?", "Shopping - New"),
    ("Aceitam dinheiro?", "Do you accept cash?", "Shopping - New"),
    ("O troco", "The change", "Shopping - New"),
    ("O saco", "The bag", "Shopping - New"),
    ("A loja", "The shop", "Shopping - New"),
    ("Aberto", "Open", "Shopping - New"),
    ("Fechado", "Closed", "Shopping - New"),
    ("Eu quero comprar isto", "I want to buy this", "Shopping - New"),
    ("Tem um tamanho maior?", "Do you have a bigger size?", "Shopping - New"),
    ("Tem um tamanho menor?", "Do you have a smaller size?", "Shopping - New"),
    ("Posso experimentar?", "Can I try it on?", "Shopping - New"),
    ("Onde são os provadores?", "Where are the fitting rooms?", "Shopping - New"),
    ("Estou só a ver, obrigado", "I am just looking, thanks", "Shopping - New"),
    ("Onde é o mercado?", "Where is the market?", "Shopping - New"),
    ("Quilo", "Kilo", "Shopping - New"),
    ("Litro", "Litre", "Shopping - New"),
    ("Caixa", "Checkout/Box", "Shopping - New"),

    # Health & Emergency (20)
    ("Estou doente", "I am sick", "Health - New"),
    ("Tenho febre", "I have a fever", "Health - New"),
    ("Tenho dor de cabeça", "I have a headache", "Health - New"),
    ("Tenho dor de barriga", "I have a stomach ache", "Health - New"),
    ("Preciso de um médico", "I need a doctor", "Health - New"),
    ("Chame uma ambulância", "Call an ambulance", "Health - New"),
    ("Onde é o hospital?", "Where is the hospital?", "Health - New"),
    ("Farmácia", "Pharmacy", "Health - New"),
    ("Medicamento", "Medicine", "Health - New"),
    ("Ajuda!", "Help!", "Health - New"),
    ("Fogo!", "Fire!", "Health - New"),
    ("Polícia", "Police", "Health - New"),
    ("Estou perdido", "I am lost", "Health - New"),
    ("Sinto-me mal", "I feel bad", "Health - New"),
    ("Tenho uma alergia", "I have an allergy", "Health - New"),
    ("Dói-me aqui", "It hurts here", "Health - New"),
    ("É uma emergência", "It is an emergency", "Health - New"),
    ("Cuidado!", "Careful!", "Health - New"),
    ("Perigo", "Danger", "Health - New"),
    ("Pare!", "Stop!", "Health - New"),

    # Weather (20)
    ("Está sol", "It is sunny", "Weather - New"),
    ("Está nublado", "It is cloudy", "Weather - New"),
    ("Está vento", "It is windy", "Weather - New"),
    ("Está frio", "It is cold", "Weather - New"),
    ("Está calor", "It is hot", "Weather - New"),
    ("Vai chover", "It is going to rain", "Weather - New"),
    ("A neve", "The snow", "Weather - New"),
    ("A tempestade", "The storm", "Weather - New"),
    ("O céu", "The sky", "Weather - New"),
    ("O sol", "The sun", "Weather - New"),
    ("A lua", "The moon", "Weather - New"),
    ("As estrelas", "The stars", "Weather - New"),
    ("O inverno", "The winter", "Weather - New"),
    ("O verão", "The summer", "Weather - New"),
    ("A primavera", "The spring", "Weather - New"),
    ("O outono", "The autumn", "Weather - New"),
    ("Graus", "Degrees", "Weather - New"),
    ("Previsão do tempo", "Weather forecast", "Weather - New"),
    ("Guarda-chuva", "Umbrella", "Weather - New"),
    ("Impermeável", "Raincoat", "Weather - New"),

    # Travel & Directions (20)
    ("O passaporte", "The passport", "Travel - New"),
    ("O bilhete", "The ticket", "Travel - New"),
    ("O aeroporto", "The airport", "Travel - New"),
    ("A estação de comboios", "The train station", "Travel - New"),
    ("A paragem de autocarro", "The bus stop", "Travel - New"),
    ("Partidas", "Departures", "Travel - New"),
    ("Chegadas", "Arrivals", "Travel - New"),
    ("Atrasado", "Delayed", "Travel - New"),
    ("Cancelado", "Cancelled", "Travel - New"),
    ("Reserva", "Reservation", "Travel - New"),
    ("Hotel", "Hotel", "Travel - New"),
    ("Quarto duplo", "Double room", "Travel - New"),
    ("Quarto individual", "Single room", "Travel - New"),
    ("Bagagem", "Luggage", "Travel - New"),
    ("Mapa", "Map", "Travel - New"),
    ("Entrada", "Entrance", "Travel - New"),
    ("Saída", "Exit", "Travel - New"),
    ("Empurrar", "Push", "Travel - New"),
    ("Puxar", "Pull", "Travel - New"),
    ("Informações", "Information", "Travel - New"),
]

SOURCE_FILE = "assets/data/source.md"

def main():
    with open(SOURCE_FILE, "a", encoding="utf-8") as f:
        f.write("\n# AI Generated Expansion (Stretch Goals)\n\n")
        f.write("| Portugues | English | Notes |\n")
        f.write("| :---- | :---- | :---- |\n")
        for pt, en, note in NEW_ITEMS:
            f.write(f"| {pt} | {en} | {note} |\n")
    
    print(f"Appended {len(NEW_ITEMS)} new items to {SOURCE_FILE}")

if __name__ == "__main__":
    main()
