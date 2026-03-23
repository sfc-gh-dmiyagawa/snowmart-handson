import csv
import random
import os
from datetime import datetime, timedelta
import math

random.seed(42)
OUTPUT_DIR = "/Users/dmiyagawa/Downloads/cortex-handson-jp-main/handson_snowmart/data"

# ============================================================
# Japanese location data
# ============================================================
AREAS = [
    # (PREFECTURE, CITY, LAT, LON, POP, HOUSEHOLDS, DAYTIME_RATIO, AVG_INCOME, AREA_TYPE, STATIONS)
    ("東京都", "千代田区", 35.694, 139.754, 67000, 36000, 17.0, 7500000, "オフィス街", ["東京", "大手町", "秋葉原"]),
    ("東京都", "中央区", 35.671, 139.772, 170000, 92000, 5.5, 7200000, "商業地", ["銀座", "日本橋", "築地"]),
    ("東京都", "港区", 35.658, 139.751, 260000, 148000, 4.2, 8000000, "オフィス街", ["六本木", "品川", "新橋"]),
    ("東京都", "新宿区", 35.694, 139.703, 350000, 220000, 2.8, 6500000, "駅前繁華街", ["新宿", "高田馬場", "四谷"]),
    ("東京都", "渋谷区", 35.664, 139.698, 230000, 140000, 2.5, 7000000, "商業地", ["渋谷", "恵比寿", "原宿"]),
    ("東京都", "豊島区", 35.726, 139.716, 300000, 186000, 1.8, 5500000, "駅前繁華街", ["池袋", "大塚", "巣鴨"]),
    ("東京都", "世田谷区", 35.646, 139.653, 940000, 490000, 0.7, 6000000, "住宅地", ["三軒茶屋", "下北沢", "二子玉川"]),
    ("東京都", "杉並区", 35.700, 139.637, 580000, 330000, 0.7, 5800000, "住宅地", ["荻窪", "阿佐ヶ谷", "高円寺"]),
    ("東京都", "練馬区", 35.736, 139.652, 740000, 380000, 0.6, 5200000, "住宅地", ["練馬", "石神井公園", "大泉学園"]),
    ("東京都", "江東区", 35.673, 139.817, 530000, 280000, 1.2, 5500000, "商業地", ["豊洲", "亀戸", "門前仲町"]),
    ("東京都", "足立区", 35.775, 139.805, 690000, 350000, 0.7, 4500000, "住宅地", ["北千住", "竹ノ塚", "西新井"]),
    ("東京都", "八王子市", 35.666, 139.316, 580000, 270000, 0.9, 4800000, "郊外", ["八王子", "高尾", "南大沢"]),
    ("東京都", "町田市", 35.548, 139.447, 430000, 200000, 0.8, 5000000, "郊外", ["町田", "鶴川", "成瀬"]),
    ("神奈川県", "横浜市西区", 35.466, 139.622, 105000, 58000, 2.5, 6200000, "商業地", ["横浜", "みなとみらい", "平沼橋"]),
    ("神奈川県", "横浜市中区", 35.444, 139.638, 150000, 82000, 2.0, 6000000, "商業地", ["関内", "石川町", "桜木町"]),
    ("神奈川県", "川崎市中原区", 35.576, 139.660, 260000, 140000, 0.9, 5800000, "住宅地", ["武蔵小杉", "元住吉", "新丸子"]),
    ("神奈川県", "藤沢市", 35.341, 139.490, 440000, 195000, 0.8, 5300000, "郊外", ["藤沢", "辻堂", "湘南台"]),
    ("大阪府", "大阪市北区", 34.706, 135.498, 140000, 82000, 5.0, 6800000, "駅前繁華街", ["梅田", "中津", "天満"]),
    ("大阪府", "大阪市中央区", 34.681, 135.510, 110000, 66000, 6.0, 7000000, "オフィス街", ["難波", "心斎橋", "本町"]),
    ("大阪府", "大阪市天王寺区", 34.653, 135.519, 83000, 46000, 2.0, 5800000, "商業地", ["天王寺", "鶴橋", "寺田町"]),
    ("大阪府", "堺市堺区", 34.573, 135.483, 150000, 72000, 1.1, 4800000, "住宅地", ["堺", "堺東", "三国ヶ丘"]),
    ("大阪府", "豊中市", 34.781, 135.470, 400000, 190000, 0.8, 5500000, "住宅地", ["豊中", "千里中央", "庄内"]),
    ("愛知県", "名古屋市中区", 35.171, 136.909, 92000, 55000, 5.5, 6500000, "オフィス街", ["栄", "伏見", "金山"]),
    ("愛知県", "名古屋市中村区", 35.171, 136.872, 140000, 78000, 3.5, 6000000, "駅前繁華街", ["名古屋", "中村公園", "亀島"]),
    ("愛知県", "名古屋市千種区", 35.171, 136.945, 170000, 92000, 1.2, 5800000, "住宅地", ["千種", "今池", "星ヶ丘"]),
    ("愛知県", "豊田市", 35.083, 137.156, 420000, 180000, 1.1, 5500000, "郊外", ["豊田市", "新豊田", "三河豊田"]),
    ("福岡県", "福岡市博多区", 33.590, 130.421, 255000, 140000, 2.8, 5800000, "駅前繁華街", ["博多", "中洲川端", "祇園"]),
    ("福岡県", "福岡市中央区", 33.590, 130.399, 205000, 118000, 2.5, 6200000, "商業地", ["天神", "赤坂", "大濠公園"]),
    ("福岡県", "北九州市小倉北区", 33.883, 130.876, 180000, 95000, 1.8, 5000000, "商業地", ["小倉", "西小倉", "南小倉"]),
    ("埼玉県", "さいたま市大宮区", 35.906, 139.631, 120000, 58000, 2.0, 5500000, "駅前繁華街", ["大宮", "さいたま新都心", "北大宮"]),
    ("埼玉県", "さいたま市浦和区", 35.862, 139.645, 165000, 78000, 1.2, 5800000, "住宅地", ["浦和", "北浦和", "与野"]),
    ("埼玉県", "川越市", 35.925, 139.486, 350000, 158000, 0.9, 4800000, "郊外", ["川越", "本川越", "川越市"]),
    ("千葉県", "千葉市中央区", 35.607, 140.106, 210000, 108000, 1.5, 5200000, "商業地", ["千葉", "千葉中央", "蘇我"]),
    ("千葉県", "船橋市", 35.695, 139.983, 640000, 300000, 0.7, 5000000, "住宅地", ["船橋", "西船橋", "津田沼"]),
    ("千葉県", "柏市", 35.868, 139.976, 430000, 195000, 0.8, 5100000, "郊外", ["柏", "南柏", "柏の葉キャンパス"]),
    ("北海道", "札幌市中央区", 43.055, 141.341, 250000, 145000, 2.5, 5200000, "商業地", ["札幌", "大通", "すすきの"]),
    ("北海道", "札幌市北区", 43.091, 141.341, 290000, 155000, 0.8, 4500000, "住宅地", ["北24条", "麻生", "北12条"]),
    ("宮城県", "仙台市青葉区", 38.268, 140.870, 310000, 160000, 2.0, 5500000, "商業地", ["仙台", "広瀬通", "勾当台公園"]),
    ("広島県", "広島市中区", 34.392, 132.459, 135000, 73000, 2.8, 5300000, "商業地", ["広島", "紙屋町", "八丁堀"]),
    ("京都府", "京都市下京区", 34.991, 135.759, 82000, 44000, 3.0, 5500000, "駅前繁華街", ["京都", "四条", "五条"]),
    ("京都府", "京都市中京区", 35.011, 135.759, 110000, 60000, 2.0, 5800000, "商業地", ["烏丸御池", "二条", "河原町"]),
    ("兵庫県", "神戸市中央区", 34.690, 135.197, 150000, 85000, 2.5, 5800000, "商業地", ["三宮", "元町", "神戸"]),
    ("兵庫県", "神戸市東灘区", 34.720, 135.270, 215000, 105000, 0.8, 5500000, "住宅地", ["住吉", "岡本", "摂津本山"]),
    ("静岡県", "静岡市葵区", 34.976, 138.383, 250000, 115000, 1.5, 5000000, "商業地", ["静岡", "新静岡", "日吉町"]),
    ("新潟県", "新潟市中央区", 37.916, 139.036, 180000, 90000, 1.8, 4800000, "商業地", ["新潟", "白山", "関屋"]),
    ("岡山県", "岡山市北区", 34.662, 133.935, 300000, 140000, 1.5, 4900000, "商業地", ["岡山", "北長瀬", "法界院"]),
    ("熊本県", "熊本市中央区", 32.803, 130.708, 190000, 100000, 2.0, 4800000, "商業地", ["熊本", "通町筋", "水道町"]),
    ("沖縄県", "那覇市", 26.335, 127.681, 320000, 150000, 1.5, 4200000, "商業地", ["おもろまち", "牧志", "県庁前"]),
    ("長野県", "長野市", 36.651, 138.181, 370000, 155000, 1.2, 4600000, "郊外", ["長野", "篠ノ井", "川中島"]),
    ("石川県", "金沢市", 36.561, 136.656, 460000, 200000, 1.3, 4800000, "商業地", ["金沢", "香林坊", "片町"]),
]

