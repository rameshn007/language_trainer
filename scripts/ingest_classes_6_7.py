import json
import os
import subprocess

# 1. Base items from Class 6
CLASS_6_ITEMS = [
    ("dossiê", "folder / dossier", "Office & Work"),
    ("esperar por", "to wait for (something or someone)", "Grammar & Verbs"),
    ("esperar que", "to hope that", "Grammar & Verbs"),
    ("o teu marido", "your husband", "Family & People"),
    ("Podes ir ao cinema sem mim", "You can go to the cinema without me", "Conversational Phrases"),
    ("proposta", "proposal", "Office & Work"),
    ("uma proposta de trabalho", "a job proposal", "Office & Work"),
    ("uma proposta de negócio", "a business proposal", "Office & Work"),
    ("namorado", "boyfriend", "Family & People"),
    ("namorada", "girlfriend", "Family & People"),
    ("a melhor forma de conhecer", "the best way to get to know (places or things)", "Conversational Phrases"),
    ("a melhor forma", "the best way (feminine)", "Conversational Phrases"),
    ("a melhor maneira", "the best way (feminine)", "Conversational Phrases"),
    ("o melhor modo", "the best way (masculine)", "Conversational Phrases"),
    ("Para quem são estes óculos? Para si.", "Who are these glasses for? For you (formal).", "Conversational Phrases"),
    ("relatório", "report", "Office & Work"),
    ("relojoaria", "watch shop / watchmaker", "Shopping"),
    ("joalharia", "jewellery shop", "Shopping"),
    ("meses", "months", "Time & Numbers"),
    ("estações do ano", "seasons of the year", "Time & Numbers"),
    ("em junho", "in June", "Time & Numbers"),
    ("na (em + a)", "in the / on the (feminine)", "Grammar & Verbs"),
    ("no (em + o)", "in the / on the (masculine)", "Grammar & Verbs"),
    ("formação", "training / course", "Office & Work"),
    ("Em fevereiro, vamos fazer uma formação", "In February, we are going to do a training course", "Office & Work"),
    ("dar formação", "to provide training", "Office & Work"),
    ("um formador", "a trainer", "Office & Work"),
    ("treinador", "sports manager / coach", "Sports & Leisure"),
    ("Em julho, tenho de viajar para fora do país", "In July, I have to travel outside the country", "Travel & Directions"),
    ("No outono, vou levar as crianças à escola", "In autumn, I take the children to school", "Daily Routine"),
    ("Em janeiro, posso fazer esqui", "In January, I can ski", "Sports & Leisure"),
    ("Na primavera, costumo tirar fotografias na natureza", "In spring, I usually take photographs in nature", "Hobbies & Leisure"),
    ("tirar a carta de condução", "to get one's driving licence", "Daily Life"),
    ("tirar a carteira da mala", "to take the wallet out of the bag", "Daily Life"),
    ("tirar", "to take out / remove / take (photos)", "Grammar & Verbs"),
    ("levar", "take", "Grammar & Verbs (to take / carry)"),
    ("Em maio, eu e os meus amigos fazemos piqueniques no parque", "In May, my friends and I have picnics in the park", "Hobbies & Leisure"),
    ("No inverno, a minha família gosta de ir ao mercado de natal", "In winter, my family likes to go to the Christmas market", "Hobbies & Leisure"),
    ("quando", "when (time)", "Connectors"),
    ("porque", "because / why (cause)", "Connectors"),
    ("mas", "but", "Connectors (opposition)"),
    ("e", "and (addition)", "Connectors"),
    ("parar", "to stop", "Grammar & Verbs"),
    ("pare", "stop (formal imperative)", "Grammar & Verbs"),
    ("paragem", "bus stop / stop", "Travel & Directions"),
    ("mais cedo", "earlier", "Time & Numbers"),
    ("atender o telefone", "to answer the phone", "Daily Routine"),
    ("atender um cliente", "to serve / assist a customer", "Office & Work"),
    ("atendimento ao cliente", "customer service", "Office & Work"),
    ("junto", "close / near / together", "Travel & Directions"),
]

