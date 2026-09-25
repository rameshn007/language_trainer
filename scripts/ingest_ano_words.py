import json
import os
import re

# 1. Base items from assets/ano_words_phrases.md (corrected and cleaned)
CLEANED_BASE_ITEMS = [
    ("há", "for (time duration) / ago", "Grammar & Time"),
    ("desde", "since / from (starting point)", "Grammar & Time"),
    ("final de tarde", "late afternoon / early evening", "Time & Numbers"),
    ("Casa da Música", "Casa da Música (Porto concert hall)", "Culture & Places"),
    ("A Maria faz visitas guiadas desde que trabalha na Casa da Música", "Maria has been giving guided tours since she started working at Casa da Música", "Conversational Phrases"),
    ("Os amigos estão na esplanada há meia hora", "The friends have been on the terrace for half an hour", "Daily Life"),
    ("A Olívia faz campismo desde criança", "Olívia has been camping since childhood", "Hobbies & Leisure"),
    ("A atleta olímpica pratica natação há mais de dez anos", "The Olympic athlete has been practicing swimming for more than ten years", "Sports & Leisure"),
    ("o nosso casamento", "our wedding / our marriage", "Family & Life Events"),
    ("casar-se", "to get married", "Grammar & Verbs"),
    ("o divórcio", "divorce", "Family & Life Events"),
    ("o testamento", "will / testament", "Law & Society"),
    ("os herdeiros", "heirs / inheritors", "Law & Society"),
    ("a herança", "inheritance", "Law & Society"),
    ("cá", "here", "Basics & Directions"),
    ("lá", "there", "Basics & Directions"),
    ("esta, essa, aquela", "this, that, that over there (feminine)", "Grammar & Pronouns"),
    ("este, esse, aquele", "this, that, that over there (masculine)", "Grammar & Pronouns"),
    ("tão", "as / so (tão + adjective/adverb + como)", "Grammar & Comparatives"),
    ("tanto", "as much / so much (tanto/a/os/as + noun + como)", "Grammar & Comparatives"),
    ("como", "as / like / how", "Connectors & Grammar"),
    ("Comer legumes é tão bom para a saúde como comer fruta", "Eating vegetables is as good for your health as eating fruit", "Health & Food"),
    ("As aulas de kizomba são tão divertidas como as aulas de samba", "Kizomba classes are as fun as samba classes", "Hobbies & Leisure"),
    ("Andar de metro é tão barato como andar de autocarro", "Taking the metro is as cheap as taking the bus", "Travel & Directions"),
    ("Nós não temos tantos livros como vocês", "We don't have as many books as you", "Daily Life"),
    ("A Teresa não tem tanto tempo livre como eu", "Teresa does not have as much free time as me", "Daily Life"),
    ("tempo livre", "free time", "Hobbies & Leisure"),
    ("Praticar futebol tem tantas vantagens como praticar andebol", "Playing football has as many advantages as playing handball", "Sports & Leisure"),
    ("presenciais", "in-person / face-to-face (plural)", "Office & Work"),
    ("eu vou em pessoa", "I go in person", "Daily Routine"),
    ("vou ter uma reunião online", "I am going to have an online meeting", "Office & Work"),
    ("vou ter uma reunião presencial", "I am going to have an in-person meeting", "Office & Work"),
]

