#!/usr/bin/env python3
"""
scripts/add_a2_topics_exercises.py

Generates A2-level European Portuguese (PT-PT) exercises covering:
1. As Divisões da Casa (Rooms in the house & living spaces)
2. Objetos da Casa e Eletrodomésticos (Household items & appliances)
3. Partes do Corpo e Saúde (Parts of the body, health & daily care)
4. Objetos do Quotidiano e Acessórios (Everyday items & personal belongings)

Also integrates corresponding vocabulary into:
- assets/data/source.md
- assets/data/phrases.json
- assets/data/verb_phrases.json
- lib/ui/exercise/exercise_list_screen.dart
and runs generate_quiz.py to update assets/data/questions.json additively.
"""

import json
import os
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

# -----------------------------------------------------------------------------
# 1. UNIT: ROOMS IN THE HOUSE (Divisões da Casa)
# -----------------------------------------------------------------------------
ROOMS_QUESTIONS = [
    {
        "id": "room_q01",
        "questionText": "A Maria está a preparar o almoço na ____.",
        "options": ["cozinha", "garagem", "casa de banho", "varanda"],
        "correctAnswer": "cozinha",
        "type": "cloze",
        "sourceItem": {
            "id": "room_src_cozinha",
            "portuguese": "a cozinha",
            "english": "the kitchen",
            "notes": "Rooms in the house: onde se cozinha e preparam refeições"
        },
        "category": "Divisões da Casa"
    },
    {
        "id": "room_q02",
        "questionText": "À noite, nós dormimos numa cama confortável no ____.",
        "options": ["quarto", "corredor", "despensa", "jardim"],
        "correctAnswer": "quarto",
        "type": "cloze",
        "sourceItem": {
            "id": "room_src_quarto",
            "portuguese": "o quarto",
            "english": "the bedroom",
            "notes": "Rooms in the house: onde se dorme"
        },
        "category": "Divisões da Casa"
    },
    {
        "id": "room_q03",
        "questionText": "Antes de sair para o trabalho, tomo sempre um duche na ____.",
        "options": ["casa de banho", "cozinha", "cave", "sala de jantar"],
        "correctAnswer": "casa de banho",
        "type": "cloze",
        "sourceItem": {
            "id": "room_src_casa_de_banho",
            "portuguese": "a casa de banho",
            "english": "the bathroom",
            "notes": "Rooms in the house: PT-PT casa de banho (not banheiro)"
        },
        "category": "Divisões da Casa"
    },
    {
        "id": "room_q04",
        "questionText": "Depois do jantar, a família reúne-se no sofá para ver televisão na ____.",
        "options": ["sala de estar", "despensa", "garagem", "casa de banho"],
        "correctAnswer": "sala de estar",
        "type": "cloze",
        "sourceItem": {
            "id": "room_src_sala_de_estar",
            "portuguese": "a sala de estar",
            "english": "the living room",
            "notes": "Rooms in the house: sala principal de convívio"
        },
        "category": "Divisões da Casa"
    },
    {
        "id": "room_q05",
        "questionText": "Guardamos os pacotes de arroz, as massas e o azeite na ____.",
        "options": ["despensa", "varanda", "casa de banho", "sala de estar"],
        "correctAnswer": "despensa",
        "type": "cloze",
        "sourceItem": {
            "id": "room_src_despensa",
            "portuguese": "a despensa",
            "english": "the pantry / larder",
            "notes": "Rooms in the house: divisão pequena para mantimentos"
        },
        "category": "Divisões da Casa"
    },
    {
        "id": "room_q06",
        "questionText": "O carro da família fica estacionado e protegido dentro da ____.",
        "options": ["garagem", "cozinha", "marquise", "sala de jantar"],
        "correctAnswer": "garagem",
        "type": "cloze",
        "sourceItem": {
            "id": "room_src_garagem",
            "portuguese": "a garagem",
            "english": "the garage",
            "notes": "Rooms in the house: onde se guarda o carro"
        },
        "category": "Divisões da Casa"
    },
    {
        "id": "room_q07",
        "questionText": "No verão, gosto de apanhar ar fresco e beber café na ____ do apartamento.",
        "options": ["varanda", "cave", "despensa", "escada"],
        "correctAnswer": "varanda",
        "type": "cloze",
        "sourceItem": {
            "id": "room_src_varanda",
            "portuguese": "a varanda",
            "english": "the balcony",
            "notes": "Rooms in the house: espaço exterior do apartamento"
        },
        "category": "Divisões da Casa"
    },
    {
        "id": "room_q08",
        "questionText": "O prédio tem elevador, mas prefiro subir a pé pelas ____ para fazer exercício.",
        "options": ["escadas", "paredes", "janelas", "torradeiras"],
        "correctAnswer": "escadas",
        "type": "cloze",
        "sourceItem": {
            "id": "room_src_escadas",
            "portuguese": "as escadas",
            "english": "the stairs",
            "notes": "House parts: degraus para subir de piso"
        },
        "category": "Divisões da Casa"
    },
    {
        "id": "room_q09",
        "questionText": "Em muitos apartamentos em Portugal, a varanda fechada com vidro chama-se ____.",
        "options": ["marquise", "cave", "sótão", "lareira"],
        "correctAnswer": "marquise",
        "type": "cloze",
        "sourceItem": {
            "id": "room_src_marquise",
            "portuguese": "a marquise",
            "english": "the enclosed balcony / sunroom",
            "notes": "Rooms in the house: varanda envidraçada muito típica em PT"
        },
        "category": "Divisões da Casa"
    },
    {
        "id": "room_q10",
        "questionText": "O Manuel vive no rés do chão e a Ana mora no primeiro ____.",
        "options": ["andar", "quarto", "corredor", "jardim"],
        "correctAnswer": "andar",
        "type": "cloze",
        "sourceItem": {
            "id": "room_src_andar",
            "portuguese": "o andar / piso",
            "english": "the floor / storey",
            "notes": "Housing: rés do chão, primeiro andar, etc."
        },
        "category": "Divisões da Casa"
    },
    {
        "id": "room_q11",
        "questionText": "As malas de viagem e as caixas velhas estão arrumadas lá em cima no ____.",
        "options": ["sótão", "jardim", "cozinha", "rés do chão"],
        "correctAnswer": "sótão",
        "type": "cloze",
        "sourceItem": {
            "id": "room_src_sotao",
            "portuguese": "o sótão",
            "english": "the attic",
            "notes": "Rooms in the house: espaço por baixo do telhado"
        },
        "category": "Divisões da Casa"
    },
    {
        "id": "room_q12",
        "questionText": "No piso subterrâneo da vivenda fica a ____, onde guardamos o vinho.",
        "options": ["cave", "marquise", "varanda", "sala de jantar"],
        "correctAnswer": "cave",
        "type": "cloze",
        "sourceItem": {
            "id": "room_src_cave",
            "portuguese": "a cave",
            "english": "the basement / cellar",
            "notes": "Rooms in the house: piso inferior ou subterrâneo"
        },
        "category": "Divisões da Casa"
    },
    {
        "id": "room_q13",
        "questionText": "Para chegar aos quartos, temos de passar por um longo ____.",
        "options": ["corredor", "fogão", "jardim", "telhado"],
        "correctAnswer": "corredor",
        "type": "cloze",
        "sourceItem": {
            "id": "room_src_corredor",
            "portuguese": "o corredor",
            "english": "the corridor / hallway",
            "notes": "Rooms in the house: passagem que liga as divisões"
        },
        "category": "Divisões da Casa"
    },
    {
        "id": "room_q14",
        "questionText": "Ao entrar em casa, tiramos os sapatos e penduramos os casacos no ____.",
        "options": ["hall de entrada", "sótão", "congelador", "telhado"],
        "correctAnswer": "hall de entrada",
        "type": "cloze",
        "sourceItem": {
            "id": "room_src_hall",
            "portuguese": "o hall de entrada",
            "english": "the entrance hall",
            "notes": "Rooms in the house: entrada da habitação"
        },
        "category": "Divisões da Casa"
    },
    {
        "id": "room_q15",
        "questionText": "As crianças gostam de correr na relva e apanhar flores no ____ da casa.",
        "options": ["jardim", "escritório", "corredor", "forno"],
        "correctAnswer": "jardim",
        "type": "cloze",
        "sourceItem": {
            "id": "room_src_jardim",
            "portuguese": "o jardim",
            "english": "the garden",
            "notes": "House spaces: espaço verde com plantas e relva"
        },
        "category": "Divisões da Casa"
    },
    {
        "id": "room_q16",
        "questionText": "Na sala de ____, temos uma mesa grande de madeira onde a família almoça aos domingos.",
        "options": ["jantar", "espera", "banho", "dormir"],
        "correctAnswer": "jantar",
        "type": "cloze",
        "sourceItem": {
            "id": "room_src_sala_jantar",
            "portuguese": "a sala de jantar",
            "english": "the dining room",
            "notes": "Rooms in the house: sala dedicada às refeições"
        },
        "category": "Divisões da Casa"
    },
    {
        "id": "room_q17",
        "questionText": "O Pedro trabalha a partir de casa e montou a sua secretária no ____.",
        "options": ["escritório", "caixote do lixo", "frigorífico", "fogão"],
        "correctAnswer": "escritório",
        "type": "cloze",
        "sourceItem": {
            "id": "room_src_escritorio",
            "portuguese": "o escritório",
            "english": "the home office / study",
            "notes": "Rooms in the house: divisão de trabalho e estudo"
        },
        "category": "Divisões da Casa"
    },
    {
        "id": "room_q18",
        "questionText": "Qual é a divisão onde normalmente se lavam os dentes e se toma duche?",
        "options": ["A casa de banho", "A cozinha", "A garagem", "A despensa"],
        "correctAnswer": "A casa de banho",
        "type": "multipleChoice",
        "sourceItem": {
            "id": "room_src_casa_de_banho_func",
            "portuguese": "a casa de banho",
            "english": "the bathroom",
            "notes": "Rooms in the house: higiene diária"
        },
        "category": "Divisões da Casa"
    },
    {
        "id": "room_q19",
        "questionText": "Como se diz 'ground floor' em português de Portugal?",
        "options": ["Rés do chão", "Cave", "Sótão", "Primeiro andar"],
        "correctAnswer": "Rés do chão",
        "type": "multipleChoice",
        "sourceItem": {
            "id": "room_src_res_do_chao",
            "portuguese": "o rés do chão",
            "english": "the ground floor",
            "notes": "Housing: piso ao nível da rua"
        },
        "category": "Divisões da Casa"
    },
    {
        "id": "room_q20",
        "questionText": "O último piso do edifício tem um grande ____ exterior com vista para o rio Tejo.",
        "options": ["terraço", "corredor", "guarda-roupa", "armário"],
        "correctAnswer": "terraço",
        "type": "cloze",
        "sourceItem": {
            "id": "room_src_terraco",
            "portuguese": "o terraço",
            "english": "the terrace",
            "notes": "House spaces: terraço exterior amplo"
        },
        "category": "Divisões da Casa"
    },
    {
        "id": "room_q21",
        "questionText": "Como se traduz 'enclosed balcony' em português europeu?",
        "options": ["A marquise", "O sótão", "O telhado", "A despensa"],
        "correctAnswer": "A marquise",
        "type": "multipleChoice",
        "sourceItem": {
            "id": "room_src_marquise_trans",
            "portuguese": "a marquise",
            "english": "the sunroom / enclosed balcony",
            "notes": "European Portuguese distinctive vocabulary"
        },
        "category": "Divisões da Casa"
    },
    {
        "id": "room_q22",
        "questionText": "A roupa recém-lavada está estendida a secar ao sol na ____.",
        "options": ["varanda", "cave", "garagem", "despensa"],
        "correctAnswer": "varanda",
        "type": "cloze",
        "sourceItem": {
            "id": "room_src_varanda_roupa",
            "portuguese": "a varanda",
            "english": "the balcony",
            "notes": "Daily activities: estender a roupa na varanda"
        },
        "category": "Divisões da Casa"
    },
    {
        "id": "room_q23",
        "questionText": "O roupeiro onde guardo as minhas roupas fica dentro do ____.",
        "options": ["quarto", "hall de entrada", "jardim", "cozinha"],
        "correctAnswer": "quarto",
        "type": "cloze",
        "sourceItem": {
            "id": "room_src_roupeiro_quarto",
            "portuguese": "o roupeiro",
            "english": "the wardrobe",
            "notes": "Furniture & rooms: guarda-fatos / roupeiro no quarto"
        },
        "category": "Divisões da Casa"
    },
    {
        "id": "room_q24",
        "questionText": "A vizinha do terceiro andar queixou-se de que a ____ do teto está a pingar água.",
        "options": ["torneira", "lareira", "cortina", "almofada"],
        "correctAnswer": "torneira",
        "type": "cloze",
        "sourceItem": {
            "id": "room_src_torneira",
            "portuguese": "a torneira",
            "english": "the tap / faucet",
            "notes": "House fixtures: torneira da casa de banho / cozinha"
        },
        "category": "Divisões da Casa"
    },
    {
        "id": "room_q25",
        "questionText": "No inverno, acendemos a ____ da sala de estar para aquecer a casa com lenha.",
        "options": ["lareira", "marquise", "despensa", "banheira"],
        "correctAnswer": "lareira",
        "type": "cloze",
        "sourceItem": {
            "id": "room_src_lareira",
            "portuguese": "a lareira",
            "english": "the fireplace",
            "notes": "House heating: lareira a lenha"
        },
        "category": "Divisões da Casa"
    }
]

