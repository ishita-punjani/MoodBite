"""Generate MoodBite demo data CSVs in data/.

Restaurant names are real Mumbai restaurants; menus, prices and mood tags are
ILLUSTRATIVE demo data, not the restaurants' actual menus.

Coordinates are written as the area (zone) centroid with coords_verified=false.
Run scripts/geocode.py afterwards to look them up on OpenStreetMap.

Usage:  python scripts/generate_dataset.py
"""

from __future__ import annotations

import csv
from pathlib import Path

DATA = Path(__file__).resolve().parent.parent / "data"

# ---------------------------------------------------------------------------
# Moods
# ---------------------------------------------------------------------------
MOODS = [
    ("happy", "Happy", "😄", "Feeling happy and cheerful: fun, colourful, crowd-pleasing food to share with friends."),
    ("stressed", "Stressed", "😩", "Feeling stressed: warm, soothing, familiar comfort food that is easy to eat."),
    ("sad", "Sad", "😢", "Feeling low: sweet treats and hearty comfort food that feels like a hug."),
    ("tired", "Tired", "😴", "Feeling tired: light, quick, easy-to-digest food and a caffeine pick-me-up."),
    ("celebratory", "Celebratory", "🥳", "Celebrating: rich, indulgent, festive dishes and platters worth sharing."),
    ("adventurous", "Adventurous", "🤠", "Feeling adventurous: bold, spicy, unusual or regional dishes you have not tried yet."),
    ("romantic", "Romantic", "💕", "Feeling romantic: elegant, delicate dishes and desserts for a date night."),
    ("energetic", "Energetic", "⚡", "Feeling energetic: fresh, protein-rich, light and healthy food to keep you going."),
]

# ---------------------------------------------------------------------------
# Zones (must match supabase/migrations/20261020000200_zones.sql)
# ---------------------------------------------------------------------------
ZONES = [
    ("z01", "Colaba", 18.9067, 72.8147),
    ("z02", "Fort", 18.9322, 72.8347),
    ("z03", "Churchgate", 18.9322, 72.8264),
    ("z04", "Girgaon", 18.9550, 72.8170),
    ("z05", "Tardeo", 18.9701, 72.8137),
    ("z06", "Byculla", 18.9790, 72.8330),
    ("z07", "Lower Parel", 18.9953, 72.8300),
    ("z08", "Worli", 19.0176, 72.8162),
    ("z09", "Dadar", 19.0178, 72.8478),
    ("z10", "Matunga", 19.0275, 72.8550),
    ("z11", "Mahim", 19.0410, 72.8410),
    ("z12", "Sion", 19.0390, 72.8619),
    ("z13", "Bandra West", 19.0596, 72.8295),
    ("z14", "Bandra East", 19.0600, 72.8500),
    ("z15", "Khar", 19.0700, 72.8370),
    ("z16", "Santacruz", 19.0810, 72.8420),
    ("z17", "Vile Parle", 19.0990, 72.8440),
    ("z18", "Juhu", 19.1075, 72.8263),
    ("z19", "Andheri West", 19.1364, 72.8296),
    ("z20", "Andheri East", 19.1136, 72.8697),
    ("z21", "Powai", 19.1176, 72.9060),
    ("z22", "Ghatkopar", 19.0860, 72.9081),
    ("z23", "Chembur", 19.0522, 72.9005),
    ("z24", "Goregaon", 19.1663, 72.8526),
    ("z25", "Malad", 19.1874, 72.8484),
    ("z26", "Borivali", 19.2307, 72.8567),
    ("z27", "Mulund", 19.1726, 72.9565),
]