# 2. Rich Variations
VARIATIONS = [
    # Duration vs Starting Point (há vs desde vs desde que)
    ("O Pedro estuda português há seis meses", "Pedro has been studying Portuguese for six months", "Variations - Há vs Desde"),
    ("Eles vivem em Lisboa desde 2018", "They have lived in Lisbon since 2018", "Variations - Há vs Desde"),
    ("Não vejo o meu irmão há muito tempo", "I haven't seen my brother for a long time", "Variations - Há vs Desde"),
    ("Ela trabalha como médica desde que terminou o curso", "She has worked as a doctor since she finished university", "Variations - Há vs Desde"),
    ("Estou à espera do autocarro há vinte minutos", "I have been waiting for the bus for twenty minutes", "Variations - Há vs Desde"),
    ("Nós somos amigos desde a infância", "We have been friends since childhood", "Variations - Há vs Desde"),
    ("Há quanto tempo estás em Portugal?", "How long have you been in Portugal?", "Variations - Há vs Desde"),
    ("Desde quando é que conheces o Pedro?", "Since when have you known Pedro?", "Variations - Há vs Desde"),
    ("Cheguei ao Porto há duas semanas", "I arrived in Porto two weeks ago", "Variations - Há vs Desde"),
    ("Ele não fuma desde o ano passado", "He hasn't smoked since last year", "Variations - Há vs Desde"),

    # Comparatives of Equality (tão ... como with adjectives/adverbs)
    ("O Porto é tão bonito como Lisboa", "Porto is as beautiful as Lisbon", "Variations - Comparatives"),
    ("Este exercício não é tão difícil como aquele", "This exercise is not as difficult as that one", "Variations - Comparatives"),
    ("Ela fala português tão bem como um nativo", "She speaks Portuguese as well as a native", "Variations - Comparatives"),
    ("O meu chá está tão quente como o teu", "My tea is as hot as yours", "Variations - Comparatives"),
    ("A praia de Cascais é tão calma como a praia de Sesimbra", "Cascais beach is as calm as Sesimbra beach", "Variations - Comparatives"),
    ("Este casaco é tão confortável como elegante", "This coat is as comfortable as it is elegant", "Variations - Comparatives"),
    ("Eles não são tão pontuais como nós", "They are not as punctual as us", "Variations - Comparatives"),
    ("Andar a pé é tão saudável como correr", "Walking is as healthy as running", "Variations - Comparatives"),

    # Comparatives of Quantity (tanto / tanta / tantos / tantas ... como)
    ("Eu não tenho tanto dinheiro como ele", "I don't have as much money as him", "Variations - Comparatives of Quantity"),
    ("Nós temos tanta paciência como vocês", "We have as much patience as you", "Variations - Comparatives of Quantity"),
    ("O João comprou tantas maçãs como laranjas", "João bought as many apples as oranges", "Variations - Comparatives of Quantity"),
    ("Tu tens tantas dúvidas como eu?", "Do you have as many questions as I do?", "Variations - Comparatives of Quantity"),
    ("Este restaurante não tem tantos clientes como aquele", "This restaurant does not have as many customers as that one", "Variations - Comparatives of Quantity"),
    ("Hoje não há tanta gente na rua como ontem", "Today there aren't as many people in the street as yesterday", "Variations - Comparatives of Quantity"),
    ("Ela tem tantas amigas na universidade como na escola", "She has as many friends at university as at school", "Variations - Comparatives of Quantity"),
    ("Não faças tanto barulho, por favor", "Don't make so much noise, please", "Variations - Comparatives of Quantity"),

    # Family, Marriage, Divorce, Will & Inheritance
    ("Eles vão casar-se na próxima primavera", "They are going to get married next spring", "Variations - Life Events"),
    ("O casamento deles foi uma festa fantástica", "Their wedding was a fantastic celebration", "Variations - Life Events"),
    ("Ele casou-se com a Rita há três anos", "He married Rita three years ago", "Variations - Life Events"),
    ("Depois de conversar muito, o casal decidiu o divórcio", "After talking a lot, the couple decided on divorce", "Variations - Life Events"),
    ("O divórcio foi resolvido de forma amigável", "The divorce was settled amicably", "Variations - Life Events"),
    ("O avô deixou um testamento detalhado", "The grandfather left a detailed will", "Variations - Life Events"),
    ("Os herdeiros já assinaram todos os documentos", "The heirs have already signed all the documents", "Variations - Life Events"),
    ("Ela recebeu uma herança inesperada", "She received an unexpected inheritance", "Variations - Life Events"),
    ("A herança inclui uma casa antiga no Alentejo", "The inheritance includes an old house in Alentejo", "Variations - Life Events"),

    # Location & Demonstratives
    ("Vem cá, preciso de falar contigo", "Come here, I need to talk to you", "Variations - Location & Demonstratives"),
    ("O que estás a fazer aí? Vem cá para dentro", "What are you doing there? Come in here", "Variations - Location & Demonstratives"),
    ("Ela está lá em cima a trabalhar no quarto", "She is up there working in the bedroom", "Variations - Location & Demonstratives"),
    ("Vou lá amanhã de manhã resolver o assunto", "I will go there tomorrow morning to resolve the matter", "Variations - Location & Demonstratives"),
    ("Este café aqui é meu e essa água aí é tua", "This coffee here is mine and that water there is yours", "Variations - Location & Demonstratives"),
    ("Aquele edifício ao fundo é a Casa da Música", "That building in the background is Casa da Música", "Variations - Location & Demonstratives"),
    ("Esta cidade tem tanta história como Lisboa", "This city has as much history as Lisbon", "Variations - Location & Demonstratives"),

    # In-person vs Online Meetings & Modality
    ("Amanhã temos uma reunião presencial às dez horas", "Tomorrow we have an in-person meeting at ten o'clock", "Variations - Work & Meetings"),
    ("A reunião de projeto vai ser online através do computador", "The project meeting is going to be online via computer", "Variations - Work & Meetings"),
    ("Prefiro aulas presenciais para praticar conversação", "I prefer in-person classes to practice conversation", "Variations - Work & Meetings"),
    ("Os cursos online têm tantas vantagens como os cursos presenciais", "Online courses have as many advantages as in-person courses", "Variations - Work & Meetings"),
    ("Eu vou lá em pessoa entregar o contrato assinado", "I will go there in person to deliver the signed contract", "Variations - Work & Meetings"),
    ("O atendimento presencial no banco requer agendamento", "In-person service at the bank requires an appointment", "Variations - Work & Meetings"),
    ("Vais participar na reunião presencial ou online?", "Are you going to participate in the meeting in person or online?", "Variations - Work & Meetings"),

    # Free Time, Sports & Cultural Life
    ("No meu tempo livre gosto de ler e ouvir música", "In my free time I like to read and listen to music", "Variations - Free Time & Culture"),
    ("O que costumas fazer no teu tempo livre?", "What do you usually do in your free time?", "Variations - Free Time & Culture"),
    ("Ao final de tarde a esplanada fica cheia de amigos", "In the late afternoon the terrace gets full of friends", "Variations - Free Time & Culture"),
    ("Gosto de passear pela cidade ao final de tarde", "I like to stroll through the city in the late afternoon", "Variations - Free Time & Culture"),
    ("Já fizeste uma visita guiada à Casa da Música?", "Have you ever taken a guided tour of Casa da Música?", "Variations - Free Time & Culture"),
    ("A atleta olímpica treina natação todos os dias", "The Olympic athlete trains swimming every day", "Variations - Free Time & Culture"),
    ("Praticar andebol é tão dinâmico como praticar futebol", "Playing handball is as dynamic as playing football", "Variations - Free Time & Culture"),
]

