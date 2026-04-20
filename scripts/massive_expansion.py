import json
import os

SOURCE_FILE = "assets/data/source.md"
VERB_PHRASES_FILE = "assets/data/verb_phrases.json"
INTERROGATIVES_FILE = "assets/data/interrogatives.json"

EXPANSIONS = {
    "macacos": [
        ("Os macacos saltam entre as árvores.", "Monkeys jump between the trees."),
        ("O macaco come uma banana.", "The monkey eats a banana."),
        ("Vimos vários macacos no jardim zoológico.", "We saw several monkeys at the zoo."),
        ("Aquele macaco é muito engraçado.", "That monkey is very funny."),
        ("Os macacos são animais espertos.", "Monkeys are clever animals.")
    ],
    "preguiça": [
        ("O bicho-preguiça move-se muito devagar.", "The sloth moves very slowly."),
        ("Hoje sinto uma preguiça enorme.", "Today I feel an enormous laziness."),
        ("Não tenhas preguiça, vamos caminhar!", "Don't be lazy, let's go for a walk!"),
        ("A preguiça vive na floresta tropical.", "The sloth lives in the tropical forest."),
        ("Dormir até tarde é a minha preguiça favorita.", "Sleeping late is my favorite laziness.")
    ],
    "sapos": [
        ("Os sapos saltam para o lago.", "The frogs jump into the lake."),
        ("O sapo é verde e rugoso.", "The frog is green and rough."),
        ("Ouvimos os sapos a coaxar à noite.", "We heard the frogs croaking at night."),
        ("Há muitos sapos no jardim depois da chuva.", "There are many frogs in the garden after the rain."),
        ("O príncipe transformou-se num sapo.", "The prince turned into a frog.")
    ],
    "barata": [
        ("Vi uma barata na cozinha hoje.", "I saw a cockroach in the kitchen today."),
        ("Esta camisola é muito barata.", "This sweater is very cheap."),
        ("As baratas saem à noite.", "Cockroaches come out at night."),
        ("É melhor comprar fruta barata no mercado.", "It's better to buy cheap fruit at the market."),
        ("Tens medo de baratas?", "Are you afraid of cockroaches?")
    ],
    "Montanha": [
        ("A montanha é muito alta.", "The mountain is very high."),
        ("Vamos subir a montanha amanhã.", "We are going to climb the mountain tomorrow."),
        ("O topo da montanha está coberto de neve.", "The top of the mountain is covered with snow."),
        ("Gosto de ver o nascer do sol na montanha.", "I like to see the sunrise in the mountain."),
        ("O ar na montanha é puro.", "The air in the mountain is pure.")
    ],
    "chinelos": [
        ("Visto os meus chinelos quando chego a casa.", "I put on my flip flops when I get home."),
        ("Perdi os meus chinelos na praia.", "I lost my flip flops at the beach."),
        ("Onde estão os meus chinelos de quarto?", "Where are my house slippers?"),
        ("Estes chinelos são muito confortáveis.", "These flip flops are very comfortable."),
        ("Vou comprar uns chinelos novos para o verão.", "I'm going to buy new flip flops for the summer.")
    ],
    "verão": [
        ("O verão é a minha estação favorita.", "Summer is my favorite season."),
        ("No verão faz muito calor.", "In summer it is very hot."),
        ("Vamos de férias no próximo verão.", "We are going on holiday next summer."),
        ("As noites de verão são agradáveis.", "Summer nights are pleasant."),
        ("Eu gosto de comer gelados no verão.", "I like to eat ice cream in summer.")
    ],
    "comboio": [
        ("Vou para o trabalho de comboio.", "I go to work by train."),
        ("O comboio parte às oito horas.", "The train departs at eight o'clock."),
        ("O bilhete de comboio é caro.", "The train ticket is expensive."),
        ("Apanhei o comboio errado hoje.", "I caught the wrong train today."),
        ("A viagem de comboio demora duas horas.", "The train trip takes two hours.")
    ],
    "lavar": [
        ("Vou lavar as mãos antes de jantar.", "I'm going to wash my hands before dinner."),
        ("Ela lava a roupa aos sábados.", "She washes the clothes on Saturdays."),
        ("Tens de lavar o teu carro.", "You have to wash your car."),
        ("Nós lavamos a loiça juntos.", "We wash the dishes together."),
        ("Onde posso lavar o rosto?", "Where can I wash my face?")
    ],
    "vestir": [
        ("Vou vestir um casaco quente.", "I'm going to put on a warm coat."),
        ("Preciso de me vestir para sair.", "I need to get dressed to go out."),
        ("Ele veste sempre roupas azuis.", "He always wears blue clothes."),
        ("Ela veste-se muito bem.", "She dresses very well."),
        ("Ajuda a criança a vestir a camisola.", "Help the child put on the sweater.")
    ],
    "respirar": [
        ("Respirar ar puro faz bem à saúde.", "Breathing fresh air is good for your health."),
        ("Respiro fundo para relaxar.", "I breathe deeply to relax."),
        ("Estava difícil respirar com tanto fumo.", "It was hard to breathe with so much smoke."),
        ("O mergulhador consegue respirar debaixo de água.", "The diver can breathe underwater."),
        ("Tenta respirar devagar.", "Try to breathe slowly.")
    ],
    "levantar": [
        ("Levanto-me cedo todos os dias.", "I get up early every day."),
        ("Podes levantar a caixa, por favor?", "Can you pick up the box, please?"),
        ("O sol levanta-se às seis da manhã.", "The sun rises at six in the morning."),
        ("Vou levantar dinheiro no banco.", "I'm going to withdraw money from the bank."),
        ("Cuidado ao levantar pesos.", "Be careful when lifting weights.")
    ],
    "deitar": [
        ("Vou deitar-me agora, boa noite.", "I'm going to lie down now, good night."),
        ("Ela deita o lixo fora.", "She throws the trash away."),
        ("Não te deites tarde hoje.", "Don't go to bed late today."),
        ("Onde posso deitar este papel?", "Where can I throw this paper?"),
        ("O gato deita-se no sofá.", "The cat lies on the sofa.")
    ],
    "antes": [
        ("Lava as mãos antes de comer.", "Wash your hands before eating."),
        ("Cheguei antes de ti.", "I arrived before you."),
        ("Ele faz exercício antes do trabalho.", "He exercises before work."),
        ("Telefona-me antes de saíres.", "Call me before you leave."),
        ("Antes era tudo diferente.", "Before, everything was different.")
    ],
    "depois": [
        ("Vamos ao cinema depois do jantar.", "Let's go to the cinema after dinner."),
        ("Depois de amanhã é feriado.", "The day after tomorrow is a holiday."),
        ("Vemo-nos depois!", "See you later!"),
        ("Eles chegaram depois da festa acabar.", "They arrived after the party finished."),
        ("Primeiro estudas, depois jogas.", "First you study, then you play.")
    ]
}