# 2. Base items from Class 7
CLASS_7_ITEMS = [
    ("direita e esquerda", "right and left / forehand and backhand", "Sports & Leisure"),
    ("serviço", "serve (tennis) / service", "Sports & Leisure"),
    ("volei", "volley (tennis)", "Sports & Leisure"),
    ("smash", "smash (tennis)", "Sports & Leisure"),
    ("cruzada", "cross-court (tennis)", "Sports & Leisure"),
    ("ao longo", "down the line (tennis)", "Sports & Leisure"),
    ("um ás", "an ace (tennis)", "Sports & Leisure"),
    ("dupla falta", "double fault (tennis)", "Sports & Leisure"),
    ("um ponto ganhante", "a winner / winning point (tennis)", "Sports & Leisure"),
    ("40 igual", "40-all / deuce (tennis)", "Sports & Leisure"),
    ("vantagem", "advantage (tennis)", "Sports & Leisure"),
    ("vantagem nula", "no advantage / sudden death (tennis)", "Sports & Leisure"),
    ("agradar", "to please", "Grammar & Verbs"),
    ("por isso", "therefore / that is why", "Connectors"),
    ("arrumam a sala", "they tidy up the living room", "Daily Routine"),
    ("arrumar", "to organize / tidy up", "Grammar & Verbs"),
    ("dele", "his / of him", "Grammar & Verbs"),
    ("dela", "hers / of her", "Grammar & Verbs"),
    ("os filhos dele", "his children", "Family & People"),
    ("os filhos dela", "her children", "Family & People"),
    ("vão trazer", "they are going to bring", "Grammar & Verbs"),
    ("Eles estão no supermercado", "They are at the supermarket", "Shopping"),
    ("Eu tenho teste amanhã, mas hoje não consigo estudar", "I have a test tomorrow, but today I cannot study", "School & Study"),
    ("porque estou doente", "because I am sick", "Health"),
    ("porque corre todos os dias", "because he/she runs every day", "Sports & Leisure"),
    ("todos os dias", "every day", "Time & Numbers"),
    ("todo o dia", "all day long", "Time & Numbers"),
    ("Ela quer muito ir ao cinema connosco, mas, infelizmente, não pode", "She really wants to go to the cinema with us, but, unfortunately, she cannot", "Conversational Phrases"),
    ("os netos", "the grandchildren", "Family & People"),
    ("o neto", "the grandson", "Family & People"),
    ("a neta", "the granddaughter", "Family & People"),
    ("quando recebe", "when he/she receives / welcomes", "Conversational Phrases"),
    ("põem a música mais baixa", "they turn the music down", "Daily Life"),
    ("mais alto", "louder / higher", "Basics"),
    ("fala mais alto", "speak louder", "Conversational Phrases"),
    ("pôr a mesa", "to set the table", "Daily Routine"),
    ("levantar a mesa", "to clear the table", "Daily Routine"),
    ("este autor", "this author (masculine)", "Arts & Literature"),
    ("esta autora", "this author (feminine)", "Arts & Literature"),
    ("gosto muito de", "I like ... very much", "Conversational Phrases"),
    ("gosto muito deste livro", "I like this book very much", "Conversational Phrases"),
    ("Eu só vou à praia quando está bom tempo", "I only go to the beach when the weather is good", "Hobbies & Leisure"),
    ("alguém", "someone / somebody", "Basics"),
    ("ninguém", "nobody / no one", "Basics"),
    ("gorro", "winter hat (wollen hat)", "Clothing (beanie / woolen hat)"),
    ("Hoje, está muito frio. É melhor vestir um casaco mais quente e levar o gorro.", "Today is very cold. It is better to wear a warmer coat and take a woolen hat.", "Weather & Clothing"),
    ("Quando viajam pela Península Ibérica, os turistas americanos acham que Portugal é tão bonito como Espanha", "When traveling through the Iberian Peninsula, American tourists think Portugal is as beautiful as Spain.", "Travel & Directions"),
    ("A Rita e o irmão fazem geocaching há dois anos. É um passatempo ótimo para as pessoas que gostam de aventura.", "Rita and her brother have been doing geocaching for two years. It is a great hobby for people who like adventure.", "Hobbies & Leisure"),
    ("passatempo", "hobby / pastime", "Hobbies & Leisure"),
    ("Desde a última aula de português, o Nuno consegue compreender melhor os pronomes pessoais", "Since the last Portuguese class, Nuno understands personal pronouns better.", "Grammar & Verbs"),
    ("pronomes pessoais", "personal pronouns", "Grammar & Verbs"),
    ("Sr. Carlos, eu dou-lhe a senha para ligar o computador", "Mr. Carlos, I give you the password to turn on the computer", "Office & Work"),
    ("senha", "password", "Office & Work"),
    ("ligar o computador", "to turn on the computer", "Office & Work"),
]

# 3. Screenshot Sentences
SCREENSHOT_SENTENCES = [
    ("Nós vamos sair de casa quando parar de chover.", "We are going to leave the house when it stops raining.", "Conjunctions & Grammar"),
    ("A Isabel vai passar o fim de semana com a Vitória porque são amigas.", "Isabel is going to spend the weekend with Vitória because they are friends.", "Conjunctions & Grammar"),
    ("Nós gostamos de sair à noite, mas raramente vamos à discoteca.", "We like to go out at night, but we rarely go to the disco.", "Conjunctions & Grammar"),
    ("Amanhã, vai chover, e, no fim de semana, vai estar sol.", "Tomorrow it is going to rain, and at the weekend it is going to be sunny.", "Conjunctions & Grammar"),
    ("A minha mãe está em casa, mas não atende o telefone.", "My mother is at home, but doesn't answer the phone.", "Conjunctions & Grammar"),
    ("A Carla e o Rodrigo estão a viajar porque estão de férias.", "Carla and Rodrigo are traveling because they are on vacation.", "Conjunctions & Grammar"),
    ("A Mariana está cansada porque trabalha muito.", "Mariana is tired because she works a lot.", "Conjunctions & Grammar"),
    ("A Luísa vive junto ao mar, mas não gosta de peixe.", "Luísa lives by the sea, but doesn't like fish.", "Conjunctions & Grammar"),
    ("Quando está sol, vamos correr à beira-mar.", "When it is sunny, we go running by the sea.", "Conjunctions & Grammar"),
    ("Os alunos ouvem a gravação e resolvem o exercício.", "The students listen to the recording and solve the exercise.", "Conjunctions & Grammar"),
    ("Normalmente, eu faço exercícios para rever a matéria.", "Normally, I do exercises to review the material.", "Conjunctions & Grammar"),
    ("Amanhã, eu também vou fazer exercícios para rever a matéria.", "Tomorrow, I will also do exercises to review the material.", "Conjunctions & Grammar"),
    ("A Vera e a irmã são muito simpáticas.", "Vera and her sister are very friendly.", "Conjunctions & Grammar"),
    ("A Vera é tão simpática como a irmã.", "Vera is as friendly as her sister.", "Conjunctions & Grammar"),
    ("São 15:30. Tu estás na biblioteca há 30 minutos.", "It is 15:30. You have been in the library for 30 minutes.", "Conjunctions & Grammar"),
    ("Tu estás na biblioteca desde as 15:00.", "You have been in the library since 15:00.", "Conjunctions & Grammar"),
    ("Carlos, eu dou-te a senha para ligar o computador.", "Carlos, I give you (informal) the password to turn on the computer.", "Conjunctions & Grammar"),
    ("Nós fazemos esqui na Serra da Estrela em janeiro.", "We go skiing in Serra da Estrela in January.", "Conjunctions & Grammar"),
    ("Eles fazem esqui na Serra da Estrela no inverno.", "They go skiing in Serra da Estrela in winter.", "Conjunctions & Grammar"),
]