# -----------------------------------------------------------------------------
# 2. UNIT: HOUSEHOLD ITEMS & APPLIANCES (Objetos da Casa e Eletrodomésticos)
# -----------------------------------------------------------------------------
HOUSEHOLD_QUESTIONS = [
    {
        "id": "house_q01",
        "questionText": "Guarda o iogurte e o queijo no ____ para não se estragarem com o calor.",
        "options": ["frigorífico", "forno", "armário", "aspirador"],
        "correctAnswer": "frigorífico",
        "type": "cloze",
        "sourceItem": {
            "id": "house_src_frigorifico",
            "portuguese": "o frigorífico",
            "english": "the refrigerator",
            "notes": "Household appliances: PT-PT frigorífico (not geladeira)"
        },
        "category": "Objetos da Casa"
    },
    {
        "id": "house_q02",
        "questionText": "Depois do almoço, pomos os pratos, copos e talheres na máquina de lavar ____.",
        "options": ["loiça", "roupa", "café", "pão"],
        "correctAnswer": "loiça",
        "type": "cloze",
        "sourceItem": {
            "id": "house_src_maquina_loica",
            "portuguese": "a máquina de lavar loiça",
            "english": "the dishwasher",
            "notes": "Household appliances: PT-PT loiça (spelled com i)"
        },
        "category": "Objetos da Casa"
    },
    {
        "id": "house_q03",
        "questionText": "A roupa suja deve ser lavada na máquina de lavar ____ a quarenta graus.",
        "options": ["roupa", "loiça", "mão", "carro"],
        "correctAnswer": "roupa",
        "type": "cloze",
        "sourceItem": {
            "id": "house_src_maquina_roupa",
            "portuguese": "a máquina de lavar roupa",
            "english": "the washing machine",
            "notes": "Household appliances: máquina de lavar roupa"
        },
        "category": "Objetos da Casa"
    },
    {
        "id": "house_q04",
        "questionText": "O tapete da sala tem muito pó; vou passar o ____ para limpar tudo.",
        "options": ["aspirador", "ferro", "frigorífico", "candeeiro"],
        "correctAnswer": "aspirador",
        "type": "cloze",
        "sourceItem": {
            "id": "house_src_aspirador",
            "portuguese": "o aspirador",
            "english": "the vacuum cleaner",
            "notes": "Household appliances: aspirador de pó"
        },
        "category": "Objetos da Casa"
    },
    {
        "id": "house_q05",
        "questionText": "Para alisar a camisa antes da entrevista, uso o ferro de ____ e a tábua.",
        "options": ["engomar", "lavar", "cozinhar", "aspirar"],
        "correctAnswer": "engomar",
        "type": "cloze",
        "sourceItem": {
            "id": "house_src_ferro_engomar",
            "portuguese": "o ferro de engomar",
            "english": "the clothes iron",
            "notes": "Household items: PT-PT ferro de engomar / engomar a roupa"
        },
        "category": "Objetos da Casa"
    },
    {
        "id": "house_q06",
        "questionText": "Se a sopa estiver fria, podemos aquecê-la em dois minutos no ____.",
        "options": ["micro-ondas", "congelador", "frigorífico", "aspirador"],
        "correctAnswer": "micro-ondas",
        "type": "cloze",
        "sourceItem": {
            "id": "house_src_microondas",
            "portuguese": "o micro-ondas",
            "english": "the microwave",
            "notes": "Kitchen appliances: micro-ondas para aquecer rápido"
        },
        "category": "Objetos da Casa"
    },
    {
        "id": "house_q07",
        "questionText": "Vamos assar o peixe e as batatas no ____ bem quente.",
        "options": ["forno", "congelador", "lava-loiça", "tapete"],
        "correctAnswer": "forno",
        "type": "cloze",
        "sourceItem": {
            "id": "house_src_forno",
            "portuguese": "o forno",
            "english": "the oven",
            "notes": "Kitchen appliances: assar no forno"
        },
        "category": "Objetos da Casa"
    },
    {
        "id": "house_q08",
        "questionText": "Coloca a panela com água a ferver em cima do bico do ____.",
        "options": ["fogão", "sofá", "espelho", "guarda-roupa"],
        "correctAnswer": "fogão",
        "type": "cloze",
        "sourceItem": {
            "id": "house_src_fogao",
            "portuguese": "o fogão",
            "english": "the stove / cooker",
            "notes": "Kitchen appliances: fogão a gás ou vitrocerâmica"
        },
        "category": "Objetos da Casa"
    },
    {
        "id": "house_q09",
        "questionText": "De manhã, ponho duas fatias de pão na ____ para ficarem crocantes.",
        "options": ["torradeira", "máquina de lavar", "batedeira", "chaleira"],
        "correctAnswer": "torradeira",
        "type": "cloze",
        "sourceItem": {
            "id": "house_src_torradeira",
            "portuguese": "a torradeira",
            "english": "the toaster",
            "notes": "Kitchen appliances: fazer torradas"
        },
        "category": "Objetos da Casa"
    },
    {
        "id": "house_q10",
        "questionText": "Para fazer chá rapidamente, fervemos água na ____ elétrica.",
        "options": ["chaleira", "frigideira", "panela", "torradeira"],
        "correctAnswer": "chaleira",
        "type": "cloze",
        "sourceItem": {
            "id": "house_src_chaleira",
            "portuguese": "a chaleira elétrica",
            "english": "the electric kettle",
            "notes": "Kitchen appliances: chaleira para ferver água"
        },
        "category": "Objetos da Casa"
    },
    {
        "id": "house_q11",
        "questionText": "O caixote do ____ da cozinha está cheio; deita o saco fora, por favor.",
        "options": ["lixo", "pão", "azeite", "açúcar"],
        "correctAnswer": "lixo",
        "type": "cloze",
        "sourceItem": {
            "id": "house_src_caixote_lixo",
            "portuguese": "o caixote do lixo",
            "english": "the rubbish bin",
            "notes": "Household items: PT-PT caixote do lixo (not lixeira)"
        },
        "category": "Objetos da Casa"
    },
    {
        "id": "house_q12",
        "questionText": "Varri as migalhas do chão com a ____ e depois passei a esfregona húmida.",
        "options": ["vassoura", "toalha", "almofada", "faca"],
        "correctAnswer": "vassoura",
        "type": "cloze",
        "sourceItem": {
            "id": "house_src_vassoura",
            "portuguese": "a vassoura",
            "english": "the broom",
            "notes": "Cleaning items: varrer o chão"
        },
        "category": "Objetos da Casa"
    },
    {
        "id": "house_q13",
        "questionText": "Para lavar o chão da cozinha e da casa de banho, uso um balde e uma ____.",
        "options": ["esfregona", "torradeira", "chaleira", "tábua"],
        "correctAnswer": "esfregona",
        "type": "cloze",
        "sourceItem": {
            "id": "house_src_esfregona",
            "portuguese": "a esfregona",
            "english": "the mop",
            "notes": "Cleaning items: limpar com esfregona"
        },
        "category": "Objetos da Casa"
    },
    {
        "id": "house_q14",
        "questionText": "Para comer bife com batatas, precisamos de dois talheres: um garfo e uma ____.",
        "options": ["faca", "colher", "chávena", "concha"],
        "correctAnswer": "faca",
        "type": "cloze",
        "sourceItem": {
            "id": "house_src_faca",
            "portuguese": "a faca",
            "english": "the knife",
            "notes": "Cutlery: talher para cortar"
        },
        "category": "Objetos da Casa"
    },
    {
        "id": "house_q15",
        "questionText": "Em Portugal, o café expresso é servido numa pequena ____ de porcelana.",
        "options": ["chávena", "panela", "frigideira", "garrafa"],
        "correctAnswer": "chávena",
        "type": "cloze",
        "sourceItem": {
            "id": "house_src_chavena",
            "portuguese": "a chávena",
            "english": "the cup / mug",
            "notes": "Tableware: PT-PT chávena (not xícara)"
        },
        "category": "Objetos da Casa"
    },
    {
        "id": "house_q16",
        "questionText": "Na casa de banho, ela olha-se ao ____ enquanto penteia o cabelo.",
        "options": ["espelho", "tapete", "candeeiro", "guarda-roupa"],
        "correctAnswer": "espelho",
        "type": "cloze",
        "sourceItem": {
            "id": "house_src_espelho",
            "portuguese": "o espelho",
            "english": "the mirror",
            "notes": "Household items: ver o reflexo"
        },
        "category": "Objetos da Casa"
    },
    {
        "id": "house_q17",
        "questionText": "À noite, acendo o ____ da mesa de cabeceira para ler um livro sem perturbar.",
        "options": ["candeeiro", "frigorífico", "aspirador", "fogão"],
        "correctAnswer": "candeeiro",
        "type": "cloze",
        "sourceItem": {
            "id": "house_src_candeeiro",
            "portuguese": "o candeeiro",
            "english": "the lamp",
            "notes": "Household items: PT-PT candeeiro (not luminária / abajur)"
        },
        "category": "Objetos da Casa"
    },
    {
        "id": "house_q18",
        "questionText": "No inverno, cobrimos a cama com um ____ quente para não sentir frio à noite.",
        "options": ["edredão", "espelho", "garfo", "balde"],
        "correctAnswer": "edredão",
        "type": "cloze",
        "sourceItem": {
            "id": "house_src_edredao",
            "portuguese": "o edredão",
            "english": "the duvet / quilt",
            "notes": "Bedding: edredão para a cama"
        },
        "category": "Objetos da Casa"
    },
    {
        "id": "house_q19",
        "questionText": "Depois de tomar duche, seco o corpo com uma ____ de banho turca.",
        "options": ["toalha", "almofada", "cortina", "tábua"],
        "correctAnswer": "toalha",
        "type": "cloze",
        "sourceItem": {
            "id": "house_src_toalha",
            "portuguese": "a toalha",
            "english": "the towel",
            "notes": "Bathroom items: secar com a toalha"
        },
        "category": "Objetos da Casa"
    },
    {
        "id": "house_q20",
        "questionText": "O António fritou dois ovos com azeite na ____ antiaderente.",
        "options": ["frigideira", "chávena", "colher", "chaleira"],
        "correctAnswer": "frigideira",
        "type": "cloze",
        "sourceItem": {
            "id": "house_src_frigideira",
            "portuguese": "a frigideira",
            "english": "the frying pan",
            "notes": "Cookware: frigideira para fritar"
        },
        "category": "Objetos da Casa"
    },
    {
        "id": "house_q21",
        "questionText": "Como se diz 'refrigerator' em português de Portugal?",
        "options": ["Frigorífico", "Geladeira", "Congelador", "Micro-ondas"],
        "correctAnswer": "Frigorífico",
        "type": "multipleChoice",
        "sourceItem": {
            "id": "house_src_frigo_trans",
            "portuguese": "o frigorífico",
            "english": "the refrigerator",
            "notes": "PT-PT vs PT-BR distinction: frigorífico"
        },
        "category": "Objetos da Casa"
    },
    {
        "id": "house_q22",
        "questionText": "Qual é o objeto usado para apoiar a cabeça confortavelmente na cama ou no sofá?",
        "options": ["A almofada", "A tábua", "A vassoura", "A cortina"],
        "correctAnswer": "A almofada",
        "type": "multipleChoice",
        "sourceItem": {
            "id": "house_src_almofada",
            "portuguese": "a almofada",
            "english": "the pillow / cushion",
            "notes": "Bedding & living room: almofada"
        },
        "category": "Objetos da Casa"
    },
    {
        "id": "house_q23",
        "questionText": "Fechei as ____ da sala para bloquear a luz do sol durante a tarde.",
        "options": ["cortinas", "toalhas", "almofadas", "torradeiras"],
        "correctAnswer": "cortinas",
        "type": "cloze",
        "sourceItem": {
            "id": "house_src_cortinas",
            "portuguese": "as cortinas",
            "english": "the curtains",
            "notes": "Furniture & decor: cortinas da janela"
        },
        "category": "Objetos da Casa"
    },
    {
        "id": "house_q24",
        "questionText": "Para cozer o arroz e fazer sopa, utilizamos uma ____ grande com tampa.",
        "options": ["panela", "chávena", "faca", "tábua"],
        "correctAnswer": "panela",
        "type": "cloze",
        "sourceItem": {
            "id": "house_src_panela",
            "portuguese": "a panela",
            "english": "the cooking pot / saucepan",
            "notes": "Cookware: panela com tampa"
        },
        "category": "Objetos da Casa"
    },
    {
        "id": "house_q25",
        "questionText": "Mudamos os ____ da cama todas as semanas para manter os lençóis limpos e perfumados.",
        "options": ["lençóis", "espelhos", "garfos", "pratos"],
        "correctAnswer": "lençóis",
        "type": "cloze",
        "sourceItem": {
            "id": "house_src_lencois",
            "portuguese": "os lençóis",
            "english": "the bed sheets",
            "notes": "Bedding: lençóis da cama"
        },
        "category": "Objetos da Casa"
    }
]

