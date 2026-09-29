#!/usr/bin/env python3
"""
scripts/add_listen_repeat_phrases.py

Appends a curated mix of A2 European Portuguese phrases for:
- House & Rooms (A Casa e Divisões)
- Household Items & Appliances (Objetos da Casa e Eletrodomésticos)
- Body Parts & Health (Partes do Corpo e Saúde)
- Everyday Items & Belongings (Objetos do Quotidiano)

into assets/data/phrases.json and assets/data/verb_phrases.json
so they are seamlessly integrated into the Listen & Repeat audio player and CarPlay.
"""

import json
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

NEW_CONVERSATIONAL_PHRASES = [
    # House & Rooms
    {
        "portuguese": "A Maria está a cozinhar o almoço na cozinha.",
        "english": "Maria is cooking lunch in the kitchen.",
        "category": "House & Rooms",
        "notes": "A Casa: Cozinha"
    },
    {
        "portuguese": "À noite, durmo numa cama confortável no quarto.",
        "english": "At night, I sleep in a comfortable bed in the bedroom.",
        "category": "House & Rooms",
        "notes": "A Casa: Quarto"
    },
    {
        "portuguese": "Tomo um duche quente na casa de banho todas as manhãs.",
        "english": "I take a warm shower in the bathroom every morning.",
        "category": "House & Rooms",
        "notes": "A Casa: Casa de Banho"
    },
    {
        "portuguese": "A família reúne-se na sala de estar para ver televisão.",
        "english": "The family gathers in the living room to watch TV.",
        "category": "House & Rooms",
        "notes": "A Casa: Sala de Estar"
    },
    {
        "portuguese": "Guardamos o arroz, as massas e o azeite na despensa.",
        "english": "We keep rice, pasta, and olive oil in the pantry.",
        "category": "House & Rooms",
        "notes": "A Casa: Despensa"
    },
    {
        "portuguese": "Gosto de beber café na varanda quando está sol.",
        "english": "I like drinking coffee on the balcony when it is sunny.",
        "category": "House & Rooms",
        "notes": "A Casa: Varanda"
    },
    {
        "portuguese": "Estendemos a roupa lavada na marquise.",
        "english": "We hang the washed laundry in the sunroom.",
        "category": "House & Rooms",
        "notes": "A Casa: Marquise"
    },
    {
        "portuguese": "O carro fica protegido dentro da garagem.",
        "english": "The car stays protected inside the garage.",
        "category": "House & Rooms",
        "notes": "A Casa: Garagem"
    },
    {
        "portuguese": "As crianças brincam na relva do jardim.",
        "english": "The children play on the garden grass.",
        "category": "House & Rooms",
        "notes": "A Casa: Jardim"
    },
    {
        "portuguese": "Prefiro subir as escadas a pé em vez do elevador.",
        "english": "I prefer taking the stairs on foot instead of the lift.",
        "category": "House & Rooms",
        "notes": "A Casa: Escadas"
    },

    # Household Items & Appliances
    {
        "portuguese": "Põe o leite no frigorífico para não se estragar.",
        "english": "Put the milk in the fridge so it doesn't spoil.",
        "category": "Household Items",
        "notes": "Objetos: Frigorífico"
    },
    {
        "portuguese": "Pomil a loiça suja na máquina de lavar loiça.",
        "english": "We put the dirty dishes in the dishwasher.",
        "category": "Household Items",
        "notes": "Objetos: Máquina de Lavar Loiça"
    },
    {
        "portuguese": "Vou passar o aspirador na carpete da sala.",
        "english": "I am going to vacuum the living room carpet.",
        "category": "Household Items",
        "notes": "Objetos: Aspirador"
    },
    {
        "portuguese": "Preciso do ferro de engomar para passar esta camisa.",
        "english": "I need the iron to iron this shirt.",
        "category": "Household Items",
        "notes": "Objetos: Ferro de Engomar"
    },
    {
        "portuguese": "Aqueço a sopa no micro-ondas em dois minutos.",
        "english": "I heat the soup in the microwave in two minutes.",
        "category": "Household Items",
        "notes": "Objetos: Micro-ondas"
    },
    {
        "portuguese": "O peixe assa no forno a duzentos graus.",
        "english": "The fish bakes in the oven at two hundred degrees.",
        "category": "Household Items",
        "notes": "Objetos: Forno"
    },
    {
        "portuguese": "Fervemos água na chaleira elétrica para o chá.",
        "english": "We boil water in the electric kettle for tea.",
        "category": "Household Items",
        "notes": "Objetos: Chaleira"
    },
    {
        "portuguese": "De manhã, faço torradas na torradeira com manteiga.",
        "english": "In the morning, I make toast in the toaster with butter.",
        "category": "Household Items",
        "notes": "Objetos: Torradeira"
    },
    {
        "portuguese": "O caixote do lixo está cheio, deita o saco fora.",
        "english": "The rubbish bin is full, throw the bag out.",
        "category": "Household Items",
        "notes": "Objetos: Caixote do Lixo"
    },
    {
        "portuguese": "Varro o chão com a vassoura e limpo com a esfregona.",
        "english": "I sweep the floor with the broom and clean with the mop.",
        "category": "Household Items",
        "notes": "Objetos: Vassoura e Esfregona"
    },
    {
        "portuguese": "Tomamos o café expresso numa chávena pequena.",
        "english": "We drink espresso coffee in a small cup.",
        "category": "Household Items",
        "notes": "Objetos: Chávena"
    },
    {
        "portuguese": "Na casa de banho, ela olha-se ao espelho.",
        "english": "In the bathroom, she looks at herself in the mirror.",
        "category": "Household Items",
        "notes": "Objetos: Espelho"
    },

    # Body Parts & Health
    {
        "portuguese": "Dói-me muito a cabeça depois de trabalhar tanto tempo.",
        "english": "My head hurts a lot after working for so long.",
        "category": "Body & Health",
        "notes": "Saúde: Dor de Cabeça"
    },
    {
        "portuguese": "Estou com dores de garganta e febre alta.",
        "english": "I have a sore throat and a high fever.",
        "category": "Body & Health",
        "notes": "Saúde: Garganta e Febre"
    },
    {
        "portuguese": "Trabalho sentado e estou com dores nas costas.",
        "english": "I work sitting down and I have back pain.",
        "category": "Body & Health",
        "notes": "Saúde: Costas"
    },
    {
        "portuguese": "Lavo sempre as mãos com sabão antes das refeições.",
        "english": "I always wash my hands with soap before meals.",
        "category": "Body & Health",
        "notes": "Saúde: Lavar as Mãos"
    },
    {
        "portuguese": "O jogador caiu no relvado e torceu o tornozelo.",
        "english": "The player fell on the pitch and sprained his ankle.",
        "category": "Body & Health",
        "notes": "Saúde: Tornozelo"
    },
    {
        "portuguese": "Fui ao dentista ontem porque me doía um dente.",
        "english": "I went to the dentist yesterday because a tooth hurt.",
        "category": "Body & Health",
        "notes": "Saúde: Dentista"
    },
    {
        "portuguese": "Tenho os olhos cansados de olhar para o ecrã.",
        "english": "My eyes are tired from looking at the screen.",
        "category": "Body & Health",
        "notes": "Saúde: Olhos"
    },
    {
        "portuguese": "Ponho um cachecol de lã no pescoço para não apanhar frio.",
        "english": "I put a wool scarf around my neck not to catch cold.",
        "category": "Body & Health",
        "notes": "Saúde: Pescoço"
    },
    {
        "portuguese": "Caminhei dez quilómetros e agora doem-me os pés.",
        "english": "I walked ten kilometres and now my feet hurt.",
        "category": "Body & Health",
        "notes": "Saúde: Pés"
    },
    {
        "portuguese": "Coloquei um penso rápido no dedo para proteger o corte.",
        "english": "I put a plaster on my finger to protect the cut.",
        "category": "Body & Health",
        "notes": "Saúde: Penso Rápido"
    },

    # Everyday Items & Personal Belongings
    {
        "portuguese": "A bateria do meu telemóvel acabou, preciso do carregador.",
        "english": "My mobile phone battery ran out, I need the charger.",
        "category": "Everyday Items",
        "notes": "Quotidiano: Telemóvel"
    },
    {
        "portuguese": "Onde está o carregador para ligar o telemóvel à tomada?",
        "english": "Where is the charger to plug the phone into the socket?",
        "category": "Everyday Items",
        "notes": "Quotidiano: Carregador e Tomada"
    },
    {
        "portuguese": "Esqueci-me das chaves de casa e não consigo abrir a porta.",
        "english": "I forgot my house keys and I cannot open the door.",
        "category": "Everyday Items",
        "notes": "Quotidiano: Chaves"
    },
    {
        "portuguese": "Perdi a minha carteira com o dinheiro e o Cartão de Cidadão.",
        "english": "I lost my wallet with money and Citizen Card.",
        "category": "Everyday Items",
        "notes": "Quotidiano: Carteira"
    },
    {
        "portuguese": "Valido o meu passe de transportes antes de entrar no metro.",
        "english": "I validate my transit pass before entering the metro.",
        "category": "Everyday Items",
        "notes": "Quotidiano: Passe de Transportes"
    },
    {
        "portuguese": "Está a chover muito, leva o teu guarda-chuva.",
        "english": "It is raining heavily, take your umbrella.",
        "category": "Everyday Items",
        "notes": "Quotidiano: Guarda-chuva"
    },
    {
        "portuguese": "Uso auscultadores no comboio para ouvir música.",
        "english": "I wear headphones on the train to listen to music.",
        "category": "Everyday Items",
        "notes": "Quotidiano: Auscultadores"
    },
    {
        "portuguese": "Guardo os cadernos e o computador portátil na mochila.",
        "english": "I keep the notebooks and the laptop in the backpack.",
        "category": "Everyday Items",
        "notes": "Quotidiano: Mochila e Portátil"
    },
    {
        "portuguese": "Olho para o meu relógio de pulso para ver as horas.",
        "english": "I look at my wristwatch to see the time.",
        "category": "Everyday Items",
        "notes": "Quotidiano: Relógio de Pulso"
    },
    {
        "portuguese": "Quando está muito sol, uso óculos de sol escuros.",
        "english": "When it is very sunny, I wear dark sunglasses.",
        "category": "Everyday Items",
        "notes": "Quotidiano: Óculos de Sol"
    },
    {
        "portuguese": "Levo uma garrafa de água fresca para a caminhada.",
        "english": "I take a bottle of fresh water for the walk.",
        "category": "Everyday Items",
        "notes": "Quotidiano: Garrafa de Água"
    }
]