VERBS_DATA = [
    ("respirar", "Eu respiro o ar fresco da manhã.", "I breathe the fresh morning air."),
    ("vestir", "Ela veste um vestido novo hoje.", "She wears a new dress today."),
    ("lavar", "Nós lavamos o carro todos os domingos.", "We wash the car every Sunday."),
    ("despir", "Tu despes o casaco quando entras em casa.", "You take off your coat when you enter the house."),
    ("sentir", "Eu sinto falta do verão.", "I miss summer (feel lack of)."),
    ("sentar", "Vocês sentam-se na primeira fila.", "You sit in the first row."),
    ("levantar", "Ele levanta-se às 10 horas ao fim de semana.", "He gets up at 10 AM on the weekend."),
    ("deitar", "Nós deitamo-nos tarde no sábado.", "We go to bed late on Saturday."),
    ("resumir", "O aluno resume o texto perfeitamente.", "The student summarizes the text perfectly."),
    ("estimar", "Eu estimo muito a minha bicicleta antiga.", "I greatly value my old bicycle.")
]

def main():
    if not os.path.exists("extracted_words.json"):
        print("extracted_words.json not found.")
        return

    with open("extracted_words.json", "r") as f:
        words = json.load(f)

    # 1. Update source.md
    with open(SOURCE_FILE, "a", encoding="utf-8") as f:
        f.write("\n# Vocabulary Expansion: more_words_1.md\n\n")
        f.write("| Portugues | English | Notes |\n")
        f.write("| :---- | :---- | :---- |\n")
        for item in words:
            pt = item['pt']
            en = item['en']
            f.write(f"| {pt} | {en} | New Vocabulary |\n")
            if pt in EXPANSIONS:
                for exp_pt, exp_en in EXPANSIONS[pt]:
                    f.write(f"| {exp_pt} | {exp_en} | Expansion |\n")
            # For words without predefined expansion, we could do 1-2 generic ones or just leave them
            # Let's add some more generic ones for transport
            if pt in ["metro", "elétrico", "barco", "avião", "táxi", "bicicleta", "mota", "autocarro"]:
                f.write(f"| Vou de {pt} para a escola. | I go by {pt} to school. | Transport Expansion |\n")
                f.write(f"| Onde fica a paragem de {pt}? | Where is the {pt} stop? | Transport Expansion |\n")

    # 2. Update verb_phrases.json
    if os.path.exists(VERB_PHRASES_FILE):
        with open(VERB_PHRASES_FILE, "r", encoding="utf-8") as f:
            verb_data = json.load(f)
        
        for verb, pt, en in VERBS_DATA:
            verb_data.append({
                "verb": verb,
                "portuguese": pt,
                "english": en
            })
            
        with open(VERB_PHRASES_FILE, "w", encoding="utf-8") as f:
            json.dump(verb_data, f, indent=2, ensure_ascii=False)

    # 3. Update interrogatives.json (mostly adding more variations of existing ones)
    if os.path.exists(INTERROGATIVES_FILE):
        with open(INTERROGATIVES_FILE, "r", encoding="utf-8") as f:
            int_data = json.load(f)
            
        new_ints = [
            {"interrogative": "Quanto", "portuguese": "Quanto custa o bilhete de comboio?", "english": "How much does the train ticket cost?", "category": "how_much"},
            {"interrogative": "Quando", "portuguese": "Quando começa o verão?", "english": "When does summer start?", "category": "when"},
            {"interrogative": "Onde", "portuguese": "Onde estão os meus chinelos?", "english": "Where are my flip flops?", "category": "where"}
        ]
        
        int_data.extend(new_ints)
        
        with open(INTERROGATIVES_FILE, "w", encoding="utf-8") as f:
            json.dump(int_data, f, indent=2, ensure_ascii=False)

    print("Successfully processed massive expansion.")

if __name__ == "__main__":
    main()