# -----------------------------------------------------------------------------
# 3. UNIT: PARTS OF THE BODY & HEALTH (Partes do Corpo e Saúde)
# -----------------------------------------------------------------------------
BODY_QUESTIONS = [
    {
        "id": "body_q01",
        "questionText": "Passei horas em frente ao ecrã e agora dói-me muito a ____.",
        "options": ["cabeça", "perna", "unha", "mão"],
        "correctAnswer": "cabeça",
        "type": "cloze",
        "sourceItem": {
            "id": "body_src_cabeca",
            "portuguese": "a cabeça",
            "english": "the head",
            "notes": "Body parts & symptoms: dor de cabeça"
        },
        "category": "O Corpo Humano"
    },
    {
        "id": "body_q02",
        "questionText": "Tenho os ____ irritados e vermelhos por causa do vento e do pó.",
        "options": ["olhos", "dentes", "ouvidos", "ombros"],
        "correctAnswer": "olhos",
        "type": "cloze",
        "sourceItem": {
            "id": "body_src_olhos",
            "portuguese": "os olhos",
            "english": "the eyes",
            "notes": "Body parts: visão e olhos"
        },
        "category": "O Corpo Humano"
    },
    {
        "id": "body_q03",
        "questionText": "Quando estamos com constipação, ficamos com o ____ entupido e espirramos.",
        "options": ["nariz", "braço", "cotovelo", "joelho"],
        "correctAnswer": "nariz",
        "type": "cloze",
        "sourceItem": {
            "id": "body_src_nariz",
            "portuguese": "o nariz",
            "english": "the nose",
            "notes": "Body parts: respiração e nariz"
        },
        "category": "O Corpo Humano"
    },
    {
        "id": "body_q04",
        "questionText": "Estou com dores de ____ e custa-me engolir qualquer comida ou bebida.",
        "options": ["garganta", "ouvido", "dente", "costas"],
        "correctAnswer": "garganta",
        "type": "cloze",
        "sourceItem": {
            "id": "body_src_garganta",
            "portuguese": "a garganta",
            "english": "the throat",
            "notes": "Body parts & health: dor de garganta"
        },
        "category": "O Corpo Humano"
    },
    {
        "id": "body_q05",
        "questionText": "Fui ao dentista ontem para tratar de uma cárie num ____ molar.",
        "options": ["dente", "olho", "joelho", "cotovelo"],
        "correctAnswer": "dente",
        "type": "cloze",
        "sourceItem": {
            "id": "body_src_dente",
            "portuguese": "o dente",
            "english": "the tooth",
            "notes": "Body parts & health: os dentes"
        },
        "category": "O Corpo Humano"
    },
    {
        "id": "body_q06",
        "questionText": "O atleta caiu durante a corrida e torceu o ____ do pé direito.",
        "options": ["tornozelo", "pescoço", "ombro", "dente"],
        "correctAnswer": "tornozelo",
        "type": "cloze",
        "sourceItem": {
            "id": "body_src_tornozelo",
            "portuguese": "o tornozelo",
            "english": "the ankle",
            "notes": "Body parts & injuries: articulação do pé"
        },
        "category": "O Corpo Humano"
    },
    {
        "id": "body_q07",
        "questionText": "Trabalho todo o dia sentado no escritório e agora tenho muitas dores nas ____.",
        "options": ["costas", "orelhas", "bochechas", "unhas"],
        "correctAnswer": "costas",
        "type": "cloze",
        "sourceItem": {
            "id": "body_src_costas",
            "portuguese": "as costas",
            "english": "the back",
            "notes": "Body parts & posture: dores nas costas"
        },
        "category": "O Corpo Humano"
    },
    {
        "id": "body_q08",
        "questionText": "Antes de comer, é fundamental lavar as ____ com água tépida e sabão.",
        "options": ["mãos", "pernas", "costas", "orelhas"],
        "correctAnswer": "mãos",
        "type": "cloze",
        "sourceItem": {
            "id": "body_src_maos",
            "portuguese": "as mãos",
            "english": "the hands",
            "notes": "Hygiene & body parts: lavar as mãos"
        },
        "category": "O Corpo Humano"
    },
    {
        "id": "body_q09",
        "questionText": "Ele escorregou nas pedras da calçada e esfolou o ____ ao cair.",
        "options": ["joelho", "pescoço", "estômago", "cabelo"],
        "correctAnswer": "joelho",
        "type": "cloze",
        "sourceItem": {
            "id": "body_src_joelho",
            "portuguese": "o joelho",
            "english": "the knee",
            "notes": "Body parts & accidents: o joelho"
        },
        "category": "O Corpo Humano"
    },
    {
        "id": "body_q10",
        "questionText": "Uso um cachecol de lã quentinho à volta do ____ para não apanhar frio.",
        "options": ["pescoço", "braço", "tornozelo", "cotovelo"],
        "correctAnswer": "pescoço",
        "type": "cloze",
        "sourceItem": {
            "id": "body_src_pescoco",
            "portuguese": "o pescoço",
            "english": "the neck",
            "notes": "Body parts: o pescoço"
        },
        "category": "O Corpo Humano"
    },
    {
        "id": "body_q11",
        "questionText": "Depois da refeição muito pesada com gorduras, fiquei com dores no ____.",
        "options": ["estômago", "ouvido", "ombro", "pulso"],
        "correctAnswer": "estômago",
        "type": "cloze",
        "sourceItem": {
            "id": "body_src_estomago",
            "portuguese": "o estômago / a barriga",
            "english": "the stomach / belly",
            "notes": "Body parts & digestion: dores de estômago"
        },
        "category": "O Corpo Humano"
    },
    {
        "id": "body_q12",
        "questionText": "Em cada mão humana temos cinco ____ com unhas na ponta.",
        "options": ["dedos", "braços", "ombros", "cotovelos"],
        "correctAnswer": "dedos",
        "type": "cloze",
        "sourceItem": {
            "id": "body_src_dedos",
            "portuguese": "os dedos",
            "english": "the fingers",
            "notes": "Body parts: dedos da mão"
        },
        "category": "O Corpo Humano"
    },
    {
        "id": "body_q13",
        "questionText": "Não ouço nada porque tenho uma infeção no ____ direito.",
        "options": ["ouvido", "olho", "nariz", "joelho"],
        "correctAnswer": "ouvido",
        "type": "cloze",
        "sourceItem": {
            "id": "body_src_ouvido",
            "portuguese": "o ouvido",
            "english": "the ear (hearing / inner)",
            "notes": "Body parts: ouvidos para audição (vs orelhas exteriores)"
        },
        "category": "O Corpo Humano"
    },
    {
        "id": "body_q14",
        "questionText": "O médico colocou o estetoscópio no ____ do doente para auscultar o coração.",
        "options": ["peito", "tornozelo", "cotovelo", "pé"],
        "correctAnswer": "peito",
        "type": "cloze",
        "sourceItem": {
            "id": "body_src_peito",
            "portuguese": "o peito",
            "english": "the chest",
            "notes": "Body parts: o peito / tórax"
        },
        "category": "O Corpo Humano"
    },
    {
        "id": "body_q15",
        "questionText": "A articulação entre o braço e o antebraço chama-se ____.",
        "options": ["cotovelo", "joelho", "tornozelo", "pescoço"],
        "correctAnswer": "cotovelo",
        "type": "multipleChoice",
        "sourceItem": {
            "id": "body_src_cotovelo",
            "portuguese": "o cotovelo",
            "english": "the elbow",
            "notes": "Body parts: o cotovelo"
        },
        "category": "O Corpo Humano"
    },
    {
        "id": "body_q16",
        "questionText": "Andei mais de quinze quilómetros a pé e agora tenho bolhas nos ____.",
        "options": ["pés", "ombros", "olhos", "dentes"],
        "correctAnswer": "pés",
        "type": "cloze",
        "sourceItem": {
            "id": "body_src_pes",
            "portuguese": "os pés",
            "english": "the feet",
            "notes": "Body parts: os pés"
        },
        "category": "O Corpo Humano"
    },
    {
        "id": "body_q17",
        "questionText": "A mochila pesada da escola provoca dores nos ____ dos estudantes.",
        "options": ["ombros", "dentes", "lábios", "narizes"],
        "correctAnswer": "ombros",
        "type": "cloze",
        "sourceItem": {
            "id": "body_src_ombros",
            "portuguese": "os ombros",
            "english": "the shoulders",
            "notes": "Body parts: os ombros"
        },
        "category": "O Corpo Humano"
    },
    {
        "id": "body_q18",
        "questionText": "Quando sorrimos abertamente, mostramos os lábios e os ____.",
        "options": ["dentes", "cotovelos", "tornozelos", "joelhos"],
        "correctAnswer": "dentes",
        "type": "cloze",
        "sourceItem": {
            "id": "body_src_dentes_sorriso",
            "portuguese": "os dentes",
            "english": "the teeth",
            "notes": "Face & body: dentes e boca"
        },
        "category": "O Corpo Humano"
    },
    {
        "id": "body_q19",
        "questionText": "Como se diz naturalmente em português de Portugal: 'My head hurts'?",
        "options": ["Dói-me a cabeça.", "A cabeça dói a mim.", "Eu tenho dor de cabeça grande.", "Me dói a cabeça."],
        "correctAnswer": "Dói-me a cabeça.",
        "type": "multipleChoice",
        "sourceItem": {
            "id": "body_src_doi_me_cabeca",
            "portuguese": "Dói-me a cabeça.",
            "english": "My head hurts.",
            "notes": "Natural PT-PT pronoun placement: verbo + pronome clítico"
        },
        "category": "O Corpo Humano"
    },
    {
        "id": "body_q20",
        "questionText": "Como se diz 'throat' em português?",
        "options": ["A garganta", "O pescoço", "A barriga", "O ombro"],
        "correctAnswer": "A garganta",
        "type": "multipleChoice",
        "sourceItem": {
            "id": "body_src_garganta_trans",
            "portuguese": "a garganta",
            "english": "the throat",
            "notes": "Body parts vocabulary"
        },
        "category": "O Corpo Humano"
    },
    {
        "id": "body_q21",
        "questionText": "O médico mediu a temperatura com um termómetro porque o doente tinha ____ alta.",
        "options": ["febre", "sede", "fome", "sono"],
        "correctAnswer": "febre",
        "type": "cloze",
        "sourceItem": {
            "id": "body_src_febre",
            "portuguese": "a febre",
            "english": "the fever",
            "notes": "Health: febre alta"
        },
        "category": "O Corpo Humano"
    },
    {
        "id": "body_q22",
        "questionText": "A enfermeira colocou um penso rápido no corte do meu ____.",
        "options": ["dedo", "olho", "coração", "pulmão"],
        "correctAnswer": "dedo",
        "type": "cloze",
        "sourceItem": {
            "id": "body_src_penso_dedo",
            "portuguese": "o penso rápido",
            "english": "the plaster / band-aid",
            "notes": "Health & first aid: PT-PT penso rápido (not band-aid)"
        },
        "category": "O Corpo Humano"
    },
    {
        "id": "body_q23",
        "questionText": "Ele caiu de bicicleta e partiu o ____ esquerdo; agora tem o gesso até à mão.",
        "options": ["braço", "nariz", "pescoço", "ouvido"],
        "correctAnswer": "braço",
        "type": "cloze",
        "sourceItem": {
            "id": "body_src_braco_partido",
            "portuguese": "o braço",
            "english": "the arm",
            "notes": "Body parts & injuries: o braço"
        },
        "category": "O Corpo Humano"
    },
    {
        "id": "body_q24",
        "questionText": "Usamos o relógio no ____ esquerdo para ver as horas.",
        "options": ["pulso", "ombro", "nariz", "calcanhar"],
        "correctAnswer": "pulso",
        "type": "cloze",
        "sourceItem": {
            "id": "body_src_pulso",
            "portuguese": "o pulso",
            "english": "the wrist",
            "notes": "Body parts: o pulso"
        },
        "category": "O Corpo Humano"
    },
    {
        "id": "body_q25",
        "questionText": "Tenho uma tosse seca e muita comichão na ____; vou beber chá com mel.",
        "options": ["garganta", "perna", "costela", "orelha"],
        "correctAnswer": "garganta",
        "type": "cloze",
        "sourceItem": {
            "id": "body_src_tosse_garganta",
            "portuguese": "a tosse",
            "english": "the cough",
            "notes": "Health & symptoms: tosse e dor de garganta"
        },
        "category": "O Corpo Humano"
    }
]