STORE_NAME_SUFFIXES = ["駅前店", "中央店", "南口店", "北口店", "東口店", "西口店", "本町店",
                        "一丁目店", "二丁目店", "大通り店", "公園前店", "駅ビル店", "商店街店",
                        "ロードサイド店", "インター店", "大学前店", "病院前店", "市役所前店",
                        "ニュータウン店", "モール前店"]

COMPETITOR_CHAINS = [("セブン-イレブン", 0.35), ("ファミリーマート", 0.30), ("ローソン", 0.25),
                     ("ミニストップ", 0.07), ("デイリーヤマザキ", 0.03)]

# ============================================================
# 1. Area Master
# ============================================================
print("Generating area_master.csv...")
area_rows = []
for i, a in enumerate(AREAS):
    area_rows.append({
        "AREA_ID": f"A{i+1:02d}",
        "PREFECTURE": a[0], "CITY": a[1],
        "POPULATION": a[4], "HOUSEHOLDS": a[5],
        "DAYTIME_POPULATION_RATIO": a[6], "AVG_ANNUAL_INCOME": a[7],
        "AREA_TYPE": a[8]
    })

with open(os.path.join(OUTPUT_DIR, "area_master.csv"), "w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, fieldnames=["AREA_ID","PREFECTURE","CITY","POPULATION","HOUSEHOLDS",
                                       "DAYTIME_POPULATION_RATIO","AVG_ANNUAL_INCOME","AREA_TYPE"])
    w.writeheader()
    w.writerows(area_rows)