# ---------------------------------------------------------------------------
# Dish library: key -> (name, description, base price at price level 2,
#                       is_veg, category, primary mood, [secondary moods])
# Secondary weights: first 0.7, second 0.5. Eggs count as non-veg.
# ---------------------------------------------------------------------------
D = {
    # Cafe / continental
    "club_sandwich": ("Chicken Club Sandwich", "Triple-decker with grilled chicken, egg, lettuce and fries", 280, False, "snack", "tired", ["happy"]),
    "veg_club_sandwich": ("Veg Club Sandwich", "Triple-decker with veggies, cheese and mint chutney, with fries", 240, True, "snack", "tired", ["stressed"]),
    "chicken_burger": ("Classic Chicken Burger", "Crumb-fried chicken patty, lettuce, mayo and fries", 300, False, "snack", "happy", ["sad"]),
    "fish_and_chips": ("Fish and Chips", "Beer-battered basa with chips and tartare sauce", 380, False, "main", "happy", ["sad"]),
    "grilled_chicken": ("Grilled Chicken with Herbed Rice", "Herb-marinated chicken breast, sauteed veggies and herbed rice", 420, False, "main", "energetic", ["romantic"]),
    "chicken_caesar": ("Grilled Chicken Caesar Salad", "Romaine, grilled chicken, parmesan and garlic croutons", 340, False, "salad", "energetic", ["tired"]),
    "quinoa_salad": ("Quinoa Garden Salad", "Quinoa, cucumber, cherry tomato, feta and lemon dressing", 300, True, "salad", "energetic", ["tired"]),
    "mushroom_soup": ("Cream of Mushroom Soup", "Velvety mushroom soup with garlic bread", 220, True, "starter", "stressed", ["tired", "sad"]),
    "penne_alfredo": ("Penne Alfredo", "Penne in a creamy parmesan white sauce", 360, True, "pizza_pasta", "romantic", ["sad"]),
    "spaghetti_arrabbiata": ("Spaghetti Arrabbiata", "Spaghetti in a spicy tomato and garlic sauce", 340, True, "pizza_pasta", "romantic", ["happy"]),
    "pesto_chicken_pasta": ("Pesto Chicken Pasta", "Fusilli with basil pesto, grilled chicken and pine nuts", 420, False, "pizza_pasta", "romantic", ["celebratory"]),
    "margherita": ("Margherita Pizza", "Thin crust with tomato, mozzarella and basil", 380, True, "pizza_pasta", "happy", ["romantic"]),
    "pepperoni_pizza": ("Chicken Pepperoni Pizza", "Thin crust loaded with chicken pepperoni and mozzarella", 460, False, "pizza_pasta", "happy", ["celebratory"]),
    "veg_lasagne": ("Vegetable Lasagne", "Layered pasta with roasted veggies, tomato and bechamel", 420, True, "pizza_pasta", "romantic", ["stressed"]),
    "mushroom_risotto": ("Wild Mushroom Risotto", "Creamy arborio rice with mushrooms and parmesan", 480, True, "main", "romantic", ["celebratory"]),
    "tiramisu": ("Tiramisu", "Coffee-soaked sponge layered with mascarpone cream", 320, True, "dessert", "romantic", ["celebratory"]),
    "choc_lava": ("Chocolate Lava Cake", "Warm chocolate cake with a molten centre and vanilla ice cream", 260, True, "dessert", "sad", ["romantic", "celebratory"]),
    "ny_cheesecake": ("New York Cheesecake", "Baked cream-cheese cake on a biscuit base", 300, True, "dessert", "celebratory", ["romantic", "happy"]),
    "cold_coffee": ("Cold Coffee with Ice Cream", "Thick blended coffee topped with vanilla ice cream", 180, True, "beverage", "tired", ["happy"]),
    "cappuccino": ("Cappuccino", "Espresso with steamed milk and foam", 160, True, "beverage", "tired", ["stressed"]),
    "hot_chocolate": ("Hot Chocolate", "Rich cocoa with steamed milk and whipped cream", 200, True, "beverage", "sad", ["stressed", "romantic"]),
    "lemon_iced_tea": ("Lemon Iced Tea", "Chilled black tea with lemon and mint", 150, True, "beverage", "energetic", ["happy"]),
    "fresh_lime_soda": ("Fresh Lime Soda", "Sweet or salted lime soda", 100, True, "beverage", "energetic", ["tired"]),
    "masala_chai": ("Masala Chai", "Milky tea brewed with ginger and cardamom", 60, True, "beverage", "stressed", ["tired"]),
    "loaded_nachos": ("Loaded Nachos", "Corn chips with beans, cheese sauce, salsa and jalapenos", 300, True, "starter", "happy", ["celebratory"]),
    "chilli_cheese_toast": ("Chilli Cheese Toast", "Toasted bread with melted cheese and green chilli", 180, True, "snack", "happy", ["stressed"]),
    "english_breakfast": ("Full English Breakfast", "Eggs your way, sausages, bacon, beans, hash brown and toast", 420, False, "breakfast", "energetic", ["tired"]),
    "masala_omelette": ("Masala Omelette with Toast", "Fluffy omelette with onion, tomato and chilli", 180, False, "breakfast", "energetic", ["tired"]),
    "pancakes": ("Pancakes with Maple Syrup", "Stack of fluffy pancakes with butter and maple syrup", 280, True, "breakfast", "happy", ["sad"]),
    "avocado_toast": ("Avocado Toast", "Sourdough with smashed avocado, chilli flakes and seeds", 360, True, "breakfast", "energetic", ["romantic"]),
    "shakshuka": ("Shakshuka", "Eggs poached in spiced tomato and pepper sauce with bread", 380, False, "breakfast", "adventurous", ["energetic"]),
    "cheese_fondue": ("Cheese Fondue for Two", "Swiss cheese fondue with bread, potatoes and veggies to dip", 900, True, "main", "romantic", ["celebratory"]),
    "chicken_sizzler": ("Chicken Steak Sizzler", "Grilled chicken steak on a sizzling plate with rice and veggies", 520, False, "main", "celebratory", ["romantic", "happy"]),
    "paneer_sizzler": ("Cottage Cheese Sizzler", "Grilled paneer steak with rice, fries and pepper sauce", 460, True, "main", "celebratory", ["happy"]),
    # Parsi / Irani
    "chicken_berry_pulao": ("Chicken Berry Pulao", "Fragrant rice with chicken, fried onions and tangy barberries", 450, False, "rice", "celebratory", ["adventurous"]),
    "veg_berry_pulao": ("Veg Berry Pulao", "Fragrant rice with veggies, paneer and barberries", 380, True, "rice", "celebratory", ["happy"]),
    "salli_boti": ("Mutton Salli Boti", "Sweet-sour mutton curry topped with crisp potato straws", 480, False, "main", "adventurous", ["celebratory"]),
    "mutton_dhansak": ("Mutton Dhansak", "Mutton in a lentil and vegetable gravy with brown rice", 450, False, "main", "stressed", ["sad"]),
    "patra_ni_machhi": ("Patra ni Machhi", "Pomfret steamed in banana leaf with green chutney", 480, False, "seafood", "adventurous", ["romantic"]),
    "akuri_toast": ("Akuri on Toast", "Parsi-style spiced scrambled eggs on buttered toast", 220, False, "breakfast", "tired", ["stressed"]),
    "caramel_custard": ("Caramel Custard", "Baked custard with a soft caramel top", 160, True, "dessert", "sad", ["happy"]),
    "raspberry_soda": ("Raspberry Soda", "Fizzy sweet raspberry soda", 80, True, "beverage", "happy", ["energetic"]),
    "bun_maska": ("Bun Maska", "Soft bun with a generous layer of butter", 60, True, "bakery", "tired", ["stressed"]),
    "brun_maska_chai": ("Brun Maska with Chai", "Crusty brun with butter and a cup of Irani chai", 90, True, "bakery", "stressed", ["tired"]),
    "kheema_pav": ("Kheema Pav", "Spiced minced mutton with buttered pav", 220, False, "main", "stressed", ["adventurous", "sad"]),
    "mawa_cake": ("Mawa Cake", "Dense cardamom-scented milk cake", 80, True, "bakery", "sad", ["happy"]),
    "apple_pie": ("Apple Pie", "Flaky pastry filled with cinnamon apples", 140, True, "bakery", "sad", ["romantic"]),
    "chicken_farcha": ("Chicken Farcha", "Parsi-style egg-battered fried chicken", 380, False, "starter", "happy", ["celebratory"]),
    "egg_kejriwal": ("Egg Kejriwal", "Cheese toast topped with a fried egg and green chilli", 200, False, "breakfast", "energetic", ["adventurous", "tired"]),
    # Mughlai / North Indian
    "chicken_biryani": ("Chicken Dum Biryani", "Slow-cooked rice and chicken with saffron and fried onions", 380, False, "rice", "celebratory", ["sad", "happy"]),
    "mutton_biryani": ("Mutton Biryani", "Layered rice and tender mutton cooked dum style", 460, False, "rice", "celebratory", ["adventurous", "happy"]),
    "veg_biryani": ("Veg Dum Biryani", "Rice layered with spiced vegetables and paneer", 300, True, "rice", "celebratory", ["happy"]),
    "butter_chicken": ("Butter Chicken", "Tandoori chicken in a buttery tomato gravy", 420, False, "main", "sad", ["celebratory", "stressed"]),
    "dal_makhani": ("Dal Makhani", "Black lentils slow-cooked with butter and cream", 320, True, "main", "stressed", ["sad"]),
    "paneer_tikka": ("Paneer Tikka", "Chargrilled paneer cubes marinated in spiced yoghurt", 320, True, "starter", "happy", ["celebratory", "energetic"]),
    "chicken_tikka": ("Chicken Tikka", "Boneless chicken chargrilled in the tandoor", 360, False, "starter", "energetic", ["happy"]),
    "seekh_kebab": ("Mutton Seekh Kebab", "Minced mutton skewers with mint chutney", 380, False, "starter", "celebratory", ["adventurous", "happy"]),
    "bheja_fry": ("Bheja Fry", "Goat brain tossed with onion, tomato and spices", 320, False, "main", "adventurous", []),
    "nalli_nihari": ("Nalli Nihari", "Slow-cooked mutton shank stew, best with khamiri roti", 480, False, "main", "adventurous", ["stressed"]),
    "chicken_baida_roti": ("Chicken Baida Roti", "Flaky roti stuffed with spiced chicken mince and egg", 220, False, "street_food", "adventurous", ["happy"]),
    "chicken_tikka_roll": ("Chicken Tikka Roll", "Chicken tikka wrapped in a rumali roti with onions", 180, False, "street_food", "happy", ["energetic", "tired"]),
    "paneer_kathi_roll": ("Paneer Kathi Roll", "Spiced paneer wrapped in a flaky paratha", 160, True, "street_food", "happy", ["tired"]),
    "butter_naan": ("Butter Naan", "Tandoor-baked naan brushed with butter", 70, True, "bread", "stressed", ["happy"]),
    "garlic_naan": ("Garlic Naan", "Naan topped with garlic and coriander", 90, True, "bread", "happy", ["stressed"]),
    "raan": ("Raan Masaledar", "Whole leg of lamb marinated overnight and roasted (serves 2-3)", 1100, False, "main", "celebratory", ["romantic"]),
    "paneer_butter_masala": ("Paneer Butter Masala", "Paneer in a rich tomato and cashew gravy", 340, True, "main", "sad", ["celebratory"]),
    "malai_kulfi": ("Malai Kulfi", "Traditional slow-set milk ice cream with pistachio", 140, True, "dessert", "happy", ["romantic"]),
    "phirni": ("Phirni", "Chilled ground-rice pudding with cardamom, set in clay pots", 140, True, "dessert", "romantic", ["sad"]),
    "shahi_tukda": ("Shahi Tukda", "Fried bread soaked in syrup and topped with rabdi", 180, True, "dessert", "celebratory", ["sad"]),
    "malpua_rabdi": ("Malpua with Rabdi", "Sweet fried pancakes with thickened milk", 200, True, "dessert", "celebratory", ["sad"]),
    "chole_bhature": ("Chole Bhature", "Spicy chickpea curry with fluffy fried bhature", 200, True, "main", "happy", ["stressed"]),
    "puri_bhaji": ("Puri Bhaji", "Puffed puris with spiced potato bhaji", 140, True, "main", "stressed", ["happy"]),
    "aloo_paratha": ("Aloo Paratha with Curd", "Potato-stuffed paratha with butter, curd and pickle", 150, True, "breakfast", "stressed", ["tired"]),
    "sweet_lassi": ("Sweet Lassi", "Thick chilled yoghurt drink", 100, True, "beverage", "energetic", ["happy"]),
    "mango_lassi": ("Mango Lassi", "Yoghurt blended with Alphonso mango", 130, True, "beverage", "happy", ["romantic"]),
    "dal_khichdi": ("Dal Khichdi", "Soft rice and moong dal with ghee and papad", 220, True, "main", "stressed", ["tired", "sad"]),
    "rajma_chawal": ("Rajma Chawal", "Kidney bean curry with steamed rice", 220, True, "main", "sad", ["stressed"]),
    "tandoori_chicken": ("Tandoori Chicken (Half)", "Classic chargrilled chicken with mint chutney", 380, False, "starter", "celebratory", ["energetic", "happy"]),
    "chicken_changezi": ("Chicken Changezi", "Chicken in a rich, smoky Old Delhi style gravy", 420, False, "main", "adventurous", ["celebratory"]),
    "galouti_kebab": ("Galouti Kebab", "Melt-in-the-mouth mutton kebabs on saffron sheermal", 460, False, "starter", "romantic", ["celebratory", "happy"]),
    "dal_pakwan": ("Dal Pakwan", "Sindhi breakfast of crisp pakwan with chana dal", 160, True, "breakfast", "adventurous", ["happy"]),
    "ragda_pattice": ("Ragda Pattice", "Potato patties in white pea curry with chutneys", 120, True, "street_food", "happy", ["adventurous"]),
    "kanda_bhaji": ("Kanda Bhaji with Chutneys", "Crisp onion fritters with three chutneys", 180, True, "starter", "happy", ["stressed"]),
    "tamatar_shorba": ("Tamatar Shorba", "Spiced tomato broth with a hint of cumin", 180, True, "starter", "stressed", ["tired"]),
    "jackfruit_biryani": ("Kathal Biryani", "Dum biryani made with spiced raw jackfruit", 420, True, "rice", "adventurous", ["celebratory"]),
    "laal_maas": ("Laal Maas", "Fiery Rajasthani mutton curry with red chillies", 520, False, "main", "adventurous", ["celebratory"]),
    "goan_sausage_pao": ("Goan Sausage Pao", "Spicy chorizo-style sausage masala with soft pao", 320, False, "main", "adventurous", ["happy"]),
    "malai_kofta": ("Malai Kofta", "Paneer and potato dumplings in a creamy gravy", 340, True, "main", "romantic", ["sad"]),
    "prawn_balchao": ("Prawn Balchao", "Tangy, spicy Goan prawn pickle-curry", 480, False, "seafood", "adventurous", ["celebratory"]),
    # Street food
    "pav_bhaji": ("Pav Bhaji", "Buttery mashed vegetable curry with toasted pav", 160, True, "street_food", "happy", ["stressed", "celebratory"]),
    "cheese_pav_bhaji": ("Cheese Pav Bhaji", "Pav bhaji topped with grated cheese", 200, True, "street_food", "happy", ["sad"]),
    "vada_pav": ("Vada Pav", "Spiced potato fritter in pav with garlic chutney", 30, True, "street_food", "energetic", ["happy", "tired"]),
    "pani_puri": ("Pani Puri", "Crisp puris with tangy mint water and potato", 60, True, "street_food", "happy", ["adventurous"]),
    "sev_puri": ("Sev Puri", "Flat puris topped with potato, chutneys and sev", 80, True, "street_food", "happy", ["energetic"]),
    "dahi_puri": ("Dahi Puri", "Puris filled with potato, sweet curd and chutneys", 90, True, "street_food", "happy", ["stressed"]),
    "bhel_puri": ("Bhel Puri", "Puffed rice tossed with onion, chutneys and sev", 70, True, "street_food", "energetic", ["happy"]),
    "samosa_chaat": ("Samosa Chaat", "Crushed samosa with chole, curd and chutneys", 90, True, "street_food", "happy", ["sad"]),
    "veg_frankie": ("Veg Frankie", "Spiced potato roll with tangy masala and onions", 80, True, "street_food", "happy", ["tired"]),
    "tawa_pulao": ("Tawa Pulao", "Rice tossed with pav bhaji masala and veggies on the tawa", 160, True, "rice", "adventurous", ["happy"]),
    "bombay_sandwich": ("Bombay Masala Sandwich", "Grilled sandwich with potato, veggies and green chutney", 90, True, "snack", "tired", ["happy"]),
    "schezwan_vada_pav": ("Schezwan Cheese Vada Pav", "Vada pav with schezwan chutney and cheese", 60, True, "street_food", "adventurous", ["happy"]),
    "cheese_vada_pav": ("Cheese Burst Vada Pav", "Vada pav with a molten cheese centre", 60, True, "street_food", "happy", ["sad"]),
    "samosa_pav": ("Samosa Pav", "Punjabi samosa in pav with chutneys", 40, True, "street_food", "stressed", ["happy"]),
    # Gujarati
    "panki": ("Panki", "Thin rice-batter pancakes steamed in banana leaf", 180, True, "snack", "adventurous", ["tired"]),
    "kadhi_khichdi": ("Kadhi Khichdi", "Soft khichdi with sweet-tangy Gujarati kadhi", 220, True, "main", "stressed", ["sad", "tired"]),
    "khaman_dhokla": ("Khaman Dhokla", "Steamed, spongy gram-flour cake with chutney", 120, True, "snack", "energetic", ["happy"]),
    "gujarati_thali": ("Gujarati Thali (Unlimited)", "Farsan, shaak, dal, kadhi, rotli, rice and sweet", 450, True, "thali", "celebratory", ["stressed"]),
    "handvo": ("Handvo", "Savoury baked lentil and rice cake with sesame", 160, True, "snack", "energetic", ["tired"]),
    "undhiyu_puri": ("Undhiyu with Puri", "Winter mixed-vegetable speciality with puris", 320, True, "main", "adventurous", ["celebratory"]),
    "kesar_shrikhand": ("Kesar Shrikhand", "Strained yoghurt sweetened with saffron and cardamom", 120, True, "dessert", "happy", ["celebratory"]),
    "aamras_puri": ("Aamras Puri", "Fresh Alphonso mango pulp with hot puris", 260, True, "main", "happy", ["celebratory"]),
    "methi_thepla": ("Methi Thepla with Chunda", "Fenugreek flatbreads with sweet mango pickle", 140, True, "breakfast", "tired", ["energetic"]),
    "masala_chaas": ("Masala Chaas", "Spiced buttermilk with roasted cumin", 60, True, "beverage", "energetic", ["tired"]),
    "dal_dhokli": ("Dal Dhokli", "Wheat dumplings simmered in sweet-tangy dal", 200, True, "main", "stressed", ["sad"]),
    # South Indian
    "masala_dosa": ("Masala Dosa", "Crisp dosa with potato masala, sambar and chutney", 120, True, "south_indian", "happy", ["tired", "energetic"]),
    "mysore_dosa": ("Mysore Masala Dosa", "Dosa smeared with spicy red chutney and potato masala", 140, True, "south_indian", "adventurous", ["happy"]),
    "idli_sambar": ("Idli Sambar", "Steamed rice cakes with sambar and coconut chutney", 80, True, "south_indian", "tired", ["stressed", "energetic"]),
    "medu_vada": ("Medu Vada", "Crisp lentil doughnuts with sambar", 90, True, "south_indian", "energetic", ["tired"]),
    "rava_upma": ("Rava Upma", "Semolina cooked with mustard, curry leaves and veggies", 90, True, "breakfast", "tired", ["stressed"]),
    "filter_coffee": ("Filter Coffee", "Strong South Indian coffee with frothy milk", 50, True, "beverage", "tired", ["stressed", "energetic"]),
    "ven_pongal": ("Ven Pongal", "Rice and moong dal with ghee, pepper and cashews", 110, True, "south_indian", "stressed", ["tired"]),
    "curd_rice": ("Curd Rice", "Cool tempered curd rice with pomegranate", 120, True, "rice", "stressed", ["tired", "sad"]),
    "rasam_rice": ("Rasam Rice", "Peppery tomato rasam with steamed rice", 130, True, "rice", "sad", ["stressed"]),
    "neer_dosa": ("Neer Dosa", "Soft, lacy rice crepes with coconut chutney", 120, True, "south_indian", "tired", ["energetic"]),
    "onion_uttapam": ("Onion Uttapam", "Thick rice pancake topped with onion and chilli", 130, True, "south_indian", "energetic", ["happy"]),
    "appam_stew": ("Appam with Veg Stew", "Lacy appams with a mild coconut milk stew", 220, True, "south_indian", "romantic", ["stressed"]),
    "bisi_bele_bath": ("Bisi Bele Bath", "Spiced rice, lentils and vegetables Karnataka style", 150, True, "rice", "stressed", ["adventurous"]),
    "rava_kesari": ("Rava Kesari", "Semolina halwa with ghee, saffron and cashews", 80, True, "dessert", "happy", ["sad"]),
    "semiya_payasam": ("Semiya Payasam", "Vermicelli cooked in sweetened milk with cardamom", 100, True, "dessert", "celebratory", ["sad"]),
    "butter_masala_dosa": ("Butter Masala Dosa", "Masala dosa roasted with a generous dollop of butter", 150, True, "south_indian", "sad", ["happy"]),
    # Maharashtrian
    "misal_pav": ("Misal Pav", "Fiery sprouted-moth curry topped with farsan, with pav", 120, True, "street_food", "adventurous", ["energetic"]),
    "sabudana_khichdi": ("Sabudana Khichdi", "Sago pearls with peanuts, potato and green chilli", 100, True, "breakfast", "tired", ["stressed", "energetic"]),
    "sabudana_vada": ("Sabudana Vada", "Crisp sago and peanut fritters with curd", 100, True, "snack", "energetic", ["happy"]),
    "thalipeeth": ("Thalipeeth", "Multigrain flatbread with white butter", 120, True, "breakfast", "energetic", ["adventurous"]),
    "kanda_poha": ("Kanda Poha", "Flattened rice with onion, peanuts and lemon", 70, True, "breakfast", "tired", ["stressed"]),
    "kothimbir_vadi": ("Kothimbir Vadi", "Crisp coriander and gram-flour squares", 110, True, "starter", "adventurous", ["happy"]),
    "puran_poli": ("Puran Poli", "Sweet lentil-stuffed flatbread with ghee", 120, True, "dessert", "celebratory", ["sad", "happy"]),
    "piyush": ("Piyush", "Creamy shrikhand and buttermilk drink", 80, True, "beverage", "energetic", ["happy"]),
    "sol_kadhi": ("Sol Kadhi", "Cooling kokum and coconut milk drink", 80, True, "beverage", "tired", ["energetic"]),
    "batata_vada": ("Batata Vada", "Spiced potato fritters with green chutney", 50, True, "street_food", "happy", ["stressed"]),
    "maharashtrian_thali": ("Maharashtrian Veg Thali", "Bhaji, usal, varan-bhaat, chapati, koshimbir and sweet", 280, True, "thali", "stressed", ["celebratory"]),
    "zunka_bhakri": ("Zunka Bhakri", "Spiced gram-flour scramble with jowar bhakri", 130, True, "main", "adventurous", ["stressed"]),
    "ukadiche_modak": ("Ukadiche Modak", "Steamed rice dumplings with coconut-jaggery filling", 150, True, "dessert", "celebratory", ["happy"]),
    "amrakhand": ("Amrakhand", "Mango-flavoured shrikhand", 120, True, "dessert", "happy", ["romantic"]),
    "kokum_sharbat": ("Kokum Sharbat", "Sweet-sour kokum cooler", 60, True, "beverage", "energetic", ["tired"]),
    # Seafood / Malvani / Mangalorean / Goan
    "bombil_fry": ("Bombil Fry", "Bombay duck coated in semolina and fried crisp", 280, False, "seafood", "adventurous", ["happy"]),
    "surmai_thali": ("Surmai Thali", "Fried surmai, fish curry, rice, bhakri and sol kadhi", 450, False, "thali", "celebratory", ["adventurous"]),
    "pomfret_fry": ("Rava Pomfret Fry", "Whole pomfret in spiced semolina crust", 520, False, "seafood", "celebratory", ["romantic", "happy"]),
    "prawns_koliwada": ("Prawns Koliwada", "Crisp batter-fried prawns Koli style", 420, False, "seafood", "happy", ["adventurous"]),
    "butter_garlic_crab": ("Butter Garlic Crab", "Whole crab tossed in butter, garlic and pepper", 1100, False, "seafood", "celebratory", ["adventurous", "romantic"]),
    "prawn_gassi": ("Prawn Gassi with Neer Dosa", "Mangalorean coconut prawn curry with neer dosa", 480, False, "seafood", "adventurous", ["romantic"]),
    "chicken_ghee_roast": ("Chicken Ghee Roast", "Mangalorean chicken roasted in ghee and red chillies", 420, False, "main", "adventurous", ["celebratory"]),
    "fish_curry_rice": ("Fish Curry Rice", "Homestyle coconut fish curry with steamed rice", 320, False, "seafood", "stressed", ["sad", "tired"]),
    "malvani_prawn_curry": ("Malvani Prawn Curry", "Prawns in a spicy coconut Malvani masala", 420, False, "seafood", "adventurous", ["stressed"]),
    "tisrya_masala": ("Tisrya Masala", "Clams cooked with coconut and Malvani spices", 380, False, "seafood", "adventurous", []),
    "kombdi_vade": ("Kombdi Vade", "Malvani chicken curry with puffed rice-flour vade", 380, False, "main", "adventurous", ["celebratory", "stressed"]),
    "grilled_basa": ("Grilled Basa with Lemon Butter", "Grilled fish fillet with lemon butter sauce and greens", 460, False, "seafood", "energetic", ["romantic", "tired"]),
    "goan_prawn_curry": ("Goan Prawn Curry Rice", "Prawns in a tangy coconut curry with rice", 450, False, "seafood", "romantic", ["adventurous", "stressed"]),
    "pork_vindaloo": ("Pork Vindaloo", "Goan pork curry with vinegar and Kashmiri chillies", 450, False, "main", "adventurous", ["celebratory"]),
    "chicken_xacuti": ("Chicken Xacuti", "Chicken in roasted coconut and poppy seed masala", 420, False, "main", "adventurous", ["romantic"]),
    "mushroom_xacuti": ("Mushroom Xacuti", "Mushrooms in roasted coconut xacuti masala", 320, True, "main", "adventurous", ["romantic"]),
    "bebinca": ("Bebinca", "Layered Goan dessert of coconut milk, egg yolk and ghee", 220, False, "dessert", "celebratory", ["romantic"]),
    "prawn_rava_fry": ("Prawn Rava Fry", "Semolina-crusted pan-fried prawns", 450, False, "seafood", "energetic", ["happy"]),
    "kori_rotti": ("Kori Rotti", "Mangalorean chicken curry poured over crisp rice wafers", 400, False, "main", "adventurous", ["celebratory", "stressed"]),
    "tandoori_prawns": ("Tandoori Prawns", "Jumbo prawns marinated and chargrilled", 520, False, "seafood", "celebratory", ["energetic", "happy"]),
    # Chinese / Asian / Burmese
    "hakka_noodles": ("Veg Hakka Noodles", "Wok-tossed noodles with crunchy vegetables", 260, True, "rice", "happy", ["tired"]),
    "schezwan_fried_rice": ("Schezwan Fried Rice", "Fried rice in fiery schezwan sauce", 280, True, "rice", "adventurous", ["happy"]),
    "chilli_chicken": ("Chilli Chicken", "Crisp chicken tossed with chillies, onion and peppers", 340, False, "starter", "happy", ["adventurous"]),
    "veg_manchurian": ("Veg Manchurian Gravy", "Vegetable balls in a soy-garlic gravy", 280, True, "main", "happy", ["stressed"]),
    "hot_sour_soup": ("Hot and Sour Soup", "Peppery, tangy vegetable soup", 200, True, "starter", "stressed", ["sad"]),
    "chicken_manchow": ("Chicken Manchow Soup", "Spicy chicken soup with crisp fried noodles", 220, False, "starter", "stressed", ["tired"]),
    "veg_dim_sum": ("Crystal Veg Dim Sum", "Translucent dumplings filled with vegetables", 320, True, "starter", "romantic", ["adventurous"]),
    "prawn_har_gow": ("Prawn Har Gow", "Steamed prawn dumplings", 420, False, "starter", "romantic", ["celebratory"]),
    "kung_pao_chicken": ("Kung Pao Chicken", "Chicken with peanuts and dried chillies", 420, False, "main", "adventurous", ["energetic", "happy"]),
    "roast_duck_pancakes": ("Roast Duck Pancakes", "Crisp roast duck with pancakes, cucumber and hoisin", 950, False, "main", "celebratory", ["romantic"]),
    "garlic_greens": ("Stir-fried Greens in Garlic", "Seasonal greens tossed with garlic", 280, True, "main", "energetic", ["tired"]),
    "chilli_paneer": ("Chilli Paneer Dry", "Paneer tossed with chillies, peppers and soy", 300, True, "starter", "happy", ["adventurous"]),
    "darsaan": ("Honey Noodles with Ice Cream", "Crisp noodles in honey and sesame with vanilla ice cream", 220, True, "dessert", "happy", ["romantic"]),
    "veg_khow_suey": ("Veg Khow Suey", "Coconut curry noodles with crunchy toppings", 450, True, "rice", "adventurous", ["stressed", "romantic"]),
    "chicken_khow_suey": ("Chicken Khow Suey", "Coconut curry noodles with chicken and crunchy toppings", 500, False, "rice", "adventurous", ["stressed"]),
    "tea_leaf_salad": ("Tea Leaf Salad", "Burmese fermented tea leaves with crunchy beans and nuts", 340, True, "salad", "adventurous", ["energetic"]),
    "samosa_soup": ("Burmese Samosa Soup", "Samosas dunked in a tangy lentil broth", 300, True, "starter", "adventurous", ["stressed"]),
    "mohinga": ("Mohinga", "Burmese fish and rice noodle soup", 380, False, "rice", "adventurous", ["tired"]),
    "avocado_ice_cream": ("Avocado Ice Cream", "Creamy avocado ice cream with honey", 260, True, "dessert", "romantic", ["adventurous"]),
    "thai_green_curry": ("Thai Green Curry with Rice", "Vegetables in green curry with jasmine rice", 420, True, "main", "romantic", ["adventurous"]),
    "american_chopsuey": ("American Chopsuey", "Crispy noodles with sweet-sour chicken sauce and a fried egg", 320, False, "rice", "happy", ["sad", "stressed"]),
    # Desserts, bakery, juices
    "tender_coconut_ic": ("Tender Coconut Ice Cream", "Fresh tender coconut ice cream", 120, True, "dessert", "happy", ["romantic", "energetic"]),
    "sitaphal_ic": ("Sitaphal Ice Cream", "Custard apple ice cream with real fruit", 120, True, "dessert", "happy", ["adventurous"]),
    "roasted_almond_ic": ("Roasted Almond Ice Cream", "Creamy ice cream with roasted almonds", 120, True, "dessert", "sad", ["happy"]),
    "mango_ic": ("Alphonso Mango Ice Cream", "Ice cream made with Alphonso mango", 140, True, "dessert", "celebratory", ["happy"]),
    "jamun_ic": ("Kala Jamun Ice Cream", "Tangy jamun fruit ice cream", 130, True, "dessert", "adventurous", ["happy"]),
    "chikoo_ic": ("Chikoo Ice Cream", "Sapota ice cream", 120, True, "dessert", "stressed", ["happy"]),
    "choc_truffle": ("Chocolate Truffle Pastry", "Layers of chocolate sponge and ganache", 180, True, "dessert", "sad", ["celebratory"]),
    "red_velvet": ("Red Velvet Pastry", "Red velvet sponge with cream-cheese frosting", 200, True, "dessert", "romantic", ["celebratory"]),
    "walnut_brownie": ("Walnut Brownie", "Fudgy chocolate brownie with walnuts", 150, True, "dessert", "sad", ["happy"]),
    "butter_croissant": ("Butter Croissant", "Flaky all-butter croissant", 160, True, "bakery", "tired", ["romantic"]),
    "blueberry_cheesecake": ("Blueberry Cheesecake", "Baked cheesecake with blueberry compote", 280, True, "dessert", "romantic", ["celebratory"]),
    "macaron_box": ("Macaron Box (6)", "Six assorted French macarons", 480, True, "dessert", "romantic", ["celebratory"]),
    "choc_eclair": ("Chocolate Eclair", "Choux pastry with cream and chocolate glaze", 160, True, "dessert", "happy", ["sad"]),
    "glazed_doughnut": ("Glazed Doughnut", "Soft ring doughnut with sugar glaze", 120, True, "bakery", "happy", ["sad"]),
    "gulab_jamun": ("Gulab Jamun (2 pcs)", "Warm milk dumplings in rose syrup", 80, True, "dessert", "sad", ["celebratory"]),
    "rasmalai": ("Rasmalai (2 pcs)", "Soft paneer discs in saffron milk", 120, True, "dessert", "celebratory", ["romantic"]),
    "kaju_katli": ("Kaju Katli (250 g)", "Cashew fudge with silver leaf", 350, True, "dessert", "celebratory", ["happy"]),
    "jalebi_rabdi": ("Jalebi with Rabdi", "Hot crisp jalebis with chilled rabdi", 160, True, "dessert", "happy", ["celebratory"]),
    "punjabi_samosa": ("Punjabi Samosa", "Crisp pastry with spiced potato and peas", 40, True, "snack", "happy", ["stressed"]),
    "khasta_kachori": ("Khasta Kachori", "Flaky lentil-stuffed kachori with chutneys", 50, True, "snack", "adventurous", ["happy"]),
    "sitaphal_cream": ("Sitaphal Cream", "Custard apple pulp folded into fresh cream", 220, True, "dessert", "romantic", ["happy"]),
    "mango_cream": ("Mango Cream", "Alphonso mango chunks in fresh cream", 240, True, "dessert", "celebratory", ["romantic"]),
    "strawberry_cream": ("Strawberry Cream", "Fresh strawberries with cream", 220, True, "dessert", "romantic", ["happy"]),
    "watermelon_juice": ("Watermelon Juice", "Fresh watermelon juice, no added sugar", 120, True, "beverage", "energetic", ["tired"]),
    "mosambi_juice": ("Mosambi Juice", "Fresh sweet-lime juice", 110, True, "beverage", "energetic", ["tired"]),
    "fruit_salad_cream": ("Fruit Salad with Cream", "Seasonal fruits with fresh cream", 200, True, "dessert", "energetic", ["happy"]),
    "royal_falooda": ("Royal Falooda", "Rose milk with vermicelli, basil seeds and ice cream", 200, True, "dessert", "happy", ["celebratory"]),
    "chicken_puff": ("Chicken Puff", "Flaky puff pastry with spiced chicken", 60, False, "bakery", "happy", ["tired"]),
    "veg_puff": ("Veg Puff", "Flaky puff pastry with spiced vegetables", 40, True, "bakery", "tired", ["happy"]),
    "mutton_samosa": ("Mutton Samosa", "Thin-crust samosas with spiced mutton mince", 60, False, "snack", "adventurous", ["happy"]),
    "cinnamon_roll": ("Cinnamon Roll", "Soft roll swirled with cinnamon sugar and glaze", 160, True, "bakery", "stressed", ["romantic"]),
    # Barbeque
    "bbq_veg_platter": ("Veg Barbeque Platter", "Paneer, mushroom, pineapple and potato skewers", 650, True, "starter", "celebratory", ["happy"]),
    "bbq_nonveg_platter": ("Non-veg Barbeque Platter", "Chicken, fish, prawn and mutton skewers", 850, False, "starter", "celebratory", ["energetic", "happy"]),
    "cajun_potatoes": ("Cajun Spiced Potatoes", "Crisp baby potatoes with cajun spice and mayo", 220, True, "starter", "happy", ["sad"]),
    "grilled_pineapple": ("Grilled Pineapple", "Cinnamon-dusted pineapple from the grill", 180, True, "dessert", "romantic", ["happy"]),
    # Non-veg additions (comfort food, soups, rolls, light egg and chicken dishes)
    "chicken_sweet_corn_soup": ("Chicken Sweet Corn Soup", "Silky corn soup with shredded chicken and egg ribbons", 200, False, "starter", "stressed", ["tired", "sad"]),
    "chicken_noodle_soup": ("Chicken Noodle Soup", "Clear chicken broth with noodles and vegetables", 240, False, "starter", "stressed", ["tired", "sad"]),
    "egg_bhurji_pav": ("Egg Bhurji Pav", "Spiced scrambled eggs with buttered pav", 160, False, "breakfast", "tired", ["stressed"]),
    "egg_roll": ("Egg Roll", "Egg-fried paratha wrapped around onions and green chutney", 120, False, "street_food", "tired", ["happy"]),
    "grilled_chicken_sandwich": ("Grilled Chicken Sandwich", "Grilled chicken, cheese and lettuce in toasted brown bread", 260, False, "snack", "tired", ["energetic"]),
    "chicken_stew_appam": ("Chicken Stew with Appam", "Mild coconut chicken stew with lacy rice appams", 380, False, "main", "stressed", ["sad", "tired"]),
    "mutton_paya": ("Mutton Paya Soup", "Slow-simmered trotter broth, warming and rich, with roti", 280, False, "starter", "sad", ["stressed"]),
    "chicken_curry_rice": ("Chicken Curry Rice", "Homestyle chicken curry with steamed rice", 300, False, "rice", "stressed", ["sad"]),
    "chicken_frankie": ("Chicken Frankie", "Spiced chicken and onion wrapped in a soft egg roti", 140, False, "street_food", "happy", ["energetic"]),
    "bbq_chicken_wings": ("Smoky BBQ Chicken Wings", "Chargrilled wings glazed with a smoky barbeque sauce", 380, False, "starter", "happy", ["celebratory"]),
}