# -----------------------------------------------------------------------------
# 4. UNIT: EVERYDAY ITEMS & ACCESSORIES (Objetos do Quotidiano)
# -----------------------------------------------------------------------------
EVERYDAY_QUESTIONS = [
    {
        "id": "day_q01",
        "questionText": "A bateria do meu ____ acabou; não posso receber chamadas nem mensagens.",
        "options": ["telemóvel", "guarda-chuva", "carteira", "casaco"],
        "correctAnswer": "telemóvel",
        "type": "cloze",
        "sourceItem": {
            "id": "day_src_telemovel",
            "portuguese": "o telemóvel",
            "english": "the mobile phone",
            "notes": "Everyday items: PT-PT telemóvel (not celular)"
        },
        "category": "Objetos do Quotidiano"
    },
    {
        "id": "day_q02",
        "questionText": "Onde está o ____? Preciso de ligar o telemóvel à tomada da parede.",
        "options": ["carregador", "guarda-chuva", "bilhete", "caderno"],
        "correctAnswer": "carregador",
        "type": "cloze",
        "sourceItem": {
            "id": "day_src_carregador",
            "portuguese": "o carregador",
            "english": "the charger",
            "notes": "Everyday electronics: carregador de bateria"
        },
        "category": "Objetos do Quotidiano"
    },
    {
        "id": "day_q03",
        "questionText": "Esqueci-me das ____ de casa dentro do casaco e agora não consigo abrir a porta.",
        "options": ["chaves", "canetas", "garrafas", "janelas"],
        "correctAnswer": "chaves",
        "type": "cloze",
        "sourceItem": {
            "id": "day_src_chaves",
            "portuguese": "as chaves",
            "english": "the keys",
            "notes": "Everyday belongings: chaves de casa"
        },
        "category": "Objetos do Quotidiano"
    },
    {
        "id": "day_q04",
        "questionText": "Perdi a minha ____ com o dinheiro, o cartão bancário e o cartão de cidadão.",
        "options": ["carteira", "garrafa", "chave", "janela"],
        "correctAnswer": "carteira",
        "type": "cloze",
        "sourceItem": {
            "id": "day_src_carteira",
            "portuguese": "a carteira",
            "english": "the wallet",
            "notes": "Personal belongings: carteira"
        },
        "category": "Objetos do Quotidiano"
    },
    {
        "id": "day_q05",
        "questionText": "Em Lisboa, valido o meu ____ mensal nos validadores antes de entrar no metro.",
        "options": ["passe", "guarda-chuva", "óculo", "carregador"],
        "correctAnswer": "passe",
        "type": "cloze",
        "sourceItem": {
            "id": "day_src_passe",
            "portuguese": "o passe de transportes",
            "english": "the transit pass",
            "notes": "Public transport: passe mensal de transportes"
        },
        "category": "Objetos do Quotidiano"
    },
    {
        "id": "day_q06",
        "questionText": "Está a chover torrencialmente lá fora; leva o teu ____ para não te molhares.",
        "options": ["guarda-chuva", "óculos de sol", "telemóvel", "carregador"],
        "correctAnswer": "guarda-chuva",
        "type": "cloze",
        "sourceItem": {
            "id": "day_src_guardachuva",
            "portuguese": "o guarda-chuva",
            "english": "the umbrella",
            "notes": "Weather accessories: proteger da chuva"
        },
        "category": "Objetos do Quotidiano"
    },
    {
        "id": "day_q07",
        "questionText": "Para proteger os olhos do sol forte de verão, uso sempre uns ____ de sol escuros.",
        "options": ["óculos", "auscultadores", "passes", "relógios"],
        "correctAnswer": "óculos",
        "type": "cloze",
        "sourceItem": {
            "id": "day_src_oculos_sol",
            "portuguese": "os óculos de sol",
            "english": "the sunglasses",
            "notes": "Accessories: óculos de sol"
        },
        "category": "Objetos do Quotidiano"
    },
    {
        "id": "day_q08",
        "questionText": "No comboio, ponho os ____ para ouvir música sem incomodar os outros passageiros.",
        "options": ["auscultadores", "sapatos", "óculos", "carregadores"],
        "correctAnswer": "auscultadores",
        "type": "cloze",
        "sourceItem": {
            "id": "day_src_auscultadores",
            "portuguese": "os auscultadores",
            "english": "the headphones / earphones",
            "notes": "Everyday electronics: PT-PT auscultadores (not fones de ouvido)"
        },
        "category": "Objetos do Quotidiano"
    },
    {
        "id": "day_q09",
        "questionText": "Guardo os meus cadernos e o computador portátil dentro da ____ para ir à faculdade.",
        "options": ["mochila", "carteira", "garrafa", "tomada"],
        "correctAnswer": "mochila",
        "type": "cloze",
        "sourceItem": {
            "id": "day_src_mochila",
            "portuguese": "a mochila",
            "english": "the backpack",
            "notes": "Bags: mochila às costas"
        },
        "category": "Objetos do Quotidiano"
    },
    {
        "id": "day_q10",
        "questionText": "Olhei para o meu relógio de ____ para ver quantos minutos faltavam para o comboio.",
        "options": ["pulso", "parede", "mesa", "bolso"],
        "correctAnswer": "pulso",
        "type": "cloze",
        "sourceItem": {
            "id": "day_src_relogio_pulso",
            "portuguese": "o relógio de pulso",
            "english": "the wristwatch",
            "notes": "Accessories: relógio no pulso"
        },
        "category": "Objetos do Quotidiano"
    },
    {
        "id": "day_q11",
        "questionText": "Tens uma ____ azul ou preta para eu assinar este contrato de arrendamento?",
        "options": ["caneta", "chave", "garrafa", "moeda"],
        "correctAnswer": "caneta",
        "type": "cloze",
        "sourceItem": {
            "id": "day_src_caneta",
            "portuguese": "a caneta",
            "english": "the pen",
            "notes": "Stationery: caneta para escrever"
        },
        "category": "Objetos do Quotidiano"
    },
    {
        "id": "day_q12",
        "questionText": "Para me manter hidratado no ginásio, levo sempre uma ____ de água cheia.",
        "options": ["garrafa", "carteira", "caneta", "tomada"],
        "correctAnswer": "garrafa",
        "type": "cloze",
        "sourceItem": {
            "id": "day_src_garrafa_agua",
            "portuguese": "a garrafa de água",
            "english": "the water bottle",
            "notes": "Daily essentials: garrafa de água"
        },
        "category": "Objetos do Quotidiano"
    },
    {
        "id": "day_q13",
        "questionText": "Estou com alergia e a espirrar; tens um ____ de papel para assoar o nariz?",
        "options": ["lenço", "passe", "carregador", "bilhete"],
        "correctAnswer": "lenço",
        "type": "cloze",
        "sourceItem": {
            "id": "day_src_lenco_papel",
            "portuguese": "o lenço de papel",
            "english": "the paper tissue",
            "notes": "Hygiene items: lenços de papel descartáveis"
        },
        "category": "Objetos do Quotidiano"
    },
    {
        "id": "day_q14",
        "questionText": "Para pagar o café em moedas pequenas, tiro as moedas do meu ____.",
        "options": ["porta-moedas", "guarda-chuva", "computador", "carregador"],
        "correctAnswer": "porta-moedas",
        "type": "cloze",
        "sourceItem": {
            "id": "day_src_portamoedas",
            "portuguese": "o porta-moedas",
            "english": "the coin purse",
            "notes": "Accessories: porta-moedas"
        },
        "category": "Objetos do Quotidiano"
    },
    {
        "id": "day_q15",
        "questionText": "O documento oficial de identificação dos cidadãos em Portugal é o Cartão de ____.",
        "options": ["Cidadão", "Transportes", "Visita", "Crédito"],
        "correctAnswer": "Cidadão",
        "type": "cloze",
        "sourceItem": {
            "id": "day_src_cartao_cidadao",
            "portuguese": "o Cartão de Cidadão",
            "english": "the Citizen Card / ID card",
            "notes": "Identity documents: Cartão de Cidadão (Portugal)"
        },
        "category": "Objetos do Quotidiano"
    },
    {
        "id": "day_q16",
        "questionText": "Como se diz 'cell phone / mobile phone' em Portugal?",
        "options": ["O telemóvel", "O celular", "O telefone de bolso", "O aparelho"],
        "correctAnswer": "O telemóvel",
        "type": "multipleChoice",
        "sourceItem": {
            "id": "day_src_telemovel_trans",
            "portuguese": "o telemóvel",
            "english": "the mobile phone",
            "notes": "PT-PT vs PT-BR distinction: telemóvel"
        },
        "category": "Objetos do Quotidiano"
    },
    {
        "id": "day_q17",
        "questionText": "Como se diz 'headphones' em português europeu?",
        "options": ["Os auscultadores", "Os fones de ouvido", "Os capacetes", "Os alto-falantes"],
        "correctAnswer": "Os auscultadores",
        "type": "multipleChoice",
        "sourceItem": {
            "id": "day_src_auscultadores_trans",
            "portuguese": "os auscultadores",
            "english": "the headphones",
            "notes": "PT-PT term: auscultadores"
        },
        "category": "Objetos do Quotidiano"
    },
    {
        "id": "day_q18",
        "questionText": "O cabo do carregador liga-se à ____ elétrica da parede para receber energia.",
        "options": ["tomada", "chave", "caneta", "mochila"],
        "correctAnswer": "tomada",
        "type": "cloze",
        "sourceItem": {
            "id": "day_src_tomada",
            "portuguese": "a tomada",
            "english": "the wall socket / outlet",
            "notes": "Electrical fixtures: tomada elétrica"
        },
        "category": "Objetos do Quotidiano"
    },
    {
        "id": "day_q19",
        "questionText": "Para a viagem de fim de semana ao Porto, levo apenas uma pequena ____ com roupa.",
        "options": ["mala", "chave", "caneta", "tomada"],
        "correctAnswer": "mala",
        "type": "cloze",
        "sourceItem": {
            "id": "day_src_mala",
            "portuguese": "a mala de viagem",
            "english": "the suitcase / bag",
            "notes": "Travel: mala de viagem"
        },
        "category": "Objetos do Quotidiano"
    },
    {
        "id": "day_q20",
        "questionText": "Durante as aulas, escrevo todos os apontamentos importantes no meu ____.",
        "options": ["caderno", "guarda-chuva", "auscultador", "passe"],
        "correctAnswer": "caderno",
        "type": "cloze",
        "sourceItem": {
            "id": "day_src_caderno",
            "portuguese": "o caderno",
            "english": "the notebook",
            "notes": "Stationery: caderno de apontamentos"
        },
        "category": "Objetos do Quotidiano"
    },
    {
        "id": "day_q21",
        "questionText": "Antes de sair de casa de manhã, verifico se tenho os quatro essenciais: telemóvel, carteira, passe e ____.",
        "options": ["chaves", "candeeiros", "fogões", "panelas"],
        "correctAnswer": "chaves",
        "type": "cloze",
        "sourceItem": {
            "id": "day_src_quatro_essenciais",
            "portuguese": "as chaves",
            "english": "the keys",
            "notes": "Daily routine: telemóvel, carteira, passe e chaves"
        },
        "category": "Objetos do Quotidiano"
    },
    {
        "id": "day_q22",
        "questionText": "Comprei um bilhete simples na máquina automática porque me esqueci do ____ em casa.",
        "options": ["passe", "casaco", "chapéu", "óculo"],
        "correctAnswer": "passe",
        "type": "cloze",
        "sourceItem": {
            "id": "day_src_bilhete_passe",
            "portuguese": "o bilhete",
            "english": "the ticket",
            "notes": "Public transport: bilhete vs passe"
        },
        "category": "Objetos do Quotidiano"
    },
    {
        "id": "day_q23",
        "questionText": "Para trabalhar no comboio ou na esplanada, levo o meu computador ____ na mochila.",
        "options": ["portátil", "de mesa", "grande", "pesado"],
        "correctAnswer": "portátil",
        "type": "cloze",
        "sourceItem": {
            "id": "day_src_portatil",
            "portuguese": "o computador portátil",
            "english": "the laptop",
            "notes": "Electronics: computador portátil (laptop)"
        },
        "category": "Objetos do Quotidiano"
    },
    {
        "id": "day_q24",
        "questionText": "Quando o dia está muito quente e abafado, uso um ____ para me abanar e refrescar.",
        "options": ["leque", "ferro", "casaco", "edredão"],
        "correctAnswer": "leque",
        "type": "cloze",
        "sourceItem": {
            "id": "day_src_leque",
            "portuguese": "o leque",
            "english": "the hand fan",
            "notes": "Summer accessories: leque"
        },
        "category": "Objetos do Quotidiano"
    },
    {
        "id": "day_q25",
        "questionText": "Guardo os recibos de compras e os talões de pagamento num envelope dentro da ____.",
        "options": ["gaveta", "panela", "garrafa", "tomada"],
        "correctAnswer": "gaveta",
        "type": "cloze",
        "sourceItem": {
            "id": "day_src_gaveta",
            "portuguese": "a gaveta",
            "english": "the drawer",
            "notes": "Furniture: a gaveta da secretária"
        },
        "category": "Objetos do Quotidiano"
    }
]