# 4. Expanded Related Items (A1/A2 Variations)
EXPANDED_ITEMS = [
    ("Eu espero pelo autocarro na paragem.", "I wait for the bus at the bus stop.", "Expansion - Daily Life"),
    ("Nós esperamos que o tempo melhore amanhã.", "We hope that the weather improves tomorrow.", "Expansion - Conversational"),
    ("Ele recebeu uma nova proposta de trabalho.", "He received a new job proposal.", "Expansion - Work"),
    ("Qual é a melhor forma de chegar ao centro?", "What is the best way to get to the center?", "Expansion - Travel"),
    ("Eu preciso de escrever um relatório hoje.", "I need to write a report today.", "Expansion - Work"),
    ("Eles vão dar formação aos novos funcionários.", "They are going to give training to new employees.", "Expansion - Work"),
    ("Eu levo os meus filhos ao parque ao sábado.", "I take my children to the park on Saturday.", "Expansion - Daily Routine"),
    ("Ela tirou fotografias muito bonitas em Sintra.", "She took very beautiful photographs in Sintra.", "Expansion - Leisure"),
    ("Podes atender o telefone, por favor?", "Can you answer the phone, please?", "Expansion - Daily Life"),
    ("O funcionário atende o cliente na receção.", "The employee assists the customer at the reception.", "Expansion - Work"),
    ("O café fica junto à estação de comboios.", "The café is right next to the train station.", "Expansion - Travel"),
    ("Aos fins de semana, jogo ténis com o meu irmão.", "At weekends, I play tennis with my brother.", "Expansion - Sports"),
    ("O jogador fez um serviço muito forte.", "The player made a very strong serve.", "Expansion - Sports"),
    ("Nós ganhámos o ponto decisivo na rede.", "We won the decisive point at the net.", "Expansion - Sports"),
    ("Está 40 igual no último jogo.", "It is 40-all in the last game.", "Expansion - Sports"),
    ("Eles arrumam a casa todos os sábados de manhã.", "They tidy up the house every Saturday morning.", "Expansion - Daily Routine"),
    ("Podes ajudar-me a pôr a mesa para o almoço?", "Can you help me set the table for lunch?", "Expansion - Daily Routine"),
    ("Depois de jantar, nós levantamos a mesa.", "After dinner, we clear the table.", "Expansion - Daily Routine"),
    ("Está muito barulho, fala mais alto, por favor.", "It is very noisy, speak louder, please.", "Expansion - Conversational"),
    ("Eles puseram a televisão mais baixa para descansar.", "They turned the television down to rest.", "Expansion - Daily Life"),
    ("O Porto é tão bonito como Lisboa.", "Porto is as beautiful as Lisbon.", "Expansion - Comparisons"),
    ("Este restaurante é tão acolhedor como o outro.", "This restaurant is as welcoming as the other.", "Expansion - Comparisons"),
    ("Eu moro nesta cidade há cinco anos.", "I have lived in this city for five years.", "Expansion - Time"),
    ("Estou à espera do comboio há vinte minutos.", "I have been waiting for the train for twenty minutes.", "Expansion - Time"),
    ("Eles estudam português desde o mês passado.", "They have been studying Portuguese since last month.", "Expansion - Time"),
    ("O museu está aberto desde as nove da manhã.", "The museum is open since nine in the morning.", "Expansion - Time"),
    ("No verão, nós vamos passar férias ao Algarve.", "In summer, we go on holiday to the Algarve.", "Expansion - Seasons"),
    ("Na primavera, os jardins de Lisboa ficam floridos.", "In spring, the gardens of Lisbon are in bloom.", "Expansion - Seasons"),
    ("No outono, as folhas das árvores caem no chão.", "In autumn, tree leaves fall to the ground.", "Expansion - Seasons"),
    ("No inverno, faz muito frio e uso um gorro quente.", "In winter, it is very cold and I wear a warm beanie.", "Expansion - Seasons"),
    ("Hoje estou cansado, por isso vou para a cama mais cedo.", "Today I am tired, therefore I am going to bed earlier.", "Expansion - Connectors"),
    ("Ele não comprou o bilhete, por isso não pode entrar.", "He didn't buy the ticket, therefore he cannot enter.", "Expansion - Connectors"),
    ("Nós ficamos em casa quando chove muito.", "We stay at home when it rains a lot.", "Expansion - Connectors"),
    ("Ela foi ao médico porque tinha febre alta.", "She went to the doctor because she had a high fever.", "Expansion - Connectors"),
    ("Queremos ir passear, mas o tempo está chuvoso.", "We want to go for a walk, but the weather is rainy.", "Expansion - Connectors"),
    ("Eu dou-lhe o livro quando terminar a leitura.", "I will give him/her the book when I finish reading.", "Expansion - Pronouns"),
    ("O professor explica-nos a lição com paciência.", "The teacher explains the lesson to us with patience.", "Expansion - Pronouns"),
    ("Eles mostram-lhes a cidade histórica.", "They show them the historic city.", "Expansion - Pronouns"),
    ("Não conheço ninguém nesta festa.", "I do not know anyone at this party.", "Expansion - Indefinites"),
    ("Alguém sabe onde fica a farmácia mais próxima?", "Does anyone know where the nearest pharmacy is?", "Expansion - Indefinites"),
    ("A fotografia é o meu passatempo preferido.", "Photography is my favorite hobby.", "Expansion - Leisure"),
    ("Eu preciso de ligar o computador para começar a trabalhar.", "I need to turn on the computer to start working.", "Expansion - Work"),
]