# ---------------------------------------------------------------------------
# Restaurants: (name, area, address, cuisines, price_level, [dish keys])
# Area must be a zone name above. Addresses are approximate, for display only.
# ---------------------------------------------------------------------------
RESTAURANTS = [
    ("Leopold Cafe", "Colaba", "Colaba Causeway, Colaba, Mumbai", ["cafe", "continental"], 3,
     ["fish_and_chips", "chicken_burger", "veg_club_sandwich", "chilli_cheese_toast", "chicken_sizzler", "cold_coffee", "fresh_lime_soda"]),
    ("Bademiya", "Colaba", "Tulloch Road, behind Taj Mahal Palace, Colaba, Mumbai", ["mughlai", "street food"], 2,
     ["seekh_kebab", "chicken_tikka", "chicken_baida_roti", "chicken_tikka_roll", "paneer_tikka", "paneer_kathi_roll"]),
    ("Kailash Parbat", "Colaba", "Colaba Causeway, Colaba, Mumbai", ["street food", "sindhi", "sweets"], 2,
     ["pani_puri", "ragda_pattice", "samosa_chaat", "dal_pakwan", "chole_bhature", "malai_kulfi", "sweet_lassi"]),
    ("Ling's Pavilion", "Colaba", "Mahakavi Bhushan Marg, Colaba, Mumbai", ["chinese"], 3,
     ["veg_dim_sum", "prawn_har_gow", "kung_pao_chicken", "roast_duck_pancakes", "hot_sour_soup", "garlic_greens", "darsaan"]),
    ("Theobroma", "Colaba", "Colaba Causeway, Colaba, Mumbai", ["desserts", "bakery", "cafe"], 2,
     ["walnut_brownie", "choc_truffle", "red_velvet", "butter_croissant", "blueberry_cheesecake", "cappuccino", "hot_chocolate"]),
    ("Britannia & Co.", "Fort", "Wakefield House, Ballard Estate, Fort, Mumbai", ["parsi", "irani"], 2,
     ["chicken_berry_pulao", "veg_berry_pulao", "salli_boti", "mutton_dhansak", "patra_ni_machhi", "caramel_custard", "raspberry_soda"]),
    ("Yazdani Bakery", "Fort", "Cawasji Patel Street, Fort, Mumbai", ["bakery", "irani"], 1,
     ["bun_maska", "brun_maska_chai", "mawa_cake", "apple_pie", "veg_puff", "chicken_puff"]),
    ("Trishna", "Fort", "Sai Baba Marg, Kala Ghoda, Fort, Mumbai", ["seafood"], 4,
     ["butter_garlic_crab", "prawns_koliwada", "pomfret_fry", "grilled_basa", "goan_prawn_curry", "fish_curry_rice", "phirni"]),
    ("Mahesh Lunch Home", "Fort", "Cawasji Patel Street, Fort, Mumbai", ["seafood", "mangalorean"], 3,
     ["prawn_gassi", "chicken_ghee_roast", "kori_rotti", "bombil_fry", "neer_dosa", "sol_kadhi", "tandoori_prawns"]),
    ("Khyber", "Fort", "Mahatma Gandhi Road, Kala Ghoda, Fort, Mumbai", ["north indian", "mughlai"], 4,
     ["raan", "galouti_kebab", "butter_chicken", "dal_makhani", "paneer_butter_masala", "garlic_naan", "shahi_tukda", "phirni"]),
    ("Burma Burma", "Fort", "Kala Ghoda, Fort, Mumbai", ["burmese", "asian"], 3,
     ["veg_khow_suey", "tea_leaf_salad", "samosa_soup", "veg_dim_sum", "avocado_ice_cream", "lemon_iced_tea"]),
    ("Pancham Puriwala", "Fort", "Opposite CSMT, Fort, Mumbai", ["north indian", "street food"], 1,
     ["puri_bhaji", "chole_bhature", "aloo_paratha", "dal_khichdi", "sweet_lassi", "gulab_jamun"]),
    ("Pizza By The Bay", "Churchgate", "Marine Drive, Churchgate, Mumbai", ["italian"], 3,
     ["margherita", "pepperoni_pizza", "penne_alfredo", "spaghetti_arrabbiata", "veg_lasagne", "tiramisu", "loaded_nachos", "lemon_iced_tea"]),
    ("Hotel Status", "Churchgate", "Nariman Point, Churchgate, Mumbai", ["south indian", "north indian"], 2,
     ["masala_dosa", "idli_sambar", "onion_uttapam", "pav_bhaji", "dal_khichdi", "filter_coffee", "rasam_rice"]),
    ("Kyani & Co.", "Girgaon", "Jagannath Shankarseth Marg, Dhobi Talao, Mumbai", ["irani", "bakery"], 1,
     ["bun_maska", "akuri_toast", "kheema_pav", "egg_kejriwal", "mawa_cake", "masala_chai", "raspberry_soda"]),
    ("Shree Thaker Bhojanalay", "Girgaon", "Kalbadevi Road, Mumbai", ["gujarati", "thali"], 2,
     ["gujarati_thali", "kadhi_khichdi", "aamras_puri", "kesar_shrikhand", "khaman_dhokla", "masala_chaas"]),
    ("Soam", "Girgaon", "Babulnath Road, Girgaon Chowpatty, Mumbai", ["gujarati", "street food"], 2,
     ["panki", "handvo", "dal_dhokli", "undhiyu_puri", "sev_puri", "methi_thepla", "masala_chaas"]),
    ("Jaffer Bhai's Delhi Darbar", "Girgaon", "Grant Road, Mumbai", ["mughlai", "biryani"], 2,
     ["chicken_biryani", "mutton_biryani", "chicken_changezi", "butter_chicken", "seekh_kebab", "butter_naan", "phirni"]),
    ("Swati Snacks", "Tardeo", "Tardeo Road, Tardeo, Mumbai", ["gujarati", "street food"], 2,
     ["panki", "dahi_puri", "sev_puri", "kadhi_khichdi", "khaman_dhokla", "aamras_puri", "kesar_shrikhand"]),
    ("Sardar Pav Bhaji", "Tardeo", "Tardeo Junction, Tardeo, Mumbai", ["street food"], 1,
     ["pav_bhaji", "cheese_pav_bhaji", "tawa_pulao", "masala_chaas", "veg_frankie", "sweet_lassi"]),
    ("Haji Ali Juice Centre", "Tardeo", "Lala Lajpatrai Marg, Haji Ali, Mumbai", ["juices", "desserts"], 1,
     ["sitaphal_cream", "mango_cream", "strawberry_cream", "fruit_salad_cream", "watermelon_juice", "mosambi_juice", "veg_club_sandwich"]),
    ("Noor Mohammadi Hotel", "Byculla", "Bhendi Bazaar, Mumbai", ["mughlai"], 1,
     ["nalli_nihari", "bheja_fry", "chicken_biryani", "kheema_pav", "chicken_changezi", "mutton_samosa", "shahi_tukda"]),
    ("Persian Darbar", "Byculla", "Byculla, Mumbai", ["mughlai", "biryani"], 2,
     ["mutton_biryani", "chicken_biryani", "veg_biryani", "tandoori_chicken", "paneer_tikka", "malai_kofta", "malpua_rabdi"]),
    ("The Bombay Canteen", "Lower Parel", "Kamala Mills, Lower Parel, Mumbai", ["modern indian"], 4,
     ["kanda_bhaji", "egg_kejriwal", "jackfruit_biryani", "goan_sausage_pao", "laal_maas", "prawn_balchao", "malai_kulfi"]),
    ("Cafe Zoe", "Lower Parel", "Mathuradas Mills, Lower Parel, Mumbai", ["cafe", "european"], 3,
     ["avocado_toast", "shakshuka", "quinoa_salad", "pesto_chicken_pasta", "mushroom_risotto", "ny_cheesecake", "cappuccino"]),
    ("Copper Chimney", "Worli", "Dr Annie Besant Road, Worli, Mumbai", ["north indian", "mughlai"], 3,
     ["tandoori_chicken", "paneer_tikka", "dal_makhani", "butter_chicken", "chicken_biryani", "butter_naan", "rasmalai"]),
    ("Prakash Shakahari Upahar Kendra", "Dadar", "Gokhale Road, Dadar, Mumbai", ["maharashtrian"], 1,
     ["sabudana_khichdi", "sabudana_vada", "misal_pav", "batata_vada", "piyush", "kokum_sharbat"]),
    ("Aaswad", "Dadar", "Gokhale Road, Dadar West, Mumbai", ["maharashtrian"], 1,
     ["misal_pav", "thalipeeth", "kothimbir_vadi", "puran_poli", "ukadiche_modak", "amrakhand", "piyush"]),
    ("Mama Kane", "Dadar", "Near Dadar Station, Dadar West, Mumbai", ["maharashtrian"], 1,
     ["batata_vada", "kanda_poha", "maharashtrian_thali", "zunka_bhakri", "sabudana_khichdi", "kokum_sharbat"]),
    ("Cafe Madras", "Matunga", "King's Circle, Matunga, Mumbai", ["south indian"], 1,
     ["masala_dosa", "butter_masala_dosa", "rava_upma", "ven_pongal", "rasam_rice", "filter_coffee", "rava_kesari"]),
    ("Ram Ashraya", "Matunga", "Bhandarkar Road, Matunga East, Mumbai", ["south indian"], 1,
     ["idli_sambar", "medu_vada", "mysore_dosa", "curd_rice", "bisi_bele_bath", "filter_coffee", "semiya_payasam"]),
    ("Guru Kripa", "Sion", "Sion Road, Sion, Mumbai", ["street food", "north indian"], 1,
     ["punjabi_samosa", "samosa_pav", "samosa_chaat", "chole_bhature", "khasta_kachori", "jalebi_rabdi"]),
    ("Goa Portuguesa", "Mahim", "Kataria Road, Mahim, Mumbai", ["goan", "seafood"], 3,
     ["goan_prawn_curry", "pork_vindaloo", "chicken_xacuti", "mushroom_xacuti", "prawn_rava_fry", "bebinca", "goan_sausage_pao"]),
    ("Candies", "Bandra West", "Mehboob Studio Road, Bandra West, Mumbai", ["cafe", "bakery"], 2,
     ["chicken_puff", "veg_puff", "club_sandwich", "glazed_doughnut", "choc_eclair", "cold_coffee", "cinnamon_roll"]),
    ("Elco Pani Puri Centre", "Bandra West", "Hill Road, Bandra West, Mumbai", ["street food"], 1,
     ["pani_puri", "sev_puri", "dahi_puri", "ragda_pattice", "pav_bhaji", "bhel_puri", "royal_falooda"]),
    ("Hearsch Bakery", "Bandra West", "Hill Road, Bandra West, Mumbai", ["bakery", "desserts"], 1,
     ["glazed_doughnut", "apple_pie", "walnut_brownie", "butter_croissant", "chicken_puff", "cinnamon_roll"]),
    ("Pali Village Cafe", "Bandra West", "Pali Village, Bandra West, Mumbai", ["european", "cafe"], 3,
     ["mushroom_soup", "mushroom_risotto", "veg_lasagne", "grilled_basa", "pesto_chicken_pasta", "tiramisu", "choc_lava"]),
    ("Lucky Restaurant", "Bandra West", "S V Road, Bandra West, Mumbai", ["mughlai", "biryani"], 2,
     ["chicken_biryani", "mutton_biryani", "veg_biryani", "butter_chicken", "dal_makhani", "garlic_naan"]),
    ("Highway Gomantak", "Bandra East", "Western Express Highway, Bandra East, Mumbai", ["malvani", "seafood"], 2,
     ["surmai_thali", "bombil_fry", "malvani_prawn_curry", "tisrya_masala", "fish_curry_rice", "sol_kadhi", "kombdi_vade"]),
    ("Out of the Blue", "Khar", "Union Park, Khar West, Mumbai", ["continental", "italian"], 3,
     ["cheese_fondue", "chicken_sizzler", "paneer_sizzler", "spaghetti_arrabbiata", "mushroom_soup", "choc_lava", "lemon_iced_tea"]),
    ("Gajalee", "Vile Parle", "Hanuman Road, Vile Parle East, Mumbai", ["seafood", "malvani"], 3,
     ["butter_garlic_crab", "bombil_fry", "prawns_koliwada", "pomfret_fry", "surmai_thali", "tisrya_masala", "sol_kadhi"]),
    ("Natural Ice Cream", "Juhu", "Juhu Tara Road, Juhu, Mumbai", ["desserts", "ice cream"], 1,
     ["tender_coconut_ic", "sitaphal_ic", "roasted_almond_ic", "mango_ic", "jamun_ic", "chikoo_ic"]),
    ("Prithvi Cafe", "Juhu", "Prithvi Theatre, Juhu Church Road, Juhu, Mumbai", ["cafe", "north indian"], 2,
     ["masala_chai", "bombay_sandwich", "paneer_kathi_roll", "chilli_cheese_toast", "quinoa_salad", "cold_coffee", "walnut_brownie"]),
    ("Leaping Windows", "Andheri West", "Yari Road, Versova, Andheri West, Mumbai", ["cafe"], 2,
     ["masala_omelette", "pancakes", "chicken_burger", "loaded_nachos", "chicken_caesar", "hot_chocolate", "cappuccino"]),
    ("Mainland China", "Andheri East", "Andheri East, Mumbai", ["chinese"], 3,
     ["hakka_noodles", "schezwan_fried_rice", "chilli_chicken", "veg_manchurian", "chicken_manchow", "chilli_paneer", "darsaan", "american_chopsuey"]),
    ("Mirchi and Mime", "Powai", "Hiranandani Gardens, Powai, Mumbai", ["modern indian", "north indian"], 3,
     ["tamatar_shorba", "paneer_tikka", "galouti_kebab", "laal_maas", "malai_kofta", "jackfruit_biryani", "mango_lassi"]),
    ("Shiv Sagar", "Ghatkopar", "Ghatkopar, Mumbai", ["street food", "south indian", "fast food"], 2,
     ["pav_bhaji", "masala_dosa", "mysore_dosa", "paneer_sizzler", "bombay_sandwich", "mango_lassi", "cold_coffee"]),
    ("Jhama Sweets", "Chembur", "Chembur Camp, Chembur, Mumbai", ["sweets", "street food"], 1,
     ["gulab_jamun", "rasmalai", "kaju_katli", "jalebi_rabdi", "samosa_chaat", "dal_pakwan", "punjabi_samosa"]),
    ("Jumboking", "Malad", "Malad West, Mumbai", ["street food", "fast food"], 1,
     ["vada_pav", "cheese_vada_pav", "schezwan_vada_pav", "veg_frankie", "bombay_sandwich", "cold_coffee"]),
    ("Barbeque Nation", "Borivali", "Borivali West, Mumbai", ["barbeque", "north indian"], 3,
     ["bbq_veg_platter", "bbq_nonveg_platter", "cajun_potatoes", "tandoori_prawns", "grilled_pineapple", "dal_makhani", "malpua_rabdi"]),
]