print(f"  area_master.csv: {len(area_rows)} rows")

# ============================================================
# 2. SnowMart Stores
# ============================================================
print("Generating snowmart_stores.csv...")
# Weighted area distribution
weights = []
for a in AREAS:
    if a[0] == "東京都": weights.append(5)
    elif a[0] in ("神奈川県", "大阪府"): weights.append(3)
    elif a[0] in ("愛知県", "福岡県", "埼玉県", "千葉県"): weights.append(2)
    else: weights.append(1)

stores = []
used_names = set()
for i in range(500):
    area = random.choices(AREAS, weights=weights, k=1)[0]
    station = random.choice(area[9])
    suffix = random.choice(STORE_NAME_SUFFIXES)
    name = f"{station}{suffix}"
    while name in used_names:
        suffix = random.choice(STORE_NAME_SUFFIXES)
        name = f"{station}{suffix}"
    used_names.add(name)

    lat = area[2] + random.uniform(-0.02, 0.02)
    lon = area[3] + random.uniform(-0.02, 0.02)
    floor = max(50, min(200, int(random.gauss(100, 25))))
    open_year = random.randint(2010, 2024)
    open_month = random.randint(1, 12)
    open_day = random.randint(1, 28)
    store_type = "直営" if random.random() < 0.7 else "FC"

    stores.append({
        "STORE_ID": f"S{i+1:03d}",
        "STORE_NAME": name,
        "PREFECTURE": area[0],
        "CITY": area[1],
        "LATITUDE": round(lat, 6),
        "LONGITUDE": round(lon, 6),
        "STORE_TYPE": store_type,
        "FLOOR_AREA_SQM": floor,
        "OPEN_DATE": f"{open_year}-{open_month:02d}-{open_day:02d}",
        "NEAREST_STATION": station
    })