def append_to_source_md():
    source_file = "assets/data/source.md"
    with open(source_file, "r", encoding="utf-8") as f:
        existing = f.read()

    with open(source_file, "a", encoding="utf-8") as f:
        f.write("\n\n# New Words & Phrases from Class 6\n\n")
        f.write("| Portugues | English | Notes |\n")
        f.write("| :---- | :---- | :---- |\n")
        for pt, en, note in CLASS_6_ITEMS:
            f.write(f"| {pt} | {en} | {note} |\n")

        f.write("\n# New Words & Phrases from Class 7\n\n")
        f.write("| Portugues | English | Notes |\n")
        f.write("| :---- | :---- | :---- |\n")
        for pt, en, note in CLASS_7_ITEMS:
            f.write(f"| {pt} | {en} | {note} |\n")

        f.write("\n# Class Exercises & Screenshot Sentences\n\n")
        f.write("| Portugues | English | Notes |\n")
        f.write("| :---- | :---- | :---- |\n")
        for pt, en, note in SCREENSHOT_SENTENCES:
            f.write(f"| {pt} | {en} | {note} |\n")

        f.write("\n# Expanded Practical Phrases & Variations\n\n")
        f.write("| Portugues | English | Notes |\n")
        f.write("| :---- | :---- | :---- |\n")
        for pt, en, note in EXPANDED_ITEMS:
            f.write(f"| {pt} | {en} | {note} |\n")

    print(f"Appended {len(CLASS_6_ITEMS) + len(CLASS_7_ITEMS) + len(SCREENSHOT_SENTENCES) + len(EXPANDED_ITEMS)} items to {source_file}")

def append_to_combined_class_notes():
    combined_file = "assets/Combined_Portuguese_Class_Notes.md"
    with open(combined_file, "a", encoding="utf-8") as f:
        f.write("\n# Aula de português 6\n\n")
        f.write("| Portugues | English |\n")
        f.write("| :---- | :---- |\n")
        for pt, en, _ in CLASS_6_ITEMS:
            f.write(f"| {pt} | {en} |\n")

        f.write("\n# Aula de português 7\n\n")
        f.write("| Portugues | English |\n")
        f.write("| :---- | :---- |\n")
        for pt, en, _ in CLASS_7_ITEMS:
            f.write(f"| {pt} | {en} |\n")

    print(f"Appended Class 6 & 7 notes to {combined_file}")