# Dishes added after the first release. They get ids after the original dishes so existing
# dish ids (and any embeddings already stored against them) do not change.
ADDITIONS = {
    "Leopold Cafe": ["chicken_noodle_soup"],
    "Bademiya": ["egg_bhurji_pav", "egg_roll"],
    "Kyani & Co.": ["egg_bhurji_pav"],
    "Ling's Pavilion": ["chicken_sweet_corn_soup"],
    "Pali Village Cafe": ["chicken_noodle_soup"],
    "Candies": ["grilled_chicken_sandwich"],
    "Cafe Zoe": ["grilled_chicken"],
    "Leaping Windows": ["english_breakfast"],
    "Mahesh Lunch Home": ["chicken_stew_appam"],
    "Noor Mohammadi Hotel": ["mutton_paya"],
    "Lucky Restaurant": ["chicken_curry_rice"],
    "Britannia & Co.": ["chicken_farcha"],
    "Jumboking": ["chicken_frankie"],
    "Barbeque Nation": ["bbq_chicken_wings"],
}

PRICE_MULTIPLIER = {1: 0.75, 2: 1.0, 3: 1.45, 4: 2.1}
SECONDARY_WEIGHTS = (0.7, 0.5)


def price_for(base: int, level: int) -> int:
    return max(20, int(round(base * PRICE_MULTIPLIER[level] / 10.0)) * 10)


