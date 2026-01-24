import json
import random

# Raw data manually cleaned and exploded from "Ramesh __ Filomena - Aula de português (Portuguese class)(1).md"
#

raw_data = [
    # --- MON 12 JAN 2026 ---
    {"pt": "Chamo-me Ramesh", "en": "Call me Ramesh", "cat": "intro"},
    {"pt": "O meu nome é Ramesh", "en": "My name is Ramesh", "cat": "intro"},
    {"pt": "Eu sou o Ramesh", "en": "I am Ramesh", "cat": "intro"},
    {"pt": "Eu sou casado", "en": "I am married", "cat": "intro"},
    {"pt": "ser", "en": "to be (permanent)", "cat": "grammar"},
    {"pt": "estar", "en": "to be (temporary)", "cat": "grammar"},
    {"pt": "eu estou cansado", "en": "I am tired", "cat": "state"},
    {"pt": "Um problema", "en": "A problem", "cat": "noun"},
    {"pt": "Um dia", "en": "Day", "cat": "noun"},
    {"pt": "Um cinema", "en": "Cinema", "cat": "noun"},
    {"pt": "Um carro", "en": "A car", "cat": "noun"},
    {"pt": "Uma casa", "en": "A house", "cat": "noun"},
    {"pt": "Eu moro", "en": "I live", "cat": "verb"},
    {"pt": "vivo na Malveira", "en": "I live in Malveira", "cat": "verb"},
    {"pt": "na", "en": "in the (em+a)", "cat": "grammar"},
    {"pt": "eu tenho duas filhas", "en": "I have two daughters", "cat": "family"},
    {"pt": "uma filha tem quinze anos", "en": "One daughter is 15 years old", "cat": "family"},
    {"pt": "a outra tem doze anos", "en": "the other is 12 years old", "cat": "family"},
    {"pt": "eu tenho quarenta e nove anos", "en": "I am 49 years old", "cat": "age"},
    {"pt": "eu sou engenheiro de software", "en": "I am a software engineer", "cat": "profession"},
    {"pt": "eu sou inglês", "en": "I am English", "cat": "nationality"},
    {"pt": "eu sou de Inglaterra", "en": "I am from England", "cat": "nationality"},
    {"pt": "De India", "en": "The India", "cat": "country"},
    {"pt": "O Brazil", "en": "Brazil", "cat": "country"},
    {"pt": "O Morocco", "en": "Morocco", "cat": "country"},
    {"pt": "da", "en": "from the (e+a)", "cat": "grammar"},
    {"pt": "dos Países Baixos", "en": "The Netherlands", "cat": "country"},
    {"pt": "Da Holanda", "en": "The Holland", "cat": "country"},
    {"pt": "Eu gosto de jogar ténis", "en": "I like to play tennis", "cat": "hobby"},
    {"pt": "Eu gosto ver futebol", "en": "I like to watch football", "cat": "hobby"},
    {"pt": "Eu gosto ler", "en": "I like to read", "cat": "hobby"},
    {"pt": "Eu gosto viajar", "en": "I like to travel", "cat": "hobby"},
    {"pt": "Eu gosto passear", "en": "I like to take small trips", "cat": "hobby"},
    {"pt": "passatempos", "en": "hobbies", "cat": "noun"},
    {"pt": "atividades", "en": "Activities", "cat": "noun"},
    {"pt": "em Portugal eu gosto do clima", "en": "Things I like about Portugal are the weather", "cat": "phrase"},
    {"pt": "Gosto das pessoas", "en": "I like the people", "cat": "phrase"},
    {"pt": "Tempo", "en": "Weather/temperature", "cat": "noun"},
    {"pt": "hoje está bom tempo", "en": "Today the weather is good", "cat": "weather"},
    {"pt": "Eu gosto da doçaria portuguesa", "en": "I like the confectionary in Portugal", "cat": "food"},
    {"pt": "Eu sou vegetariano", "en": "I am vegetarian", "cat": "food"},
    {"pt": "eu não como peixe", "en": "I don't eat fish", "cat": "food"},
    {"pt": "pescetariano", "en": "Pescatarian", "cat": "food"},
    {"pt": "nem carne", "en": "Nor meat", "cat": "food"},
    {"pt": "laticinios", "en": "Milk based products", "cat": "food"},
    {"pt": "queria", "en": "I want (polite)", "cat": "polite"},
    {"pt": "queria um café, por favor", "en": "I want a coffee, please", "cat": "polite"},
    {"pt": "adeus", "en": "Goodbye", "cat": "greeting"},
    {"pt": "até já", "en": "See you very soon (within the hour)", "cat": "greeting"},
    {"pt": "até logo", "en": "See you again (slightly longer period)", "cat": "greeting"},
    {"pt": "até breve", "en": "See you shortly", "cat": "greeting"},
    {"pt": "até à próxima", "en": "See you next time", "cat": "greeting"},
    {"pt": "até amanhã", "en": "See you tomorrow", "cat": "greeting"},
    {"pt": "até sábado", "en": "See you Saturday", "cat": "greeting"},
    {"pt": "até à próxima semana", "en": "See you next week", "cat": "greeting"},
    {"pt": "Até nunca", "en": "See you never", "cat": "greeting"},
    {"pt": "boa semana!", "en": "Good week!", "cat": "greeting"},
    {"pt": "bom fim de semana!", "en": "Good weekend!", "cat": "greeting"},
    {"pt": "está bem", "en": "He is well", "cat": "state"},
    {"pt": "estou bem", "en": "I am fine", "cat": "state"},
    {"pt": "como está?", "en": "How are you (formal)?", "cat": "greeting"},
    {"pt": "como estás?", "en": "How are you (informal)?", "cat": "greeting"},
    {"pt": "muito obrigado", "en": "Thank you very much", "cat": "polite"},
    {"pt": "tudo bem?", "en": "Everything good?", "cat": "greeting"},
    {"pt": "mais ou menos", "en": "More or less", "cat": "phrase"},
    {"pt": "desculpe", "en": "Sorry (formal)", "cat": "polite"},
    {"pt": "desculpa", "en": "Sorry (informal)", "cat": "polite"},
    {"pt": "com licença", "en": "Excuse me", "cat": "polite"},
    {"pt": "posso entrar?", "en": "May I enter?", "cat": "phrase"},
    {"pt": "posso fazer uma pregunta", "en": "May I ask a question?", "cat": "phrase"},
    {"pt": "pode repetir, por favor", "en": "Can you repeat please", "cat": "phrase"},
    {"pt": "pode falar mais devagar", "en": "Can you speak more slowly", "cat": "phrase"},
    {"pt": "devagar", "en": "slowly", "cat": "adverb"},
    {"pt": "depressa", "en": "quickly", "cat": "adverb"},
    {"pt": "rápido", "en": "fast", "cat": "adverb"},
    {"pt": "lento", "en": "slow", "cat": "adverb"},
    {"pt": "falo um pouco de português", "en": "I speak a little Portuguese", "cat": "phrase"},

    # --- THUR 15 JAN 2026 ---
    {"pt": "Eu também", "en": "Me too", "cat": "phrase"},
    {"pt": "Concordo", "en": "I agree", "cat": "phrase"},
    {"pt": "Está a chover desde novembro", "en": "It has been raining since November", "cat": "weather"},
    {"pt": "Eu estou a aprender português", "en": "I am learning Portuguese", "cat": "grammar_continuous"},
    {"pt": "Estudantes", "en": "Students", "cat": "people"},
    {"pt": "Alunos", "en": "Pupils", "cat": "people"},
    {"pt": "Aprendizes", "en": "The learners", "cat": "people"},
    {"pt": "Exatamente", "en": "Exactly", "cat": "phrase"},
    {"pt": "Eu vou fazer o jantar", "en": "I go to make dinner", "cat": "food"},
    {"pt": "Refeições", "en": "Meals", "cat": "food"},
    {"pt": "pequeno-almoço", "en": "Breakfast", "cat": "food"},
    {"pt": "almoço", "en": "Lunch", "cat": "food"},
    {"pt": "Lanche", "en": "Tea-time / Snack", "cat": "food"},
    {"pt": "Jantar", "en": "Dinner", "cat": "food"},
    {"pt": "Uma fatia de bolo", "en": "Slice of cake", "cat": "food"},
    {"pt": "bolo de cenoura", "en": "carrot cake", "cat": "food"},
    {"pt": "Compreendo", "en": "I understand", "cat": "verb"},
    {"pt": "um", "en": "a (masc. singular)", "cat": "grammar"},
    {"pt": "uma", "en": "a (fem. singular)", "cat": "grammar"},
    {"pt": "uns", "en": "some (masc. plural)", "cat": "grammar"},
    {"pt": "umas", "en": "some (fem. plural)", "cat": "grammar"},
    {"pt": "Uns jogadores são do benfica", "en": "Some players are from Benfica", "cat": "phrase"},
    {"pt": "ficar", "en": "To be (location/stay)", "cat": "grammar"},
    {"pt": "Eu estou doente", "en": "I am sick", "cat": "health"},
    {"pt": "O restaurante fica no centro", "en": "The restaurant is located in the center", "cat": "location"},
    {"pt": "Encontramo-nos à porta", "en": "We meet at the door", "cat": "phrase"},
    {"pt": "Nós fomos de férias", "en": "We went on holiday", "cat": "phrase"},
    {"pt": "Nós estamos cansados", "en": "We are tired", "cat": "state"},
    {"pt": "Nós estamos felizes", "en": "We are happy", "cat": "state"},
    {"pt": "Eu estou em casa", "en": "I am at home", "cat": "location"},
    {"pt": "A casa é grande", "en": "The house is big", "cat": "desc"},
    {"pt": "A casa está limpa", "en": "The house is clean", "cat": "desc"},
    {"pt": "A caneta está em cima da mesa", "en": "The pen is on top of the table", "cat": "location"},
    {"pt": "O carro está na garagem", "en": "The car is in the garage", "cat": "location"},
    {"pt": "O quadro está na parede", "en": "The picture is on the wall", "cat": "location"},
    {"pt": "Semana passada", "en": "Last week", "cat": "time"},
    {"pt": "anteontem", "en": "day before yesterday", "cat": "time"},
    {"pt": "ontem", "en": "yesterday", "cat": "time"},
    {"pt": "hoje", "en": "today", "cat": "time"},
    {"pt": "amanhã", "en": "tomorrow", "cat": "time"},
    {"pt": "depois de amanhã", "en": "day after tomorrow", "cat": "time"},
    {"pt": "próxima semana", "en": "next week", "cat": "time"},
    {"pt": "Nunca", "en": "Never", "cat": "freq"},
    {"pt": "raramente", "en": "rarely", "cat": "freq"},
    {"pt": "às vezes", "en": "sometimes", "cat": "freq"},
    {"pt": "habitualmente", "en": "usually", "cat": "freq"},
    {"pt": "frequentemente", "en": "often", "cat": "freq"},
    {"pt": "sempre", "en": "always", "cat": "freq"},
    {"pt": "Nunca faço surf", "en": "I never surf", "cat": "hobby"},
    {"pt": "vejo sempre futebol", "en": "I always watch football", "cat": "hobby"},

    # --- MON 19 JAN 2026 ---
    {"pt": "Segunda-feira", "en": "Monday", "cat": "time"},
    {"pt": "dezanove de janeiro", "en": "19th of January", "cat": "time"},
    # NUMBERS (Exploded)
    {"pt": "Cem", "en": "100", "cat": "number"},
    {"pt": "duzentos", "en": "200", "cat": "number"},
    {"pt": "trezentos", "en": "300", "cat": "number"},
    {"pt": "quatrocentos", "en": "400", "cat": "number"},
    {"pt": "quinhentos", "en": "500", "cat": "number"},
    {"pt": "seiscentos", "en": "600", "cat": "number"},
    {"pt": "setecentos", "en": "700", "cat": "number"},
    {"pt": "oitocentos", "en": "800", "cat": "number"},
    {"pt": "novecentos", "en": "900", "cat": "number"},
    {"pt": "mil", "en": "1000", "cat": "number"},
    {"pt": "Quinhentos e cinquenta e cinco", "en": "555", "cat": "number"},
    # MONTHS (Exploded)
    {"pt": "janeiro", "en": "January", "cat": "time"},
    {"pt": "fevereiro", "en": "February", "cat": "time"},
    {"pt": "março", "en": "March", "cat": "time"},
    {"pt": "abril", "en": "April", "cat": "time"},
    {"pt": "maio", "en": "May", "cat": "time"},
    {"pt": "junho", "en": "June", "cat": "time"},
    {"pt": "julho", "en": "July", "cat": "time"},
    {"pt": "agosto", "en": "August", "cat": "time"},
    {"pt": "setembro", "en": "September", "cat": "time"},
    {"pt": "outubro", "en": "October", "cat": "time"},
    {"pt": "novembro", "en": "November", "cat": "time"},
    {"pt": "dezembro", "en": "December", "cat": "time"},
    # TIME
    {"pt": "São 10h30", "en": "It is 10:30", "cat": "time"},
    {"pt": "É meio-dia", "en": "It is midday", "cat": "time"},
    {"pt": "É meia-noite", "en": "It is midnight", "cat": "time"},
    {"pt": "Que horas são?", "en": "What time is it?", "cat": "time"},
    {"pt": "A que horas chegas?", "en": "At what time do you arrive?", "cat": "time"},
    {"pt": "Chego ao meio-dia", "en": "I arrive at midday", "cat": "time"},
    # PREPOSITIONS (Exploded)
    {"pt": "a", "en": "at/to", "cat": "grammar"},
    {"pt": "de", "en": "of/from", "cat": "grammar"},
    {"pt": "em", "en": "in/on", "cat": "grammar"},
    {"pt": "para", "en": "for/to (destination)", "cat": "grammar"},
    {"pt": "por", "en": "by/for (period)/because", "cat": "grammar"},
    {"pt": "sem", "en": "without", "cat": "grammar"},
    {"pt": "com", "en": "with", "cat": "grammar"},
    {"pt": "até", "en": "until", "cat": "grammar"},
    {"pt": "desde", "en": "since", "cat": "grammar"},
    {"pt": "sobre", "en": "about", "cat": "grammar"},
    # PHRASES / LOCATION
    {"pt": "Eu vou à praia", "en": "I go to the beach", "cat": "motion"},
    {"pt": "Eu vou ao supermercado", "en": "I go to the supermarket", "cat": "motion"},
    {"pt": "Ao fim de semana", "en": "At the weekend", "cat": "time"},
    {"pt": "Direto", "en": "Live (transmission)", "cat": "media"},
    {"pt": "Ao vivo", "en": "Live (band/person)", "cat": "media"},
    {"pt": "Este fim de semana", "en": "This weekend", "cat": "time"},
    {"pt": "Daqui a duas semanas", "en": "In two weeks", "cat": "time"},
    {"pt": "Na segunda-feira vi um filme", "en": "Last Monday I watched a film", "cat": "phrase"},
    {"pt": "Na segunda-feira vou ao cinema", "en": "Next Monday I will go to the cinema", "cat": "phrase"},
    {"pt": "Eu vou de comboio", "en": "I go by train", "cat": "transport"},
    {"pt": "Eu vou de autocarro", "en": "I go by bus", "cat": "transport"},
    {"pt": "Este presente é para ti", "en": "This present is for you", "cat": "phrase"},
    {"pt": "Este lugar está reservado", "en": "This seat is reserved", "cat": "phrase"},
    {"pt": "Para a semana", "en": "Next week", "cat": "time"},
    {"pt": "Preciso do carro por 4 dias", "en": "I need the car for 4 days", "cat": "phrase"},
    {"pt": "Pela ponte", "en": "By/Over the bridge", "cat": "direction"},
    {"pt": "há 4 meses", "en": "4 months ago", "cat": "time"},
    {"pt": "haver", "en": "there is/are", "cat": "verb"},
    {"pt": "Isto", "en": "This/That", "cat": "pronoun"},
    {"pt": "então", "en": "then", "cat": "connector"},
    {"pt": "disponivel", "en": "available", "cat": "adj"},

    # --- THU 22 JAN 2026 ---
    {"pt": "inacreditável", "en": "unbelievable", "cat": "adj"},
    # QUANDO (Exploded)
    {"pt": "Quando?", "en": "When?", "cat": "question"},
    {"pt": "Quando chegas a Portugal?", "en": "When do you arrive to Portugal?", "cat": "question"},
    # ONDE (Exploded)
    {"pt": "Onde?", "en": "Where?", "cat": "question"},
    {"pt": "Onde fica o restaurante?", "en": "Where is the restaurant?", "cat": "question"},
    {"pt": "Onde está o leite?", "en": "Where is the milk?", "cat": "question"},
    {"pt": "De onde é?", "en": "Where are you from?", "cat": "question"},
    # QUEM (Exploded)
    {"pt": "Quem?", "en": "Who?", "cat": "question"},
    {"pt": "Quem vai ao jantar?", "en": "Who is going to dinner?", "cat": "question"},
    # QUE (Exploded)
    {"pt": "Que..?", "en": "What/Which (noun)?", "cat": "question"},
    {"pt": "Que comida preferes?", "en": "What food do you prefer?", "cat": "question"},
    # O QUE (Exploded)
    {"pt": "O que..?", "en": "What (verb)?", "cat": "question"},
    {"pt": "O que fazes no fim de semana?", "en": "What do you do this weekend?", "cat": "question"},
    # QUAL/QUAIS (Exploded)
    {"pt": "Qual?", "en": "What/Which (singular)?", "cat": "question"},
    {"pt": "Qual é a tua cor favorita?", "en": "What is your favorite color?", "cat": "question"},
    {"pt": "Quais?", "en": "What/Which (plural)?", "cat": "question"},
    {"pt": "Quais são as tuas músicas favoritas?", "en": "What are your favorite musics?", "cat": "question"},
    # QUANTO (Exploded)
    {"pt": "Quanto?", "en": "How much?", "cat": "question"},
    {"pt": "Quanto custa?", "en": "How much does it cost?", "cat": "question"},
    {"pt": "Quanto tempo leva a viagem?", "en": "How long does the trip take?", "cat": "question"},
    {"pt": "Quantos anos tens?", "en": "How old are you?", "cat": "question"},
    # PORQUE (Exploded)
    {"pt": "Porque?", "en": "Why (start/middle)?", "cat": "question"},
    {"pt": "Porquê?", "en": "Why (isolated)?", "cat": "question"},
    {"pt": "Porque estás triste?", "en": "Why are you sad?", "cat": "question"},
    {"pt": "Há quanto tempo?", "en": "How long (has it been)?", "cat": "question"},
    {"pt": "Há quanto tempo vives em Lisboa?", "en": "How long have you been living in Lisbon?", "cat": "question"},
    {"pt": "Está à espera do seu amigo?", "en": "Are you waiting for your friend?", "cat": "phrase"},
    {"pt": "Para que queres?", "en": "For what do you want?", "cat": "question"},
    {"pt": "Desde quando?", "en": "Since when?", "cat": "question"},
    {"pt": "Vens", "en": "Coming from", "cat": "verb"},
    {"pt": "O eléctrico", "en": "The tram", "cat": "transport"},
    {"pt": "Em que mês estamos?", "en": "Which month are we in?", "cat": "question"},
    {"pt": "Fui", "en": "I was/went", "cat": "verb"},
    {"pt": "foste", "en": "you were/went", "cat": "verb"},
    {"pt": "roupas", "en": "clothes", "cat": "noun"},
    {"pt": "Médico", "en": "Doctor", "cat": "noun"},
    # ADVERBS (Exploded)
    {"pt": "este", "en": "this (near me)", "cat": "demonstrative"},
    {"pt": "esse", "en": "that (near you)", "cat": "demonstrative"},
    {"pt": "aquele", "en": "that (over there)", "cat": "demonstrative"},
    {"pt": "aqui", "en": "here (close to me)", "cat": "location"},
    {"pt": "aí", "en": "there (close to you)", "cat": "location"},
    {"pt": "ali", "en": "over there (far)", "cat": "location"},
    {"pt": "o teu", "en": "your", "cat": "possessive"},
    {"pt": "acaba", "en": "finishes/ends", "cat": "verb"},
    {"pt": "Volto", "en": "I come back", "cat": "verb"}
]