with open(os.path.join(OUTPUT_DIR, "snowmart_stores.csv"), "w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, fieldnames=["STORE_ID","STORE_NAME","PREFECTURE","CITY","LATITUDE",
                                       "LONGITUDE","STORE_TYPE","FLOOR_AREA_SQM","OPEN_DATE","NEAREST_STATION"])
    w.writeheader()
    w.writerows(stores)
print(f"  snowmart_stores.csv: {len(stores)} rows")

# ============================================================
# 3. Competitor Stores
# ============================================================
print("Generating competitor_stores.csv...")
chain_names = [c[0] for c in COMPETITOR_CHAINS]
chain_weights = [c[1] for c in COMPETITOR_CHAINS]

competitors = []
for i in range(1000):
    area = random.choices(AREAS, weights=weights, k=1)[0]
    chain = random.choices(chain_names, weights=chain_weights, k=1)[0]
    lat = area[2] + random.uniform(-0.03, 0.03)
    lon = area[3] + random.uniform(-0.03, 0.03)
    floor = max(40, min(180, int(random.gauss(90, 25))))

    competitors.append({
        "COMPETITOR_ID": f"C{i+1:04d}",
        "CHAIN_NAME": chain,
        "PREFECTURE": area[0],
        "CITY": area[1],
        "LATITUDE": round(lat, 6),
        "LONGITUDE": round(lon, 6),
        "FLOOR_AREA_SQM": floor
    })

with open(os.path.join(OUTPUT_DIR, "competitor_stores.csv"), "w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, fieldnames=["COMPETITOR_ID","CHAIN_NAME","PREFECTURE","CITY",
                                       "LATITUDE","LONGITUDE","FLOOR_AREA_SQM"])
    w.writeheader()
    w.writerows(competitors)
print(f"  competitor_stores.csv: {len(competitors)} rows")

# ============================================================
# 4. Daily Sales
# ============================================================
print("Generating daily_sales.csv...")

# Build area lookup for stores
area_lookup = {}
for a in AREAS:
    area_lookup[(a[0], a[1])] = {"type": a[8], "pop": a[4], "ratio": a[6]}

start_date = datetime(2024, 1, 1)
sales_rows = []