# -----------------------------------------------------------------------------
# 5. SOURCE.MD VOCABULARY & PHRASES (for general quiz & dictionary expansion)
# -----------------------------------------------------------------------------
NEW_SOURCE_ITEMS = [
    # Rooms in the house
    ("a cozinha", "the kitchen", "Home - Rooms"),
    ("o quarto", "the bedroom", "Home - Rooms"),
    ("a casa de banho", "the bathroom", "Home - Rooms"),
    ("a sala de estar", "the living room", "Home - Rooms"),
    ("a sala de jantar", "the dining room", "Home - Rooms"),
    ("o corredor", "the corridor / hallway", "Home - Rooms"),
    ("o hall de entrada", "the entrance hall", "Home - Rooms"),
    ("a despensa", "the pantry / larder", "Home - Rooms"),
    ("a varanda", "the balcony", "Home - Rooms"),
    ("a marquise", "the sunroom / enclosed balcony", "Home - Rooms"),
    ("o terraço", "the terrace", "Home - Rooms"),
    ("a garagem", "the garage", "Home - Rooms"),
    ("o sótão", "the attic", "Home - Rooms"),
    ("a cave", "the basement / cellar", "Home - Rooms"),
    ("o jardim", "the garden", "Home - Rooms"),
    ("o rés do chão", "the ground floor", "Home - Rooms"),
    ("o primeiro andar", "the first floor", "Home - Rooms"),
    ("as escadas", "the stairs", "Home - Rooms"),
    ("a lareira", "the fireplace", "Home - Rooms"),
    ("o roupeiro", "the wardrobe", "Home - Rooms"),

    # Household items & appliances
    ("o frigorífico", "the refrigerator", "Household - Items"),
    ("o congelador", "the freezer", "Household - Items"),
    ("o fogão", "the stove / cooker", "Household - Items"),
    ("o forno", "the oven", "Household - Items"),
    ("o micro-ondas", "the microwave", "Household - Items"),
    ("a máquina de lavar loiça", "the dishwasher", "Household - Items"),
    ("a máquina de lavar roupa", "the washing machine", "Household - Items"),
    ("o aspirador", "the vacuum cleaner", "Household - Items"),
    ("a torradeira", "the toaster", "Household - Items"),
    ("a chaleira elétrica", "the electric kettle", "Household - Items"),
    ("o ferro de engomar", "the clothes iron", "Household - Items"),
    ("a tábua de engomar", "the ironing board", "Household - Items"),
    ("a vassoura", "the broom", "Household - Items"),
    ("a esfregona", "the mop", "Household - Items"),
    ("o caixote do lixo", "the rubbish bin", "Household - Items"),
    ("o candeeiro", "the lamp", "Household - Items"),
    ("o sofá", "the sofa", "Household - Items"),
    ("o tapete", "the rug / carpet", "Household - Items"),
    ("as cortinas", "the curtains", "Household - Items"),
    ("o espelho", "the mirror", "Household - Items"),
    ("a almofada", "the cushion / pillow", "Household - Items"),
    ("os lençóis", "the bed sheets", "Household - Items"),
    ("o edredão", "the duvet", "Household - Items"),
    ("a toalha", "the towel", "Household - Items"),
    ("a panela", "the pot / saucepan", "Household - Items"),
    ("a frigideira", "the frying pan", "Household - Items"),
    ("os talheres", "the cutlery", "Household - Items"),
    ("o garfo", "the fork", "Household - Items"),
    ("a faca", "the knife", "Household - Items"),
    ("a colher", "the spoon", "Household - Items"),
    ("o prato", "the plate", "Household - Items"),
    ("o copo", "the glass", "Household - Items"),
    ("a chávena", "the cup / mug", "Household - Items"),
    ("a torneira", "the tap / faucet", "Household - Items"),

    # Parts of the body & health
    ("a cabeça", "the head", "Body & Health"),
    ("os olhos", "the eyes", "Body & Health"),
    ("o nariz", "the nose", "Body & Health"),
    ("a boca", "the mouth", "Body & Health"),
    ("os lábios", "the lips", "Body & Health"),
    ("os dentes", "the teeth", "Body & Health"),
    ("a língua", "the tongue", "Body & Health"),
    ("a garganta", "the throat", "Body & Health"),
    ("os ouvidos", "the ears (hearing)", "Body & Health"),
    ("as orelhas", "the ears (outer)", "Body & Health"),
    ("o pescoço", "the neck", "Body & Health"),
    ("os ombros", "the shoulders", "Body & Health"),
    ("o peito", "the chest", "Body & Health"),
    ("as costas", "the back", "Body & Health"),
    ("os braços", "the arms", "Body & Health"),
    ("o cotovelo", "the elbow", "Body & Health"),
    ("o pulso", "the wrist", "Body & Health"),
    ("as mãos", "the hands", "Body & Health"),
    ("os dedos", "the fingers", "Body & Health"),
    ("as unhas", "the nails", "Body & Health"),
    ("a barriga", "the belly", "Body & Health"),
    ("o estômago", "the stomach", "Body & Health"),
    ("as pernas", "the legs", "Body & Health"),
    ("o joelho", "the knee", "Body & Health"),
    ("o tornozelo", "the ankle", "Body & Health"),
    ("os pés", "the feet", "Body & Health"),
    ("Dói-me a cabeça.", "My head hurts.", "Body & Health"),
    ("Dói-me a garganta.", "My throat hurts.", "Body & Health"),
    ("Estou com dores nas costas.", "I have back pain.", "Body & Health"),
    ("a febre", "the fever", "Body & Health"),
    ("a tosse", "the cough", "Body & Health"),
    ("o penso rápido", "the plaster / band-aid", "Body & Health"),

    # Everyday items & accessories
    ("o telemóvel", "the mobile phone", "Everyday Items"),
    ("o carregador", "the charger", "Everyday Items"),
    ("os auscultadores", "the headphones", "Everyday Items"),
    ("o computador portátil", "the laptop", "Everyday Items"),
    ("a carteira", "the wallet", "Everyday Items"),
    ("o porta-moedas", "the coin purse", "Everyday Items"),
    ("as chaves de casa", "the house keys", "Everyday Items"),
    ("o passe de transportes", "the transit pass", "Everyday Items"),
    ("os óculos de sol", "the sunglasses", "Everyday Items"),
    ("o guarda-chuva", "the umbrella", "Everyday Items"),
    ("o relógio de pulso", "the wristwatch", "Everyday Items"),
    ("a mochila", "the backpack", "Everyday Items"),
    ("a mala de viagem", "the suitcase", "Everyday Items"),
    ("a garrafa de água", "the water bottle", "Everyday Items"),
    ("o lenço de papel", "the paper tissue", "Everyday Items"),
    ("a caneta", "the pen", "Everyday Items"),
    ("o caderno", "the notebook", "Everyday Items"),
    ("o Cartão de Cidadão", "the Citizen ID Card", "Everyday Items"),
    ("a tomada elétrica", "the electrical wall socket", "Everyday Items"),
    ("a gaveta", "the drawer", "Everyday Items"),
]