def update_phrases_json():
    phrases_path = "assets/data/phrases.json"
    with open(phrases_path, "r", encoding="utf-8") as f:
        phrases = json.load(f)

    existing_pts = set(p["portuguese"].strip().lower() for p in phrases)

    new_candidate_phrases = [
        {"portuguese": "Nós vamos sair de casa quando parar de chover.", "english": "We are going to leave the house when it stops raining."},
        {"portuguese": "A Isabel vai passar o fim de semana com a Vitória porque são amigas.", "english": "Isabel is going to spend the weekend with Vitória because they are friends."},
        {"portuguese": "Nós gostamos de sair à noite, mas raramente vamos à discoteca.", "english": "We like to go out at night, but we rarely go to the disco."},
        {"portuguese": "Amanhã, vai chover, e, no fim de semana, vai estar sol.", "english": "Tomorrow it will rain, and at the weekend it will be sunny."},
        {"portuguese": "A minha mãe está em casa, mas não atende o telefone.", "english": "My mother is at home, but doesn't answer the phone."},
        {"portuguese": "A Carla e o Rodrigo estão a viajar porque estão de férias.", "english": "Carla and Rodrigo are traveling because they are on vacation."},
        {"portuguese": "A Mariana está cansada porque trabalha muito.", "english": "Mariana is tired because she works hard."},
        {"portuguese": "A Luísa vive junto ao mar, mas não gosta de peixe.", "english": "Luísa lives by the sea, but doesn't like fish."},
        {"portuguese": "Quando está sol, vamos correr à beira-mar.", "english": "When it is sunny, we go running by the sea."},
        {"portuguese": "Os alunos ouvem a gravação e resolvem o exercício.", "english": "The students listen to the recording and solve the exercise."},
        {"portuguese": "Normalmente, eu faço exercícios para rever a matéria.", "english": "Normally, I do exercises to review the material."},
        {"portuguese": "Amanhã, eu também vou fazer exercícios para rever a matéria.", "english": "Tomorrow, I will also do exercises to review the material."},
        {"portuguese": "A Vera é tão simpática como a irmã.", "english": "Vera is as friendly as her sister."},
        {"portuguese": "Tu estás na biblioteca desde as 15:00.", "english": "You have been in the library since 15:00."},
        {"portuguese": "Sr. Carlos, eu dou-lhe a senha para ligar o computador.", "english": "Mr. Carlos, I give you the password to turn on the computer."},
        {"portuguese": "Eles fazem esqui na Serra da Estrela no inverno.", "english": "They ski in Serra da Estrela in winter."},
        {"portuguese": "No outono, vou levar as crianças à escola.", "english": "In autumn, I take the children to school."},
        {"portuguese": "Na primavera, costumo tirar fotografias na natureza.", "english": "In spring, I usually take photographs of nature."},
        {"portuguese": "Em maio, eu e os meus amigos fazemos piqueniques no parque.", "english": "In May, my friends and I have picnics in the park."},
        {"portuguese": "No inverno, a minha família gosta de ir ao mercado de natal.", "english": "In winter, my family likes to go to the Christmas market."},
        {"portuguese": "Hoje, está muito frio. É melhor vestir um casaco mais quente e levar o gorro.", "english": "Today is very cold. It is better to wear a warmer coat and take a woolen hat."},
        {"portuguese": "A Rita e o irmão fazem geocaching há dois anos.", "english": "Rita and her brother have been doing geocaching for two years."},
        {"portuguese": "Desde a última aula de português, o Nuno consegue compreender melhor os pronomes pessoais.", "english": "Since the last Portuguese lesson, Nuno understands personal pronouns better."},
        {"portuguese": "Ela quer muito ir ao cinema connosco, mas, infelizmente, não pode.", "english": "She really wants to go to the cinema with us, but, unfortunately, she cannot."},
        {"portuguese": "Eu só vou à praia quando está bom tempo.", "english": "I only go to the beach when the weather is good."},
        {"portuguese": "Hoje estou cansado, por isso vou para a cama mais cedo.", "english": "Today I am tired, therefore I go to bed earlier."},
        {"portuguese": "O Porto é tão bonito como Lisboa.", "english": "Porto is as beautiful as Lisbon."},
        {"portuguese": "Podes ajudar-me a pôr a mesa para o almoço?", "english": "Can you help me set the table for lunch?"},
        {"portuguese": "Depois de jantar, nós levantamos a mesa.", "english": "After dinner, we clear the table."}
    ]

    added = 0
    for p in new_candidate_phrases:
        if p["portuguese"].strip().lower() not in existing_pts:
            phrases.append(p)
            existing_pts.add(p["portuguese"].strip().lower())
            added += 1

    with open(phrases_path, "w", encoding="utf-8") as f:
        json.dump(phrases, f, ensure_ascii=False, indent=2)

    print(f"Added {added} new phrases to {phrases_path}")

def update_verb_phrases_json():
    verb_phrases_path = "assets/data/verb_phrases.json"
    with open(verb_phrases_path, "r", encoding="utf-8") as f:
        verb_phrases = json.load(f)

    existing_pts = set(vp["portuguese"].strip().lower() for vp in verb_phrases)

    new_verb_phrases = [
        {"verb": "esperar", "portuguese": "Eu espero pelo autocarro na paragem.", "english": "I wait for the bus at the bus stop."},
        {"verb": "esperar", "portuguese": "Nós esperamos que não chova amanhã.", "english": "We hope that it doesn't rain tomorrow."},
        {"verb": "atender", "portuguese": "A rececionista atende o telefone rapidamente.", "english": "The receptionist answers the phone quickly."},
        {"verb": "atender", "portuguese": "O empregado atende os clientes com simpatia.", "english": "The employee serves the customers with friendliness."},
        {"verb": "arrumar", "portuguese": "Eles arrumam a sala antes de receber os convidados.", "english": "They tidy up the living room before receiving the guests."},
        {"verb": "pôr", "portuguese": "Eu ponho a mesa todos os dias antes do jantar.", "english": "I set the table every day before dinner."},
        {"verb": "levantar", "portuguese": "Nós levantamos a mesa depois da refeição.", "english": "We clear the table after the meal."},
        {"verb": "tirar", "portuguese": "Ela tira a carteira da mala para pagar.", "english": "She takes the wallet out of her bag to pay."},
        {"verb": "levar", "portuguese": "Eu levo as crianças à escola todas as manhãs.", "english": "I take the children to school every morning."},
        {"verb": "conseguir", "portuguese": "Hoje eu não consigo estudar porque estou doente.", "english": "Today I cannot study because I am sick."},
        {"verb": "fazer", "portuguese": "Nós fazemos esqui na serra no inverno.", "english": "We go skiing in the mountains in winter."},
        {"verb": "ligar", "portuguese": "Eu ligo o computador às nove da manhã.", "english": "I turn on the computer at nine in the morning."}
    ]

    added = 0
    for vp in new_verb_phrases:
        if vp["portuguese"].strip().lower() not in existing_pts:
            verb_phrases.append(vp)
            existing_pts.add(vp["portuguese"].strip().lower())
            added += 1

    with open(verb_phrases_path, "w", encoding="utf-8") as f:
        json.dump(verb_phrases, f, ensure_ascii=False, indent=2)

    print(f"Added {added} new verb phrases to {verb_phrases_path}")