def update_ano_markdown():
    path = "assets/ano_words_phrases.md"
    content = "# Vocabulary, Comparatives & Time Markers (assets/ano_words_phrases.md)\n\n"
    content += "## Core Vocabulary & Phrases (Corrected & Standardized)\n\n"
    content += "| Portugues | English |\n"
    content += "| :---- | :---- |\n"
    for pt, en, _ in CLEANED_BASE_ITEMS:
        content += f"| {pt} | {en} |\n"
    content += "\n## Variations & Grammar Expansion\n\n"
    content += "| Portugues | English |\n"
    content += "| :---- | :---- |\n"
    for pt, en, _ in VARIATIONS:
        content += f"| {pt} | {en} |\n"
    
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)
    print(f"Updated {path}")

def update_source_markdown():
    path = "assets/data/source.md"
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()

    # Find the section "# New Words and Phrases from assets/ano_words_phrases.md"
    # and replace everything up to "# New Words & Phrases from Class 6"
    target_start = "# New Words and Phrases from assets/ano_words_phrases.md"
    target_end = "# New Words & Phrases from Class 6"

    new_section = "# New Words and Phrases from assets/ano_words_phrases.md\n\n"
    new_section += "| Portugues | English | Notes |\n"
    new_section += "| :---- | :---- | :---- |\n"
    for pt, en, note in CLEANED_BASE_ITEMS:
        new_section += f"| {pt} | {en} | {note} |\n"
    for pt, en, note in VARIATIONS:
        new_section += f"| {pt} | {en} | {note} |\n"
    new_section += "\n\n"

    if target_start in content and target_end in content:
        before = content.split(target_start)[0]
        after = target_end + content.split(target_end)[1]
        updated_content = before + new_section + after
    else:
        # Fallback append if headings differ
        updated_content = content + "\n\n" + new_section

    with open(path, "w", encoding="utf-8") as f:
        f.write(updated_content)
    print(f"Updated {path}")