# Conversational phrases for phrases.json
NEW_PHRASES = [
    {"portuguese": "Onde fica a casa de banho?", "english": "Where is the bathroom?"},
    {"portuguese": "A Maria está a cozinhar na cozinha.", "english": "Maria is cooking in the kitchen."},
    {"portuguese": "Dói-me muito a cabeça hoje.", "english": "My head hurts a lot today."},
    {"portuguese": "Estou com dores de garganta e febre.", "english": "I have a sore throat and fever."},
    {"portuguese": "Esqueci-me das chaves dentro de casa.", "english": "I forgot the keys inside the house."},
    {"portuguese": "A bateria do meu telemóvel acabou.", "english": "My mobile phone battery ran out."},
    {"portuguese": "Põe o leite no frigorífico, por favor.", "english": "Put the milk in the fridge, please."},
    {"portuguese": "Está a chover, não te esqueças do guarda-chuva.", "english": "It is raining, do not forget the umbrella."},
    {"portuguese": "Validei o passe antes de entrar no metro.", "english": "I validated the pass before entering the metro."},
    {"portuguese": "Lavo sempre as mãos antes de comer.", "english": "I always wash my hands before eating."},
    {"portuguese": "Vou passar o aspirador na sala de estar.", "english": "I am going to vacuum the living room."},
    {"portuguese": "Ele partiu o braço numa queda de bicicleta.", "english": "He broke his arm in a bicycle fall."}
]