def create_conjunctions_exercise():
    exercise_path = "assets/data/exercises/unit_conjunctions.json"
    questions = [
        {
            "id": "conj_q1",
            "questionText": "A minha mãe está em casa, ____ não atende o telefone.",
            "options": ["mas", "porque", "quando", "e"],
            "correctAnswer": "mas",
            "type": "cloze",
            "sourceItem": {
                "id": "conj_src_1",
                "portuguese": "mas",
                "english": "but (opposition)",
                "notes": "Screenshot 2 - Exercise 27 Example"
            },
            "category": "Conjunctions"
        },
        {
            "id": "conj_q2",
            "questionText": "A Carla e o Rodrigo estão a viajar ____ estão de férias.",
            "options": ["porque", "mas", "quando", "e"],
            "correctAnswer": "porque",
            "type": "cloze",
            "sourceItem": {
                "id": "conj_src_2",
                "portuguese": "porque",
                "english": "because (cause)",
                "notes": "Screenshot 2 - Exercise 27a"
            },
            "category": "Conjunctions"
        },
        {
            "id": "conj_q3",
            "questionText": "A Mariana está cansada ____ trabalha muito.",
            "options": ["porque", "mas", "e", "quando"],
            "correctAnswer": "porque",
            "type": "cloze",
            "sourceItem": {
                "id": "conj_src_3",
                "portuguese": "porque",
                "english": "because (cause)",
                "notes": "Screenshot 2 - Exercise 27b"
            },
            "category": "Conjunctions"
        },
        {
            "id": "conj_q4",
            "questionText": "A Luísa vive junto ao mar, ____ não gosta de peixe.",
            "options": ["mas", "porque", "e", "quando"],
            "correctAnswer": "mas",
            "type": "cloze",
            "sourceItem": {
                "id": "conj_src_4",
                "portuguese": "mas",
                "english": "but (opposition)",
                "notes": "Screenshot 2 - Exercise 27c"
            },
            "category": "Conjunctions"
        },
        {
            "id": "conj_q5",
            "questionText": "____ está sol, vamos correr à beira-mar.",
            "options": ["Quando", "Porque", "Mas", "E"],
            "correctAnswer": "Quando",
            "type": "cloze",
            "sourceItem": {
                "id": "conj_src_5",
                "portuguese": "quando",
                "english": "when (time)",
                "notes": "Screenshot 2 - Exercise 27d"
            },
            "category": "Conjunctions"
        },
        {
            "id": "conj_q6",
            "questionText": "Os alunos ouvem a gravação ____ resolvem o exercício.",
            "options": ["e", "mas", "quando", "porque"],
            "correctAnswer": "e",
            "type": "cloze",
            "sourceItem": {
                "id": "conj_src_6",
                "portuguese": "e",
                "english": "and (addition)",
                "notes": "Screenshot 2 - Exercise 27e"
            },
            "category": "Conjunctions"
        },
        {
            "id": "conj_q7",
            "questionText": "Nós vamos sair de casa ____ parar de chover.",
            "options": ["quando", "porque", "mas", "e"],
            "correctAnswer": "quando",
            "type": "cloze",
            "sourceItem": {
                "id": "conj_src_7",
                "portuguese": "quando",
                "english": "when (time)",
                "notes": "Screenshot 1 - Example 1"
            },
            "category": "Conjunctions"
        },
        {
            "id": "conj_q8",
            "questionText": "A Isabel vai passar o fim de semana com a Vitória ____ são amigas.",
            "options": ["porque", "mas", "quando", "e"],
            "correctAnswer": "porque",
            "type": "cloze",
            "sourceItem": {
                "id": "conj_src_8",
                "portuguese": "porque",
                "english": "because (cause)",
                "notes": "Screenshot 1 - Example 2"
            },
            "category": "Conjunctions"
        },
        {
            "id": "conj_q9",
            "questionText": "Nós gostamos de sair à noite, ____ raramente vamos à discoteca.",
            "options": ["mas", "porque", "quando", "e"],
            "correctAnswer": "mas",
            "type": "cloze",
            "sourceItem": {
                "id": "conj_src_9",
                "portuguese": "mas",
                "english": "but (opposition)",
                "notes": "Screenshot 1 - Example 3"
            },
            "category": "Conjunctions"
        },
        {
            "id": "conj_q10",
            "questionText": "Amanhã, vai chover, ____, no fim de semana, vai estar sol.",
            "options": ["e", "mas", "porque", "quando"],
            "correctAnswer": "e",
            "type": "cloze",
            "sourceItem": {
                "id": "conj_src_10",
                "portuguese": "e",
                "english": "and (addition)",
                "notes": "Screenshot 1 - Example 4"
            },
            "category": "Conjunctions"
        },
        {
            "id": "conj_q11",
            "questionText": "Eu tenho teste amanhã, ____ hoje não consigo estudar porque estou doente.",
            "options": ["mas", "porque", "quando", "e"],
            "correctAnswer": "mas",
            "type": "cloze",
            "sourceItem": {
                "id": "conj_src_11",
                "portuguese": "mas",
                "english": "but (opposition)",
                "notes": "Class 7"
            },
            "category": "Conjunctions"
        },
        {
            "id": "conj_q12",
            "questionText": "Hoje estou muito cansado, ____ isso vou dormir mais cedo.",
            "options": ["por", "para", "de", "em"],
            "correctAnswer": "por",
            "type": "cloze",
            "sourceItem": {
                "id": "conj_src_12",
                "portuguese": "por isso",
                "english": "therefore",
                "notes": "Class 7"
            },
            "category": "Conjunctions"
        },
        {
            "id": "conj_q13",
            "questionText": "Ela quer muito ir ao cinema connosco, ____, infelizmente, não pode.",
            "options": ["mas", "e", "porque", "quando"],
            "correctAnswer": "mas",
            "type": "cloze",
            "sourceItem": {
                "id": "conj_src_13",
                "portuguese": "mas",
                "english": "but (opposition)",
                "notes": "Class 7"
            },
            "category": "Conjunctions"
        },
        {
            "id": "conj_q14",
            "questionText": "Eu só vou à praia ____ está bom tempo.",
            "options": ["quando", "porque", "mas", "e"],
            "correctAnswer": "quando",
            "type": "cloze",
            "sourceItem": {
                "id": "conj_src_14",
                "portuguese": "quando",
                "english": "when (condition/time)",
                "notes": "Class 7"
            },
            "category": "Conjunctions"
        }
    ]

    with open(exercise_path, "w", encoding="utf-8") as f:
        json.dump(questions, f, ensure_ascii=False, indent=2)

    print(f"Created {len(questions)} questions in {exercise_path}")