def update_combined_notes():
    path = "assets/Combined_Portuguese_Class_Notes.md"
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()

    # In Combined_Portuguese_Class_Notes.md, find the lines between:
    # "| se eu quero dizer | If I wanted to say |"
    # and "# Aula de português 6"
    marker_before = "| se eu quero dizer | If I wanted to say |"
    marker_after = "# Aula de português 6"

    replacement = "| se eu quero dizer | If I wanted to say |\n\n"
    replacement += "# Aula de português - Comparativos, Duração e Vocabulário\n\n"
    replacement += "| Portugues | English |\n"
    replacement += "| :---- | :---- |\n"
    for pt, en, _ in CLEANED_BASE_ITEMS:
        replacement += f"| {pt} | {en} |\n"
    for pt, en, _ in VARIATIONS:
        replacement += f"| {pt} | {en} |\n"
    replacement += "\n"

    if marker_before in content and marker_after in content:
        before = content.split(marker_before)[0]
        after = marker_after + content.split(marker_after)[1]
        updated = before + replacement + after
    else:
        updated = content

    with open(path, "w", encoding="utf-8") as f:
        f.write(updated)
    print(f"Updated {path}")

def update_phrases_json():
    path = "assets/data/phrases.json"
    with open(path, "r", encoding="utf-8") as f:
        phrases = json.load(f)

    existing_pts = {p["portuguese"].strip().lower() for p in phrases}

    new_phrases = [
        {"portuguese": "Eu moro aqui há dois anos.", "english": "I have lived here for two years."},
        {"portuguese": "Trabalho nesta empresa desde 2018.", "english": "I have worked in this company since 2018."},
        {"portuguese": "A Maria faz visitas guiadas na Casa da Música.", "english": "Maria gives guided tours at Casa da Música."},
        {"portuguese": "Os amigos estão na esplanada há meia hora.", "english": "The friends have been on the terrace for half an hour."},
        {"portuguese": "Este livro é tão interessante como aquele.", "english": "This book is as interesting as that one."},
        {"portuguese": "Nós não temos tanto tempo livre como eles.", "english": "We don't have as much free time as them."},
        {"portuguese": "Amanhã vou ter uma reunião presencial no escritório.", "english": "Tomorrow I will have an in-person meeting at the office."},
        {"portuguese": "Preferes uma reunião online ou presencial?", "english": "Do you prefer an online or in-person meeting?"},
        {"portuguese": "Eles vão casar-se no próximo verão.", "english": "They are going to get married next summer."},
        {"portuguese": "Vem cá, por favor, preciso da tua ajuda.", "english": "Come here, please, I need your help."},
        {"portuguese": "Ela está lá em cima no quarto.", "english": "She is upstairs in the bedroom."},
        {"portuguese": "Comer legumes é tão bom para a saúde como comer fruta.", "english": "Eating vegetables is as good for your health as eating fruit."},
        {"portuguese": "Ao final de tarde, a esplanada fica cheia de pessoas.", "english": "In the late afternoon, the terrace gets full of people."},
        {"portuguese": "O advogado já preparou o testamento.", "english": "The lawyer has already prepared the will."},
        {"portuguese": "Os herdeiros receberam a casa de família.", "english": "The heirs received the family home."},
        {"portuguese": "Não te preocupes, eu vou lá em pessoa entregar o documento.", "english": "Don't worry, I will go there in person to deliver the document."},
        {"portuguese": "Há quanto tempo estás em Portugal?", "english": "How long have you been in Portugal?"},
        {"portuguese": "Desde quando é que conheces a Maria?", "english": "Since when have you known Maria?"}
    ]

    added = 0
    for p in new_phrases:
        if p["portuguese"].strip().lower() not in existing_pts:
            phrases.append(p)
            existing_pts.add(p["portuguese"].strip().lower())
            added += 1

    with open(path, "w", encoding="utf-8") as f:
        json.dump(phrases, f, indent=2, ensure_ascii=False)
    print(f"Added {added} phrases to {path}")