for store in stores:
    key = (store["PREFECTURE"], store["CITY"])
    area_info = area_lookup.get(key, {"type": "住宅地", "pop": 300000, "ratio": 1.0})

    # Base daily sales by area type
    base_sales = {
        "オフィス街": random.randint(400000, 600000),
        "商業地": random.randint(350000, 550000),
        "駅前繁華街": random.randint(380000, 580000),
        "住宅地": random.randint(200000, 380000),
        "郊外": random.randint(180000, 350000),
    }.get(area_info["type"], 300000)

    # Adjust by floor area
    base_sales = int(base_sales * (store["FLOOR_AREA_SQM"] / 100))

    for day_offset in range(366):  # 2024 is leap year
        d = start_date + timedelta(days=day_offset)
        dow = d.weekday()  # 0=Mon, 6=Sun

        # Day of week factor
        if area_info["type"] in ("オフィス街",):
            dow_factor = 1.1 if dow < 5 else 0.7
        elif area_info["type"] in ("住宅地", "郊外"):
            dow_factor = 0.95 if dow < 5 else 1.15
        else:
            dow_factor = 1.0 if dow < 5 else 1.1

        # Season factor
        month = d.month
        if month in (7, 8):
            season_factor = 1.12  # summer: beverages up
        elif month in (12, 1, 2):
            season_factor = 1.05  # winter: food up
        elif month in (6,):
            season_factor = 0.92  # rainy season
        else:
            season_factor = 1.0

        daily_sales = int(base_sales * dow_factor * season_factor * random.uniform(0.85, 1.15))
        customers = max(100, int(daily_sales / random.uniform(350, 550)))
        avg_price = round(daily_sales / customers, 1)

        food_pct = random.uniform(0.40, 0.50)
        bev_pct = random.uniform(0.25, 0.35)
        if month in (7, 8):
            bev_pct += 0.05
            food_pct -= 0.03
        food_sales = int(daily_sales * food_pct)
        bev_sales = int(daily_sales * bev_pct)
        daily_goods = daily_sales - food_sales - bev_sales

        sales_rows.append({
            "STORE_ID": store["STORE_ID"],
            "SALES_DATE": d.strftime("%Y-%m-%d"),
            "SALES_AMOUNT": daily_sales,
            "CUSTOMER_COUNT": customers,
            "AVG_UNIT_PRICE": avg_price,
            "FOOD_SALES": food_sales,
            "BEVERAGE_SALES": bev_sales,
            "DAILY_GOODS_SALES": daily_goods
        })

with open(os.path.join(OUTPUT_DIR, "daily_sales.csv"), "w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, fieldnames=["STORE_ID","SALES_DATE","SALES_AMOUNT","CUSTOMER_COUNT",
                                       "AVG_UNIT_PRICE","FOOD_SALES","BEVERAGE_SALES","DAILY_GOODS_SALES"])
    w.writeheader()
    w.writerows(sales_rows)
print(f"  daily_sales.csv: {len(sales_rows)} rows")

# ============================================================
# 5. Customer Reviews
# ============================================================
print("Generating customer_reviews.csv...")

POSITIVE_TEMPLATES = [
    "品揃えが豊富で助かっています。特にお弁当の種類が多いのが嬉しいです。",
    "店員さんの対応がとても丁寧です。いつも気持ちよく買い物できます。",
    "店内がいつも清潔で、気持ちよく利用しています。トイレもきれいです。",
    "駅から近くて便利です。通勤途中に毎日寄っています。",
    "24時間営業なので、夜遅くなっても安心です。残業帰りによく利用します。",
    "コーヒーの品質が良くて、毎朝ここで買っています。コスパも良いです。",
    "新商品がいつも早く入荷されるので、新しいもの好きにはたまらない店舗です。",
    "セルフレジが導入されてから、レジ待ちが減りました。スムーズに買い物できます。",
    "お惣菜のクオリティが高い。手作り感があって、コンビニとは思えない味です。",
    "ATMがあるので急にお金が必要な時に助かります。手数料も安いです。",
    "スタッフの方がフレンドリーで、地域に密着した温かみのあるお店だと思います。",
    "イートインスペースが快適です。ちょっとした休憩に最適です。",
    "宅配便の受け取りができるようになって、とても便利になりました。",
    "季節限定のスイーツが毎回楽しみです。特に冬のチョコレート系が美味しいです。",
    "おにぎりの品揃えが素晴らしい。特に地域限定の具材が気に入っています。",
]