NEW_VERB_PHRASES = [
    {
        "verb": "cozinhar",
        "portuguese": "Eu cozinho o almoço para a família na cozinha.",
        "english": "I cook lunch for the family in the kitchen."
    },
    {
        "verb": "dormir",
        "portuguese": "Nós dormimos oito horas por noite num quarto confortável.",
        "english": "We sleep eight hours a night in a comfortable bedroom."
    },
    {
        "verb": "descansar",
        "portuguese": "Eles descansam no sofá da sala de estar após o trabalho.",
        "english": "They rest on the living room sofa after work."
    },
    {
        "verb": "guardar",
        "portuguese": "Eu guardo os mantimentos e o azeite na despensa.",
        "english": "I store groceries and olive oil in the pantry."
    },
    {
        "verb": "arrumar",
        "portuguese": "Nós arrumamos as roupas limpas dentro do roupeiro.",
        "english": "We tidy the clean clothes inside the wardrobe."
    },
    {
        "verb": "aquecer",
        "portuguese": "Ela aquece a comida no micro-ondas rapidamente.",
        "english": "She heats the food in the microwave quickly."
    },
    {
        "verb": "assar",
        "portuguese": "Nós assamos peixe fresco no forno a duzentos graus.",
        "english": "We roast fresh fish in the oven at two hundred degrees."
    },
    {
        "verb": "ferver",
        "portuguese": "Eu fervo água na chaleira elétrica para fazer chá.",
        "english": "I boil water in the electric kettle to make tea."
    },
    {
        "verb": "varrer",
        "portuguese": "Ele varre o chão da cozinha com a vassoura.",
        "english": "He sweeps the kitchen floor with the broom."
    },
    {
        "verb": "escovar",
        "portuguese": "Escovo os dentes na casa de banho após as refeições.",
        "english": "I brush my teeth in the bathroom after meals."
    },
    {
        "verb": "lavar",
        "portuguese": "Lavo sempre as mãos com água tépida e sabonete.",
        "english": "I always wash my hands with warm water and soap."
    },
    {
        "verb": "doer",
        "portuguese": "Dói-me muito a garganta ao engolir comida.",
        "english": "My throat hurts a lot when swallowing food."
    },
    {
        "verb": "torcer",
        "portuguese": "O atleta torceu o tornozelo a descer as escadas.",
        "english": "The athlete sprained his ankle going down the stairs."
    },
    {
        "verb": "carregar",
        "portuguese": "Preciso de carregar o telemóvel na tomada da parede.",
        "english": "I need to charge the mobile phone at the wall socket."
    },
    {
        "verb": "esquecer",
        "portuguese": "Esqueci-me das chaves de casa no casaco de inverno.",
        "english": "I forgot the house keys in the winter coat."
    },
    {
        "verb": "validar",
        "portuguese": "Valido o passe de transportes antes de entrar no metro.",
        "english": "I validate the transit pass before entering the metro."
    },
    {
        "verb": "proteger",
        "portuguese": "Uso óculos de sol para proteger os olhos no verão.",
        "english": "I wear sunglasses to protect my eyes in summer."
    },
    {
        "verb": "levar",
        "portuguese": "Levo o computador portátil e os cadernos na mochila.",
        "english": "I take the laptop and notebooks in the backpack."
    }
]