def create_sentence_transformations_exercise():
    exercise_path = "assets/data/exercises/unit_sentence_transformations.json"
    questions = [
        {
            "id": "trans_q1",
            "questionText": "Normalmente, eu faço exercícios para rever a matéria. -> Amanhã, eu também ____ exercícios para rever a matéria.",
            "options": ["vou fazer", "faço", "fazia", "fiz"],
            "correctAnswer": "vou fazer",
            "type": "cloze",
            "sourceItem": {
                "id": "trans_src_1",
                "portuguese": "vou fazer",
                "english": "I am going to do",
                "notes": "Screenshot 3 - Exercise 3a (Future periphrastic)"
            },
            "category": "Grammar & Transformations"
        },
        {
            "id": "trans_q2",
            "questionText": "A Vera e a irmã são muito simpáticas. -> A Vera é tão simpática ____ a irmã.",
            "options": ["como", "que", "de", "do que"],
            "correctAnswer": "como",
            "type": "cloze",
            "sourceItem": {
                "id": "trans_src_2",
                "portuguese": "tão ... como",
                "english": "as ... as",
                "notes": "Screenshot 3 - Exercise 3b (Comparative of equality)"
            },
            "category": "Grammar & Transformations"
        },
        {
            "id": "trans_q3",
            "questionText": "São 15:30. Tu estás na biblioteca há 30 minutos. -> Tu estás na biblioteca ____ as 15:00.",
            "options": ["desde", "há", "para", "até"],
            "correctAnswer": "desde",
            "type": "cloze",
            "sourceItem": {
                "id": "trans_src_3",
                "portuguese": "desde",
                "english": "since",
                "notes": "Screenshot 3 - Exercise 3c (há vs desde)"
            },
            "category": "Grammar & Transformations"
        },
        {
            "id": "trans_q4",
            "questionText": "Carlos, eu dou-te a senha para ligar o computador. -> Sr. Carlos, eu dou-____ a senha para ligar o computador.",
            "options": ["lhe", "te", "me", "o"],
            "correctAnswer": "lhe",
            "type": "cloze",
            "sourceItem": {
                "id": "trans_src_4",
                "portuguese": "dou-lhe",
                "english": "I give you (formal)",
                "notes": "Screenshot 3 - Exercise 3d (Informal to formal pronoun)"
            },
            "category": "Grammar & Transformations"
        },
        {
            "id": "trans_q5",
            "questionText": "Nós fazemos esqui na Serra da Estrela em janeiro. -> Eles fazem esqui na Serra da Estrela ____ inverno.",
            "options": ["no", "na", "em", "pelo"],
            "correctAnswer": "no",
            "type": "cloze",
            "sourceItem": {
                "id": "trans_src_5",
                "portuguese": "no inverno",
                "english": "in winter",
                "notes": "Screenshot 3 - Exercise 3e (Preposition + season)"
            },
            "category": "Grammar & Transformations"
        },
        {
            "id": "trans_q6",
            "questionText": "Quando viajam pela Península Ibérica, os turistas acham que Portugal é tão bonito ____ Espanha.",
            "options": ["como", "que", "do que", "mais"],
            "correctAnswer": "como",
            "type": "cloze",
            "sourceItem": {
                "id": "trans_src_6",
                "portuguese": "tão bonito como",
                "english": "as beautiful as",
                "notes": "Class 7 - Comparative"
            },
            "category": "Grammar & Transformations"
        },
        {
            "id": "trans_q7",
            "questionText": "A Rita e o irmão fazem geocaching ____ dois anos.",
            "options": ["há", "desde", "para", "por"],
            "correctAnswer": "há",
            "type": "cloze",
            "sourceItem": {
                "id": "trans_src_7",
                "portuguese": "há dois anos",
                "english": "for two years",
                "notes": "Class 7 - Duration há"
            },
            "category": "Grammar & Transformations"
        },
        {
            "id": "trans_q8",
            "questionText": "____ a última aula de português, o Nuno compreende melhor os pronomes.",
            "options": ["Desde", "Há", "Com", "Para"],
            "correctAnswer": "Desde",
            "type": "cloze",
            "sourceItem": {
                "id": "trans_src_8",
                "portuguese": "desde",
                "english": "since",
                "notes": "Class 7 - Starting point desde"
            },
            "category": "Grammar & Transformations"
        },
        {
            "id": "trans_q9",
            "questionText": "____ primavera, costumo tirar fotografias na natureza.",
            "options": ["Na", "No", "Em", "Pela"],
            "correctAnswer": "Na",
            "type": "cloze",
            "sourceItem": {
                "id": "trans_src_9",
                "portuguese": "na primavera",
                "english": "in spring",
                "notes": "Class 6 - Preposition + season"
            },
            "category": "Grammar & Transformations"
        },
        {
            "id": "trans_q10",
            "questionText": "____ outono, vou levar as crianças à escola.",
            "options": ["No", "Na", "Em", "Pelo"],
            "correctAnswer": "No",
            "type": "cloze",
            "sourceItem": {
                "id": "trans_src_10",
                "portuguese": "no outono",
                "english": "in autumn",
                "notes": "Class 6 - Preposition + season"
            },
            "category": "Grammar & Transformations"
        }
    ]

    with open(exercise_path, "w", encoding="utf-8") as f:
        json.dump(questions, f, ensure_ascii=False, indent=2)

    print(f"Created {len(questions)} questions in {exercise_path}")