def write_csv(name: str, header: list[str], rows: list[list]) -> None:
    path = DATA / name
    with path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(header)
        writer.writerows(rows)
    print(f"wrote {path.relative_to(DATA.parent)} ({len(rows)} rows)")


def main() -> None:
    DATA.mkdir(exist_ok=True)
    zone_by_name = {z[1]: z for z in ZONES}

    write_csv("moods.csv", ["id", "label", "emoji", "description"], [list(m) for m in MOODS])
    write_csv("zones.csv", ["id", "name", "lat", "lng"], [list(z) for z in ZONES])

    restaurants, dishes, dish_moods = [], [], []
    dish_no = 0

    def add_dish(rid: str, level: int, key: str) -> None:
        nonlocal dish_no
        dish_no += 1
        did = f"d{dish_no:03d}"
        dname, desc, base, veg, category, primary, secondaries = D[key]
        dishes.append([did, rid, dname, desc, price_for(base, level), str(veg).lower(), category])
        dish_moods.append([did, primary, 1.0])
        for mood, weight in zip(secondaries, SECONDARY_WEIGHTS):
            dish_moods.append([did, mood, weight])

    for r_no, (name, area, address, cuisine, level, keys) in enumerate(RESTAURANTS, start=1):
        zone = zone_by_name[area]
        rid = f"r{r_no:03d}"
        restaurants.append([rid, name, area, address, zone[2], zone[3], "|".join(cuisine), level, "true", "false"])
        for key in keys:
            add_dish(rid, level, key)
    for r_no, (name, _area, _address, _cuisine, level, _keys) in enumerate(RESTAURANTS, start=1):
        for key in ADDITIONS.get(name, []):
            add_dish(f"r{r_no:03d}", level, key)

    write_csv(
        "restaurants.csv",
        ["id", "name", "area", "address", "lat", "lng", "cuisine", "price_level", "is_open", "coords_verified"],
        restaurants,
    )
    write_csv("dishes.csv", ["id", "restaurant_id", "name", "description", "price_inr", "is_veg", "category"], dishes)
    write_csv("dish_moods.csv", ["dish_id", "mood_id", "weight"], dish_moods)


if __name__ == "__main__":
    main()