NEGATIVE_TEMPLATES = [
    "駐車場がないので車で行けません。周辺にコインパーキングもなく不便です。",
    "夕方になると弁当がほとんど品切れになっている。補充が追いついていない感じがする。",
    "店内が狭くて、他のお客さんとすれ違うのが大変です。カートも使えない広さです。",
    "接客態度がよくない。挨拶がないし、レジ対応も雑に感じることがある。",
    "トイレが汚いことが多い。清掃の頻度を上げてほしい。",
    "価格が近隣のコンビニと比べて少し高い印象。もう少し安くしてほしい。",
    "レジが1台しか稼働していなくて、昼時は長い列ができる。改善してほしい。",
    "照明が暗くて、特に夜は入りづらい雰囲気がある。防犯面でも心配です。",
    "お弁当の消費期限が短い商品が多く、買うタイミングが難しい。",
    "Wi-Fiがないのが不便。休憩で使いたいのに。近くの他のコンビニにはあるのに。",
]

MIXED_TEMPLATES = [
    "立地は便利だけど、品揃えがもう少し充実してほしい。特にパンの種類が少ない。",
    "基本的には満足しているが、夜間のスタッフの対応に差がある。研修を強化してほしい。",
    "駅前で使いやすいのは良いが、混雑時はレジの回転が悪い。もう1台増やしてほしい。",
    "コーヒーは美味しいが、フードメニューのバリエーションが少ない。もっと選びたい。",
    "清潔感はあるが、売場のレイアウトが分かりにくい。特に初めて来た人は迷うと思う。",
]

reviews = []
age_groups = ["10代", "20代", "30代", "40代", "50代以上"]
age_weights = [0.05, 0.30, 0.30, 0.20, 0.15]

for i in range(500):
    store_id = random.choice(stores)["STORE_ID"]
    review_date = start_date + timedelta(days=random.randint(0, 365))
    age_group = random.choices(age_groups, weights=age_weights, k=1)[0]

    r = random.random()
    if r < 0.35:  # positive
        rating = random.choices([4, 5], weights=[0.5, 0.5], k=1)[0]
        text = random.choice(POSITIVE_TEMPLATES)
    elif r < 0.55:  # negative
        rating = random.choices([1, 2], weights=[0.3, 0.7], k=1)[0]
        text = random.choice(NEGATIVE_TEMPLATES)
    elif r < 0.75:  # mixed
        rating = 3
        text = random.choice(MIXED_TEMPLATES)
    else:  # random
        rating = random.randint(1, 5)
        if rating >= 4:
            text = random.choice(POSITIVE_TEMPLATES)
        elif rating <= 2:
            text = random.choice(NEGATIVE_TEMPLATES)
        else:
            text = random.choice(MIXED_TEMPLATES)

    reviews.append({
        "REVIEW_ID": f"R{i+1:03d}",
        "STORE_ID": store_id,
        "REVIEW_DATE": review_date.strftime("%Y-%m-%d"),
        "RATING": rating,
        "REVIEW_TEXT": text,
        "REVIEWER_AGE_GROUP": age_group
    })

with open(os.path.join(OUTPUT_DIR, "customer_reviews.csv"), "w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, fieldnames=["REVIEW_ID","STORE_ID","REVIEW_DATE","RATING",
                                       "REVIEW_TEXT","REVIEWER_AGE_GROUP"])
    w.writeheader()
    w.writerows(reviews)
print(f"  customer_reviews.csv: {len(reviews)} rows")

# ============================================================
# Summary
# ============================================================
print("\n=== Generation Complete ===")
for fname in ["area_master.csv", "snowmart_stores.csv", "competitor_stores.csv",
              "daily_sales.csv", "customer_reviews.csv"]:
    fpath = os.path.join(OUTPUT_DIR, fname)
    size = os.path.getsize(fpath)
    print(f"  {fname}: {size:,} bytes")
print("\nDone!")