def update_verb_phrases_json():
    path = "assets/data/verb_phrases.json"
    with open(path, "r", encoding="utf-8") as f:
        verb_phrases = json.load(f)

    existing_pts = {vp["portuguese"].strip().lower() for vp in verb_phrases}

    new_verb_phrases = [
        {
            "verb": "casar",
            "portuguese": "Eles casam-se no próximo mês na igreja.",
            "english": "They are getting married next month in church."
        },
        {
            "verb": "casar",
            "portuguese": "O meu irmão casa no próximo sábado.",
            "english": "My brother gets married next Saturday."
        },
        {
            "verb": "praticar",
            "portuguese": "Ela pratica natação há mais de dez anos.",
            "english": "She has been practicing swimming for more than ten years."
        },
        {
            "verb": "praticar",
            "portuguese": "Nós praticamos desporto ao final de tarde.",
            "english": "We practice sports in the late afternoon."
        },
        {
            "verb": "herdar",
            "portuguese": "Ele herda a quinta dos avós.",
            "english": "He inherits the grandparents' farm."
        },
        {
            "verb": "herdar",
            "portuguese": "Eles herdaram uma coleção de livros antigos.",
            "english": "They inherited a collection of antique books."
        },
        {
            "verb": "andar",
            "portuguese": "Andar de metro é tão rápido como andar de táxi.",
            "english": "Taking the metro is as fast as taking a taxi."
        }
    ]

    added = 0
    for vp in new_verb_phrases:
        if vp["portuguese"].strip().lower() not in existing_pts:
            verb_phrases.append(vp)
            existing_pts.add(vp["portuguese"].strip().lower())
            added += 1

    with open(path, "w", encoding="utf-8") as f:
        json.dump(verb_phrases, f, indent=2, ensure_ascii=False)
    print(f"Added {added} verb phrases to {path}")

def update_verbs_csv():
    path = "assets/data/verbs.csv"
    with open(path, "r", encoding="utf-8") as f:
        lines = f.readlines()

    verbs_present = {l.split(",")[0].strip() for l in lines}
    new_verbs = []

    if "herdar" not in verbs_present:
        new_verbs.append("herdar,herdo,herdas,herda,herdamos,herdam,to inherit\n")
    if "praticar" not in verbs_present:
        new_verbs.append("praticar,pratico,praticas,pratica,praticamos,praticam,to practice\n")

    if new_verbs:
        with open(path, "a", encoding="utf-8") as f:
            for v in new_verbs:
                f.write(v)
        print(f"Added {len(new_verbs)} verbs to {path}")

