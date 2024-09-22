import random

class Fighter:
    def __init__(self, name, categories, strengths, weaknesses):
        self.name = name
        self.categories = categories  # Attack categories: list of strings
        self.strengths = strengths    # Resistance list (category numbers)
        self.weaknesses = weaknesses  # Weakness list (category numbers)
        self.health = 100             # Default health value
        self.buff = 1.0               # No buffs to start

    def display_info(self):
        print(f"Fighter: {self.name}")
        print(f"Health: {self.health}")
        print(f"Strengths: {self.strengths}")
        print(f"Weaknesses: {self.weaknesses}")
        print(f"Buff: {self.buff}\n")

# Function to generate random fighters
def create_random_fighter(name):
    categories = ['Category1', 'Category2', 'Category3', 'Category4']
    strengths = random.sample(range(1, 5), 2)  # Fighter is resistant to 2 out of 4 categories
    weaknesses = [i for i in range(1, 5) if i not in strengths]  # Weak in remaining categories
    return Fighter(name, categories, strengths, weaknesses)

# Example usage:
fighter = create_random_fighter("Be")
fighter.display_info()

import random

# Extending Fighter class for combat capabilities
class Fighter:
    def __init__(self, name, categories, strengths, weaknesses):
        self.name = name
        self.categories = categories
        self.strengths = strengths
        self.weaknesses = weaknesses
        self.health = 100
        self.buff = 1.0  # Buff factor to enhance damage or defense

    def take_damage(self, damage, category):
        # Modify damage based on strengths/weaknesses
        if category in self.strengths:
            damage = int(damage * 0.5)  # 50% resistance
        elif category in self.weaknesses:
            damage = int(damage * 1.5)  # 150% damage
        self.health -= damage
        print(f"{self.name} took {damage} damage! Health is now {self.health}.")

    def apply_buff(self, buff_amount):
        self.buff *= buff_amount
        print(f"{self.name} applied a buff! Buff is now {self.buff}.")

    def is_alive(self):
        return self.health > 0


# Define Michael and Be
michael = Fighter("Michael", ['Category1', 'Category2', 'Category3', 'Category4'], [], [])
be = create_random_fighter("Be")

# Define attacks and effects
attacks = {
    'Category1': {'attack1': 10, 'attack2': 15},
    'Category2': {'attack1': 20, 'attack2': 25},
    'Category3': {'attack1': 30, 'attack2': 35},
    'Category4': {'attack1': 40, 'attack2': 50}
}

# Basic game loop for turn-based combat
def battle():
    print("\nBattle Start! Michael vs Be\n")
    while michael.is_alive() and be.is_alive():
        # Player's turn
        print("\nMichael's turn:")
        print(f"Choose an attack category: {michael.categories}")
        category = input("Enter category (Category1, Category2, etc.): ")
        if category in attacks:
            chosen_attack = random.choice(list(attacks[category].items()))
            attack_name, damage = chosen_attack
            print(f"Michael uses {attack_name} dealing {damage} damage!")
            be.take_damage(damage, int(category[-1]))  # Passing category as a number
        else:
            print("Invalid category. Turn skipped.")

        if not be.is_alive():
            print("Be is defeated!")
            break

        # Be's turn
        print("\nBe's turn:")
        be_action = random.choice(["attack", "buff"])
        if be_action == "attack":
            # Be retaliates
            category = random.choice(be.categories)
            chosen_attack = random.choice(list(attacks[category].items()))
            attack_name, damage = chosen_attack
            print(f"Be uses {attack_name} dealing {damage} damage!")
            michael.take_damage(damage, int(category[-1]))  # Be attacks Michael
        elif be_action == "buff":
            be.apply_buff(1.2)
        
        if not michael.is_alive():
            print("Michael is defeated!")
            break

# Start the battle
battle()