questions = []

def get_distractors(correct_item, all_items, key_type="en"):
    """
    Selects 3 random distractors.
    """
    options = [correct_item[key_type]]
    while len(options) < 4:
        random_item = random.choice(all_items)
        # Avoid duplicates and empty strings
        if random_item[key_type] not in options and random_item[key_type].strip() != "":
            options.append(random_item[key_type])
    random.shuffle(options)
    return options

# GENERATION LOOP
id_counter = 1

for item in raw_data:
    # 1. PT -> EN
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

    # 2. EN -> PT
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
    # We ignore very short phrases to avoid ambiguity
    if " " in item['pt'] and len(item['pt'].split()) > 2:
        words = item['pt'].split()
        # Find valid words to blank out (length > 2)
        valid_indices = [i for i, w in enumerate(words) if len(w) > 2]
        
        if valid_indices:
            idx = random.choice(valid_indices)
            removed_word = words[idx]
            # Replace with blank
            words[idx] = "_____"
            cloze_sentence = " ".join(words)
            
            # Generate distractors from other words in the dataset
            distractors = [removed_word.strip(",.?!")]
            while len(distractors) < 4:
                r_item = random.choice(raw_data)
                r_words = r_item['pt'].split()
                if r_words:
                    r_word = random.choice(r_words).strip(",.?!")
                    if r_word != removed_word.strip(",.?!") and r_word not in distractors and len(r_word) > 2:
                        distractors.append(r_word)
            random.shuffle(distractors)

            q_obj_cloze = {
                "id": f"q_{id_counter:03}",
                "type": "cloze",
                "question": f"Fill in the blank: '{cloze_sentence}' ({item['en']})",
                "options": distractors,
                "answer": removed_word.strip(",.?!"),
                "sourceItem": item["pt"]
            }
            questions.append(q_obj_cloze)
            id_counter += 1

# Save to file
with open('questions.json', 'w', encoding='utf-8') as f:
    json.dump(questions, f, indent=2, ensure_ascii=False)

print(f"Successfully generated {len(questions)} questions in 'questions.json'")