# Verb phrases for verb_phrases.json
NEW_VERB_PHRASES = [
    {"verb": "engomar", "portuguese": "Eu engomo a camisa com o ferro.", "english": "I iron the shirt with the iron."},
    {"verb": "aspirar", "portuguese": "Nós aspiramos a sala todos os sábados.", "english": "We vacuum the living room every Saturday."},
    {"verb": "lavar", "portuguese": "Ela lava a loiça na máquina de lavar.", "english": "She washes the dishes in the dishwasher."},
    {"verb": "torcer", "portuguese": "O jogador torceu o tornozelo no treino.", "english": "The player sprained his ankle in training."},
    {"verb": "carregar", "portuguese": "Eu carrego o meu telemóvel durante a noite.", "english": "I charge my mobile phone overnight."},
    {"verb": "estender", "portuguese": "Eles estendem a roupa lavada na varanda.", "english": "They hang the washed laundry on the balcony."},
    {"verb": "doer", "portuguese": "Dói-me o dente desde ontem à noite.", "english": "My tooth has been hurting since last night."},
    {"verb": "esquecer", "portuguese": "Esqueci-me da carteira em casa.", "english": "I forgot my wallet at home."}
]


def write_exercise_json(filename, questions):
    path = REPO_ROOT / f"assets/data/exercises/{filename}"
    with open(path, "w", encoding="utf-8") as f:
        json.dump(questions, f, indent=2, ensure_ascii=False)
    print(f"Wrote {len(questions)} questions to {path}")