def update_phrases():
    path = REPO_ROOT / "assets/data/phrases.json"
    with open(path, "r", encoding="utf-8") as f:
        existing = json.load(f)

    seen = {p["portuguese"].strip().lower() for p in existing}
    added = 0
    for p in NEW_CONVERSATIONAL_PHRASES:
        key = p["portuguese"].strip().lower()
        if key not in seen:
            existing.append(p)
            seen.add(key)
            added += 1

    with open(path, "w", encoding="utf-8") as f:
        json.dump(existing, f, indent=2, ensure_ascii=False)
    print(f"Added {added} conversational phrases to {path} (total: {len(existing)})")


def update_verb_phrases():
    path = REPO_ROOT / "assets/data/verb_phrases.json"
    with open(path, "r", encoding="utf-8") as f:
        existing = json.load(f)

    seen = {vp["portuguese"].strip().lower() for vp in existing}
    added = 0
    for vp in NEW_VERB_PHRASES:
        key = vp["portuguese"].strip().lower()
        if key not in seen:
            existing.append(vp)
            seen.add(key)
            added += 1

    with open(path, "w", encoding="utf-8") as f:
        json.dump(existing, f, indent=2, ensure_ascii=False)
    print(f"Added {added} verb phrases to {path} (total: {len(existing)})")


if __name__ == "__main__":
    update_phrases()
    update_verb_phrases()