def update_indirect_object_pronouns_exercise():
    ind_path = "assets/data/exercises/indirect_object_pronouns.json"
    with open(ind_path, "r", encoding="utf-8") as f:
        quizzes = json.load(f)

    existing_ids = set(q["id"] for q in quizzes)

    new_pronoun_questions = [
        {
            "id": "indir_pron_carlos_senha",
            "questionText": "Sr. Carlos, eu dou-____ a senha para ligar o computador. (to you - formal)",
            "options": ["lhe", "te", "me", "nos"],
            "correctAnswer": "lhe",
            "type": "cloze",
            "sourceItem": {
                "id": "indir_pron_carlos_senha_src",
                "portuguese": "dou-lhe",
                "english": "I give you (formal)",
                "notes": "Indirect Object Pronoun - Class 7 / Screenshot 3"
            },
            "category": "Indirect Object Pronouns"
        },
        {
            "id": "indir_pron_carlos_informal",
            "questionText": "Carlos, eu dou-____ a senha para ligar o computador. (to you - informal)",
            "options": ["te", "ti", "lhe", "me"],
            "correctAnswer": "te",
            "type": "cloze",
            "sourceItem": {
                "id": "indir_pron_carlos_informal_src",
                "portuguese": "dou-te",
                "english": "I give you (informal)",
                "notes": "Indirect Object Pronoun - Class 7 / Screenshot 3"
            },
            "category": "Indirect Object Pronouns"
        },
        {
            "id": "indir_pron_explicar_materia",
            "questionText": "A professora explica-____ a matéria com atenção. (to us)",
            "options": ["nos", "nós", "lhes", "vos"],
            "correctAnswer": "nos",
            "type": "cloze",
            "sourceItem": {
                "id": "indir_pron_explicar_materia_src",
                "portuguese": "explica-nos",
                "english": "explains to us",
                "notes": "Indirect Object Pronoun"
            },
            "category": "Indirect Object Pronouns"
        },
        {
            "id": "indir_pron_dar_livro_eles",
            "questionText": "Eu dou-____ os livros amanhã. (to them)",
            "options": ["lhes", "os", "nos", "lhe"],
            "correctAnswer": "lhes",
            "type": "cloze",
            "sourceItem": {
                "id": "indir_pron_dar_livro_eles_src",
                "portuguese": "dou-lhes",
                "english": "I give them",
                "notes": "Indirect Object Pronoun"
            },
            "category": "Indirect Object Pronouns"
        }
    ]

    added = 0
    for q in new_pronoun_questions:
        if q["id"] not in existing_ids:
            quizzes.append(q)
            existing_ids.add(q["id"])
            added += 1

    with open(ind_path, "w", encoding="utf-8") as f:
        json.dump(quizzes, f, ensure_ascii=False, indent=2)

    print(f"Added {added} questions to {ind_path}")

def regenerate_quiz():
    print("Running generate_quiz.py...")
    res = subprocess.run(["python3", "generate_quiz.py"], capture_output=True, text=True)
    print(res.stdout)
    if res.stderr:
        print("STDERR:", res.stderr)

def main():
    append_to_source_md()
    append_to_combined_class_notes()
    update_verb_phrases_json()
    create_conjunctions_exercise()
    create_sentence_transformations_exercise()
    update_indirect_object_pronouns_exercise()
    regenerate_quiz()

if __name__ == "__main__":
    main()