def update_source_markdown():
    path = REPO_ROOT / "assets/data/source.md"
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()

    # Find existing portuguese entries to avoid duplicate rows
    existing_pts = set()
    for line in content.splitlines():
        if line.startswith("|"):
            parts = [p.strip() for p in line.split("|")]
            if len(parts) >= 2 and parts[1]:
                existing_pts.add(parts[1].lower())

    items_to_add = [
        item for item in NEW_SOURCE_ITEMS
        if item[0].lower() not in existing_pts
    ]

    if not items_to_add:
        print("All source items already exist in source.md.")
        return

    section = "\n# A2 Core Vocabulary: House, Rooms, Body & Everyday Items\n\n"
    section += "| Portugues | English | Notes |\n"
    section += "| :---- | :---- | :---- |\n"
    for pt, en, notes in items_to_add:
        section += f"| {pt} | {en} | {notes} |\n"

    with open(path, "a", encoding="utf-8") as f:
        f.write(section)
    print(f"Appended {len(items_to_add)} new vocabulary items to {path}")


def update_phrases_json():
    path = REPO_ROOT / "assets/data/phrases.json"
    with open(path, "r", encoding="utf-8") as f:
        phrases = json.load(f)

    existing_pts = {p.get("portuguese", "").strip().lower() for p in phrases}
    added_count = 0
    for p in NEW_PHRASES:
        if p["portuguese"].strip().lower() not in existing_pts:
            phrases.append(p)
            added_count += 1

    if added_count > 0:
        with open(path, "w", encoding="utf-8") as f:
            json.dump(phrases, f, indent=2, ensure_ascii=False)
        print(f"Added {added_count} phrases to {path}")
    else:
        print("Phrases already up to date.")


def update_verb_phrases_json():
    path = REPO_ROOT / "assets/data/verb_phrases.json"
    with open(path, "r", encoding="utf-8") as f:
        vphrases = json.load(f)

    existing_pts = {vp.get("portuguese", "").strip().lower() for vp in vphrases}
    added_count = 0
    for vp in NEW_VERB_PHRASES:
        if vp["portuguese"].strip().lower() not in existing_pts:
            vphrases.append(vp)
            added_count += 1

    if added_count > 0:
        with open(path, "w", encoding="utf-8") as f:
            json.dump(vphrases, f, indent=2, ensure_ascii=False)
        print(f"Added {added_count} verb phrases to {path}")
    else:
        print("Verb phrases already up to date.")


def register_units_in_screen():
    screen_path = REPO_ROOT / "lib/ui/exercise/exercise_list_screen.dart"
    with open(screen_path, "r", encoding="utf-8") as f:
        content = f.read()

    new_units = [
        {
            "title": "Unit 12: Rooms in the House",
            "subtitle": "As divisões da casa: cozinha, sala, quarto, casa de banho...",
            "path": "assets/data/exercises/unit_rooms_in_the_house.json",
            "icon": "home",
        },
        {
            "title": "Unit 13: Household Items & Appliances",
            "subtitle": "Objetos da casa: frigorífico, loiça, aspirador, utensílios...",
            "path": "assets/data/exercises/unit_household_items.json",
            "icon": "build",
        },
        {
            "title": "Unit 14: Parts of the Body & Health",
            "subtitle": "O corpo humano: partes do corpo, dores, sintomas e cuidados...",
            "path": "assets/data/exercises/unit_body_parts_and_health.json",
            "icon": "person",
        },
        {
            "title": "Unit 15: Everyday Items & Belongings",
            "subtitle": "Objetos do dia a dia: telemóvel, chaves, carteira, passe...",
            "path": "assets/data/exercises/unit_everyday_items.json",
            "icon": "school",
        },
    ]

    entries_to_insert = []
    for u in new_units:
        if u["path"] not in content:
            entry = f"""    {{
      'title': '{u["title"]}',
      'subtitle': '{u["subtitle"]}',
      'path': '{u["path"]}',
      'icon': '{u["icon"]}',
    }},
"""
            entries_to_insert.append(entry)

    if entries_to_insert:
        marker = "\n  ];\n\n  @override"
        idx = content.find(marker)
        if idx != -1:
            joined_entries = "".join(entries_to_insert)
            content = content[:idx] + "\n" + joined_entries.rstrip() + content[idx:]

            # Check if 'home' is handled in _getIcon
            if "case 'home':" not in content:
                icon_marker = "      case 'person':\n        return Icons.person;"
                home_case = "      case 'home':\n        return Icons.home;\n"
                if icon_marker in content:
                    content = content.replace(icon_marker, icon_marker + "\n" + home_case)

            with open(screen_path, "w", encoding="utf-8") as f:
                f.write(content)
            print(f"Registered {len(entries_to_insert)} new units in {screen_path}")
        else:
            print("Warning: could not locate unit list end marker in ExerciseListScreen")
    else:
        print("Units already registered in ExerciseListScreen.")


def validate_exercise_invariants(unit_files):
    for filename in unit_files:
        path = REPO_ROOT / f"assets/data/exercises/{filename}"
        assert path.exists(), f"File {path} does not exist"
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)

        assert len(data) >= 20, f"{filename} has fewer than 20 questions"
        seen_ids = set()
        for q in data:
            qid = q.get("id")
            assert qid and qid not in seen_ids, f"Duplicate or missing id {qid} in {filename}"
            seen_ids.add(qid)

            qtext = q.get("questionText")
            assert qtext, f"Missing questionText for {qid} in {filename}"

            options = q.get("options")
            assert isinstance(options, list) and len(options) >= 4, f"Options < 4 in {qid}"

            correct = q.get("correctAnswer")
            assert correct in options, f"correctAnswer '{correct}' not in options in {qid}"

            src = q.get("sourceItem")
            assert isinstance(src, dict), f"sourceItem not dict in {qid}"
            assert src.get("portuguese") and src.get("english"), f"Incomplete sourceItem in {qid}"

    print(f"Validated all {len(unit_files)} exercise units successfully.")


def main():
    print("=== Adding A2 Topic Exercises for Portuguese PT ===")

    # 1. Create exercise unit files
    write_exercise_json("unit_rooms_in_the_house.json", ROOMS_QUESTIONS)
    write_exercise_json("unit_household_items.json", HOUSEHOLD_QUESTIONS)
    write_exercise_json("unit_body_parts_and_health.json", BODY_QUESTIONS)
    write_exercise_json("unit_everyday_items.json", EVERYDAY_QUESTIONS)

    # 2. Validate invariants
    validate_exercise_invariants([
        "unit_rooms_in_the_house.json",
        "unit_household_items.json",
        "unit_body_parts_and_health.json",
        "unit_everyday_items.json"
    ])

    # 3. Update source markdown
    update_source_markdown()

    # 4. Update phrases & verb phrases
    update_phrases_json()
    update_verb_phrases_json()

    # 5. Register in ExerciseListScreen
    register_units_in_screen()

    print("Completed generation script.")


if __name__ == "__main__":
    main()