def create_exercise_unit():
    unit_path = "assets/data/exercises/unit_comparatives_and_duration.json"
    questions = [
        {
            "id": "comp_dur_q01",
            "questionText": "A Maria faz visitas guiadas na Casa da Música ____ 2021.",
            "options": ["desde", "há", "para", "até"],
            "correctAnswer": "desde",
            "type": "cloze",
            "sourceItem": {
                "id": "comp_dur_src_01",
                "portuguese": "desde",
                "english": "since (starting point)",
                "notes": "Time & Duration: starting point with year"
            },
            "category": "Time & Duration"
        },
        {
            "id": "comp_dur_q02",
            "questionText": "Os amigos estão na esplanada ____ meia hora a conversar.",
            "options": ["há", "desde", "por", "em"],
            "correctAnswer": "há",
            "type": "cloze",
            "sourceItem": {
                "id": "comp_dur_src_02",
                "portuguese": "há meia hora",
                "english": "for half an hour",
                "notes": "Time & Duration: elapsed duration"
            },
            "category": "Time & Duration"
        },
        {
            "id": "comp_dur_q03",
            "questionText": "A Olívia faz campismo ____ criança.",
            "options": ["desde", "há", "com", "por"],
            "correctAnswer": "desde",
            "type": "cloze",
            "sourceItem": {
                "id": "comp_dur_src_03",
                "portuguese": "desde criança",
                "english": "since childhood",
                "notes": "Time & Duration: point in life"
            },
            "category": "Time & Duration"
        },
        {
            "id": "comp_dur_q04",
            "questionText": "A atleta olímpica pratica natação ____ mais de dez anos.",
            "options": ["há", "desde", "para", "de"],
            "correctAnswer": "há",
            "type": "cloze",
            "sourceItem": {
                "id": "comp_dur_src_04",
                "portuguese": "há mais de dez anos",
                "english": "for more than ten years",
                "notes": "Time & Duration: duration with há"
            },
            "category": "Time & Duration"
        },
        {
            "id": "comp_dur_q05",
            "questionText": "A Maria trabalha na Casa da Música ____ que terminou o curso de turismo.",
            "options": ["desde", "há", "porque", "quando"],
            "correctAnswer": "desde",
            "type": "cloze",
            "sourceItem": {
                "id": "comp_dur_src_05",
                "portuguese": "desde que",
                "english": "since (conjunction)",
                "notes": "Time & Duration: desde que + clause"
            },
            "category": "Time & Duration"
        },
        {
            "id": "comp_dur_q06",
            "questionText": "Comer legumes é ____ bom para a saúde como comer fruta.",
            "options": ["tão", "tanto", "muito", "mais"],
            "correctAnswer": "tão",
            "type": "cloze",
            "sourceItem": {
                "id": "comp_dur_src_06",
                "portuguese": "tão ... como",
                "english": "as ... as (with adjective)",
                "notes": "Comparatives of equality: tão + adjective"
            },
            "category": "Comparatives"
        },
        {
            "id": "comp_dur_q07",
            "questionText": "As aulas de kizomba são tão ____ como as aulas de samba.",
            "options": ["divertidas", "divertido", "divertida", "divertidos"],
            "correctAnswer": "divertidas",
            "type": "cloze",
            "sourceItem": {
                "id": "comp_dur_src_07",
                "portuguese": "tão divertidas como",
                "english": "as fun as (feminine plural)",
                "notes": "Agreement: aulas (fem. pl.) requires divertidas"
            },
            "category": "Comparatives & Agreement"
        },
        {
            "id": "comp_dur_q08",
            "questionText": "Andar de metro é tão barato ____ andar de autocarro.",
            "options": ["como", "que", "do que", "quanto"],
            "correctAnswer": "como",
            "type": "cloze",
            "sourceItem": {
                "id": "comp_dur_src_08",
                "portuguese": "tão barato como",
                "english": "as cheap as",
                "notes": "Comparative correlative: tão ... como"
            },
            "category": "Comparatives"
        },
        {
            "id": "comp_dur_q09",
            "questionText": "Nós não temos ____ livros como vocês.",
            "options": ["tantos", "tão", "tanto", "tantas"],
            "correctAnswer": "tantos",
            "type": "cloze",
            "sourceItem": {
                "id": "comp_dur_src_09",
                "portuguese": "tantos ... como",
                "english": "as many ... as (masculine plural)",
                "notes": "Comparative of quantity: tantos livros"
            },
            "category": "Comparatives of Quantity"
        },
        {
            "id": "comp_dur_q10",
            "questionText": "A Teresa não tem ____ tempo livre como eu.",
            "options": ["tanto", "tão", "tanta", "tantos"],
            "correctAnswer": "tanto",
            "type": "cloze",
            "sourceItem": {
                "id": "comp_dur_src_10",
                "portuguese": "tanto tempo livre como",
                "english": "as much free time as",
                "notes": "Comparative of quantity: tanto tempo (masc. sing.)"
            },
            "category": "Comparatives of Quantity"
        },
        {
            "id": "comp_dur_q11",
            "questionText": "Praticar futebol tem ____ vantagens como praticar andebol.",
            "options": ["tantas", "tanto", "tão", "tantos"],
            "correctAnswer": "tantas",
            "type": "cloze",
            "sourceItem": {
                "id": "comp_dur_src_11",
                "portuguese": "tantas vantagens como",
                "english": "as many advantages as",
                "notes": "Comparative of quantity: tantas vantagens (fem. pl.)"
            },
            "category": "Comparatives of Quantity"
        },
        {
            "id": "comp_dur_q12",
            "questionText": "Eu não tenho ____ paciência como tu para esperar na fila.",
            "options": ["tanta", "tanto", "tão", "tantas"],
            "correctAnswer": "tanta",
            "type": "cloze",
            "sourceItem": {
                "id": "comp_dur_src_12",
                "portuguese": "tanta paciência como",
                "english": "as much patience as",
                "notes": "Comparative of quantity: tanta paciência (fem. sing.)"
            },
            "category": "Comparatives of Quantity"
        },
        {
            "id": "comp_dur_q13",
            "questionText": "O Porto é ____ bonito como Lisboa.",
            "options": ["tão", "tanto", "tanta", "como"],
            "correctAnswer": "tão",
            "type": "cloze",
            "sourceItem": {
                "id": "comp_dur_src_13",
                "portuguese": "tão bonito como",
                "english": "as beautiful as",
                "notes": "Comparative of equality with adjective bonito"
            },
            "category": "Comparatives"
        },
        {
            "id": "comp_dur_q14",
            "questionText": "Choose the correct adverbs: 'Esta camisa ____ é minha, mas essa camisa ____ é tua.'",
            "options": ["aqui / aí", "lá / aqui", "acolá / lá", "ali / aqui"],
            "correctAnswer": "aqui / aí",
            "type": "multipleChoice",
            "sourceItem": {
                "id": "comp_dur_src_14",
                "portuguese": "esta ... aqui, essa ... aí",
                "english": "this here, that there (near you)",
                "notes": "Demonstrative and location adverbs correspondence"
            },
            "category": "Demonstratives & Location"
        },
        {
            "id": "comp_dur_q15",
            "questionText": "O que estás a fazer aí fora? Vem ____ para dentro, está muito frio.",
            "options": ["cá", "lá", "onde", "ali"],
            "correctAnswer": "cá",
            "type": "cloze",
            "sourceItem": {
                "id": "comp_dur_src_15",
                "portuguese": "vem cá",
                "english": "come here",
                "notes": "Location adverbs: cá (to here, near speaker)"
            },
            "category": "Location Adverbs"
        },
        {
            "id": "comp_dur_q16",
            "questionText": "O meu irmão está ____ em cima a trabalhar no quarto.",
            "options": ["lá", "cá", "aqui", "este"],
            "correctAnswer": "lá",
            "type": "cloze",
            "sourceItem": {
                "id": "comp_dur_src_16",
                "portuguese": "lá em cima",
                "english": "up there",
                "notes": "Location adverbs: lá em cima"
            },
            "category": "Location Adverbs"
        },
        {
            "id": "comp_dur_q17",
            "questionText": "Qual é a palavra correta para a dissolução legal do casamento?",
            "options": ["o divórcio", "o testamento", "a herança", "o noivado"],
            "correctAnswer": "o divórcio",
            "type": "multipleChoice",
            "sourceItem": {
                "id": "comp_dur_src_17",
                "portuguese": "o divórcio",
                "english": "divorce",
                "notes": "Life events vocabulary"
            },
            "category": "Life Events & Law"
        },
        {
            "id": "comp_dur_q18",
            "questionText": "O avô foi ao notário para redigir o seu ____ e registar a divisão dos seus bens.",
            "options": ["testamento", "divórcio", "casamento", "campismo"],
            "correctAnswer": "testamento",
            "type": "cloze",
            "sourceItem": {
                "id": "comp_dur_src_18",
                "portuguese": "o testamento",
                "english": "will / testament",
                "notes": "Law & Life Events: testamento"
            },
            "category": "Life Events & Law"
        },
        {
            "id": "comp_dur_q19",
            "questionText": "Os ____ receberam a casa e o terreno da família.",
            "options": ["herdeiros", "testamentos", "casamentos", "divórcios"],
            "correctAnswer": "herdeiros",
            "type": "cloze",
            "sourceItem": {
                "id": "comp_dur_src_19",
                "portuguese": "os herdeiros",
                "english": "the heirs",
                "notes": "Law & Life Events: herdeiros"
            },
            "category": "Life Events & Law"
        },
        {
            "id": "comp_dur_q20",
            "questionText": "Ela dividiu a ____ com o irmão de forma justa.",
            "options": ["herança", "reunião", "natação", "visita"],
            "correctAnswer": "herança",
            "type": "cloze",
            "sourceItem": {
                "id": "comp_dur_src_20",
                "portuguese": "a herança",
                "english": "the inheritance",
                "notes": "Law & Life Events: herança"
            },
            "category": "Life Events & Law"
        },
        {
            "id": "comp_dur_q21",
            "questionText": "Amanhã não temos reunião por vídeo, vamos ter uma reunião ____ no escritório.",
            "options": ["presencial", "online", "distante", "vazia"],
            "correctAnswer": "presencial",
            "type": "cloze",
            "sourceItem": {
                "id": "comp_dur_src_21",
                "portuguese": "reunião presencial",
                "english": "in-person meeting",
                "notes": "Work modality: presencial (singular)"
            },
            "category": "Work & Modality"
        },
        {
            "id": "comp_dur_q22",
            "questionText": "As aulas ____ realizam-se na escola, enquanto as aulas virtuais são pela internet.",
            "options": ["presenciais", "online", "iguais", "rápidas"],
            "correctAnswer": "presenciais",
            "type": "cloze",
            "sourceItem": {
                "id": "comp_dur_src_22",
                "portuguese": "aulas presenciais",
                "english": "in-person classes",
                "notes": "Work modality: presenciais (plural)"
            },
            "category": "Work & Modality"
        },
        {
            "id": "comp_dur_q23",
            "questionText": "Não te preocupes com o correio, eu vou lá em ____ entregar os documentos.",
            "options": ["pessoa", "tempo", "reunião", "esplanada"],
            "correctAnswer": "pessoa",
            "type": "cloze",
            "sourceItem": {
                "id": "comp_dur_src_23",
                "portuguese": "em pessoa",
                "english": "in person",
                "notes": "Idiomatic phrase: ir em pessoa"
            },
            "category": "Expressions"
        },
        {
            "id": "comp_dur_q24",
            "questionText": "Ao ____ de tarde, a esplanada fica cheia de pessoas a relaxar.",
            "options": ["final", "fim", "tempo", "começo"],
            "correctAnswer": "final",
            "type": "cloze",
            "sourceItem": {
                "id": "comp_dur_src_24",
                "portuguese": "final de tarde",
                "english": "late afternoon",
                "notes": "Time phrase: ao final de tarde"
            },
            "category": "Time & Routine"
        },
        {
            "id": "comp_dur_q25",
            "questionText": "A Casa da Música é uma emblemática sala de concertos situada na cidade do ____.",
            "options": ["Porto", "Lisboa", "Faro", "Coimbra"],
            "correctAnswer": "Porto",
            "type": "multipleChoice",
            "sourceItem": {
                "id": "comp_dur_src_25",
                "portuguese": "Casa da Música",
                "english": "Casa da Música (Porto)",
                "notes": "Culture & Geography: concert hall in Porto"
            },
            "category": "Culture & Places"
        },
        {
            "id": "comp_dur_q26",
            "questionText": "'Há quanto tempo estudas português?' -> 'Estudo português ____ seis meses.'",
            "options": ["há", "desde", "para", "até"],
            "correctAnswer": "há",
            "type": "multipleChoice",
            "sourceItem": {
                "id": "comp_dur_src_26",
                "portuguese": "há seis meses",
                "english": "for six months",
                "notes": "Question & Answer pair with há"
            },
            "category": "Time & Duration"
        },
        {
            "id": "comp_dur_q27",
            "questionText": "'Desde quando vives nesta cidade?' -> 'Vivo aqui ____ 2018.'",
            "options": ["desde", "há", "em", "por"],
            "correctAnswer": "desde",
            "type": "multipleChoice",
            "sourceItem": {
                "id": "comp_dur_src_27",
                "portuguese": "desde 2018",
                "english": "since 2018",
                "notes": "Question & Answer pair with desde"
            },
            "category": "Time & Duration"
        },
        {
            "id": "comp_dur_q28",
            "questionText": "No meu tempo ____, gosto de ouvir música, nadar e ler livros.",
            "options": ["livre", "ocupado", "tão", "presencial"],
            "correctAnswer": "livre",
            "type": "cloze",
            "sourceItem": {
                "id": "comp_dur_src_28",
                "portuguese": "tempo livre",
                "english": "free time",
                "notes": "Vocabulary: tempo livre"
            },
            "category": "Hobbies & Leisure"
        }
    ]

    with open(unit_path, "w", encoding="utf-8") as f:
        json.dump(questions, f, indent=2, ensure_ascii=False)
    print(f"Created {len(questions)} exercise questions in {unit_path}")

def register_unit_in_screen():
    screen_path = "lib/ui/exercise/exercise_list_screen.dart"
    with open(screen_path, "r", encoding="utf-8") as f:
        content = f.read()

    new_unit_entry = """    {
      'title': 'Comparatives, Time & Life Events',
      'subtitle': 'Practice tão... como, tanto... como, há vs desde & vocabulary',
      'path': 'assets/data/exercises/unit_comparatives_and_duration.json',
      'icon': 'school',
    },
"""
    if "unit_comparatives_and_duration.json" not in content:
        # Insert before the closing bracket of units list
        marker = "    {\n      'title': 'Sentence Transformations & Grammar',"
        if marker in content:
            content = content.replace(marker, new_unit_entry + marker)
            with open(screen_path, "w", encoding="utf-8") as f:
                f.write(content)
            print(f"Registered unit in {screen_path}")
        else:
            print("Warning: could not locate insertion point in ExerciseListScreen")

def main():
    print("Ingesting ano_words_phrases.md data...")
    update_ano_markdown()
    update_source_markdown()
    update_combined_notes()
    update_phrases_json()
    update_verb_phrases_json()
    update_verbs_csv()
    create_exercise_unit()
    register_unit_in_screen()
    print("All file updates completed successfully.")

if __name__ == "__main__":
    main()
