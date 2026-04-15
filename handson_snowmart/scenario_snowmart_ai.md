# SnowMart 出店戦略ハンズオン（AI特化版）

## 概要

- **テーマ**: 架空コンビニ「スノーマート」の次の出店先をAIで決める
- **対象者**: AWS Jr. Champions（若手エンジニア）
- **所要時間**: 90分（コア 80分 ＋ バッファ 10分）
- **オプション**: Scene 5 Streamlit（＋10分、合計最大90分）
- **環境**: 各自の Snowflake トライアルアカウント
- **言語**: SQL・カラム名は英語、説明は日本語

## タイムライン

| シーン | 内容 | 時間 |
|--|--|--|
| セットアップ確認 | データ確認・環境チェック | 5分 |
| Scene 1 | Cortex AI Functions — レビュー分析 | 20分 |
| Scene 2 | Cortex Search — 社内ナレッジ RAG | 12分 |
| Scene 3 | Semantic View + Cortex Analyst | 15分 |
| Scene 4 | Cortex Agent — 出店戦略を決める | 23分 |
| まとめ | AWS対比・次のステップ | 5分 |
| **合計** | | **80分** |
| Scene 5（オプション） | Streamlit ダッシュボード | +10分 |

---

## ストーリー

あなたはコンビニチェーン「**スノーマート**」のデータチームに配属された新メンバーです。
スノーマートは現在全国に500店舗を展開しており、来年度中に **600店舗** への拡大を計画しています。

本部から依頼が届きました：

> 「データを使って、次に出店すべきエリアを提案してほしい。
> 売上実績、顧客の声、社内ガイドラインを全部踏まえてね。」

今日のミッションはこの問いに **Snowflake の AI 機能だけ** で答えることです。

---

## 事前準備（参加者向け・セッション開始前）

### 1. Snowflake トライアルアカウントの作成

1. `https://signup.snowflake.com/` にアクセス
2. 以下の設定でアカウントを作成:
   - Cloud Provider: `AWS`
   - Region: `Asia Pacific (Tokyo)`
   - Edition: `Enterprise`（推奨）
3. メール認証を完了し、Snowsight にログインできることを確認

### 2. CSVファイルのダウンロード

GitHub からデータを取得します。

```
リポジトリ: https://github.com/sfc-gh-dmiyagawa/snowmart-handson
ダウンロード対象: handson_snowmart/data/ 以下の5ファイル
  - snowmart_stores.csv
  - competitor_stores.csv
  - area_master.csv
  - daily_sales.csv
  - customer_reviews.csv
```

### 3. setup_snowmart.sql の実行

1. Snowsight にログインし、**Worksheets** を開く
2. `setup_snowmart.sql` の内容をワークシートに貼り付け
3. **Step 1** のステージ作成まで実行する
4. Snowsight の Stage 画面からCSVを5本アップロード
5. **Step 2 以降**を実行してデータをロード

```sql
-- 最後にこのクエリで確認。すべての行数が想定値であればOK
SELECT 'SNOWMART_STORES'    AS T, COUNT(*) FROM SNOWMART_STORES
UNION ALL SELECT 'COMPETITOR_STORES', COUNT(*) FROM COMPETITOR_STORES
UNION ALL SELECT 'AREA_MASTER',       COUNT(*) FROM AREA_MASTER
UNION ALL SELECT 'DAILY_SALES',       COUNT(*) FROM DAILY_SALES
UNION ALL SELECT 'CUSTOMER_REVIEWS',  COUNT(*) FROM CUSTOMER_REVIEWS;
-- SNOWMART_STORES=500 / COMPETITOR_STORES=1000 / AREA_MASTER=50
-- DAILY_SALES=約180,000 / CUSTOMER_REVIEWS=500
```

> **重要**: Cortex Search Service のインデックス構築に数分かかります。  
> セッション開始の **15分前** までに setup_snowmart.sql を完了させてください。

---

# セットアップ確認（5分）

### 講師トーク

> 「おはようございます。今日は90分で、Snowflake の AI 機能を一気通貫で体験します。
> データはすでにロード済みです。まず確認しましょう。」

```sql
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;
USE SCHEMA SNOWMART_DB.SNOWMART_SCHEMA;

-- データ確認
SELECT 'SNOWMART_STORES'    AS TABLE_NAME, COUNT(*) AS ROWS FROM SNOWMART_STORES
UNION ALL SELECT 'DAILY_SALES',        COUNT(*) FROM DAILY_SALES
UNION ALL SELECT 'CUSTOMER_REVIEWS',   COUNT(*) FROM CUSTOMER_REVIEWS
UNION ALL SELECT 'STORE_SALES_ANALYSIS', COUNT(*) FROM STORE_SALES_ANALYSIS
UNION ALL SELECT 'STORE_DOCUMENTS',    COUNT(*) FROM STORE_DOCUMENTS;
```

> 全テーブルに想定どおりのデータが入っていることを確認します。  
> `STORE_SALES_ANALYSIS`（Dynamic Table）と `STORE_DOCUMENTS`（10行）も確認。

### 今日使うデータの紹介（1分）

```sql
-- スノーマートの店舗を眺めてみる
SELECT PREFECTURE, CITY, STORE_TYPE, NEAREST_STATION
FROM SNOWMART_STORES
LIMIT 10;

-- 顧客レビューの例
SELECT STORE_ID, RATING, LEFT(REVIEW_TEXT, 80) AS REVIEW_PREVIEW
FROM CUSTOMER_REVIEWS
ORDER BY RATING ASC
LIMIT 5;
```

### 今日体験するAI機能

1. **Cortex AI Functions** — SQL一行でLLM（感情分析・要約・分類・テキスト生成）
2. **Cortex Search** — 社内文書に自然言語で質問（RAG）
3. **Semantic View + Cortex Analyst** — 自然言語でデータ分析
4. **Cortex Agent** — 複数AIツールを自律的に組み合わせて回答

---

# Scene 1: Cortex AI Functions — レビュー分析（20分）

> **ゴール**: 500件の顧客レビューをSQL一行でAI分析し、課題店舗と改善施策を導く

### 講師トーク

> 「500件のレビューを全部読む時間はありません。
> Cortex AI Functions を使えば感情分析・要約・分類・LLM回答が SQL に関数を書くだけで完結します。
> APIキー不要。データは Snowflake の外に出ません。
> AWSだと Comprehend + Bedrock + Lambda の組み合わせが必要な部分です。」

## Step 1-1: 感情分析（SENTIMENT）

```sql
-- レビューごとに感情スコアを計算（-1: 極ネガ ～ +1: 極ポジ）
SELECT
    REVIEW_ID,
    STORE_ID,
    RATING,
    LEFT(REVIEW_TEXT, 40)                              AS REVIEW_PREVIEW,
    ROUND(SNOWFLAKE.CORTEX.SENTIMENT(REVIEW_TEXT), 3)  AS SENTIMENT_SCORE
FROM CUSTOMER_REVIEWS
ORDER BY SENTIMENT_SCORE ASC
LIMIT 20;
```

```sql
-- 店舗別の平均感情スコア（課題店舗の発見）
SELECT
    cr.STORE_ID,
    st.STORE_NAME,
    st.PREFECTURE,
    COUNT(*)                                                           AS REVIEW_COUNT,
    ROUND(AVG(cr.RATING), 1)                                          AS AVG_RATING,
    ROUND(AVG(SNOWFLAKE.CORTEX.SENTIMENT(cr.REVIEW_TEXT)), 3)         AS AVG_SENTIMENT
FROM CUSTOMER_REVIEWS cr
JOIN SNOWMART_STORES st ON cr.STORE_ID = st.STORE_ID
GROUP BY cr.STORE_ID, st.STORE_NAME, st.PREFECTURE
HAVING COUNT(*) >= 3
ORDER BY AVG_SENTIMENT ASC
LIMIT 10;
```

> 感情スコアが最も低い店舗を確認します。評価（星）と感情スコアに乖離はありますか？

## Step 1-2: ネガティブレビューの要約（SUMMARIZE）

```sql
-- 低評価レビューをまとめて要約 — 全部読まなくても傾向が一瞬でわかる
SELECT SNOWFLAKE.CORTEX.SUMMARIZE(
    ARRAY_TO_STRING(
        ARRAY_AGG(REVIEW_TEXT) WITHIN GROUP (ORDER BY RATING ASC),
        '\n'
    )
) AS NEGATIVE_REVIEW_SUMMARY
FROM CUSTOMER_REVIEWS
WHERE RATING <= 2;
```

## Step 1-3: 問題カテゴリの自動分類（CLASSIFY_TEXT）

```sql
-- レビューを課題カテゴリに自動分類（手動タグ付け不要）
SELECT
    REVIEW_ID,
    STORE_ID,
    RATING,
    LEFT(REVIEW_TEXT, 50) AS REVIEW_PREVIEW,
    SNOWFLAKE.CORTEX.CLASSIFY_TEXT(
        REVIEW_TEXT,
        ['接客・サービス', '品揃え・商品', '立地・アクセス', '店内環境・清潔さ', '価格・レジ待ち']
    ):label::VARCHAR AS CATEGORY
FROM CUSTOMER_REVIEWS
WHERE RATING <= 2
LIMIT 30;
```

```sql
-- カテゴリ別の集計（どの問題が最多か）
SELECT
    SNOWFLAKE.CORTEX.CLASSIFY_TEXT(
        REVIEW_TEXT,
        ['接客・サービス', '品揃え・商品', '立地・アクセス', '店内環境・清潔さ', '価格・レジ待ち']
    ):label::VARCHAR AS CATEGORY,
    COUNT(*) AS COUNT
FROM CUSTOMER_REVIEWS
WHERE RATING <= 2
GROUP BY CATEGORY
ORDER BY COUNT DESC;
```

## Step 1-4: LLMに改善施策を提案させる（COMPLETE）

```sql
-- 最もネガティブな店舗の状況をLLMに渡して改善施策を生成
WITH WORST_STORE AS (
    SELECT
        st.STORE_NAME,
        st.PREFECTURE,
        st.CITY,
        st.AREA_TYPE,
        ROUND(AVG(sa.SALES_AMOUNT))                                   AS AVG_DAILY_SALES,
        ROUND(AVG(SNOWFLAKE.CORTEX.SENTIMENT(cr.REVIEW_TEXT)), 3)     AS AVG_SENTIMENT,
        COUNT(cr.REVIEW_ID)                                           AS REVIEW_COUNT
    FROM CUSTOMER_REVIEWS cr
    JOIN SNOWMART_STORES st ON cr.STORE_ID = st.STORE_ID
    JOIN STORE_SALES_ANALYSIS sa ON cr.STORE_ID = sa.STORE_ID
    WHERE cr.STORE_ID = (
        SELECT STORE_ID FROM CUSTOMER_REVIEWS
        GROUP BY STORE_ID HAVING COUNT(*) >= 3
        ORDER BY AVG(SNOWFLAKE.CORTEX.SENTIMENT(REVIEW_TEXT)) ASC
        LIMIT 1
    )
    GROUP BY st.STORE_NAME, st.PREFECTURE, st.CITY, st.AREA_TYPE
)
SELECT SNOWFLAKE.CORTEX.COMPLETE(
    'mistral-large2',
    CONCAT(
        '以下のコンビニ店舗データに基づき、改善施策を3つ、具体的かつ簡潔に提案してください。\n\n',
        '店舗名: ', STORE_NAME, '\n',
        '所在地: ', PREFECTURE, ' ', CITY, '（', AREA_TYPE, '）\n',
        '平均日販: ', AVG_DAILY_SALES::VARCHAR, '円\n',
        '顧客感情スコア: ', AVG_SENTIMENT::VARCHAR, '（-1が最悪、+1が最良）\n',
        'レビュー件数: ', REVIEW_COUNT::VARCHAR, '件\n\n',
        '改善施策（各50字以内で）:'
    )
) AS IMPROVEMENT_SUGGESTIONS
FROM WORST_STORE;
```

### 講師ポイント

- 「`SENTIMENT` / `SUMMARIZE` / `CLASSIFY_TEXT` / `COMPLETE` はすべて `SELECT` の中に書くだけ」
- 「`COMPLETE()` の第一引数はモデル名。`mistral-large2`、`llama3.1-70b`、`claude-3-5-sonnet` 等を選択可能」
- 「データが Snowflake 外に出ないため、顧客レビューのような個人情報を含むデータも安全に使えます」
- 「AWSだと Amazon Comprehend + Bedrock API + Lambda の組み合わせが必要な処理をSQL一本で完結」

---

# Scene 2: Cortex Search — 社内ガイドラインを検索する（12分）

> **ゴール**: セットアップ済みの RAG 基盤を使って、出店ガイドラインを自然言語で検索する

### 講師トーク

> 「出店ガイドライン（10セクション）はすでに Cortex Search Service に登録済みです。
> 今度は自然言語でガイドラインに質問してみましょう。
> キーワード検索ではなくセマンティック検索なので、言い回しが違っても意味が近ければ見つかります。」

## Step 2-1: 既存の Search Service を確認

```sql
-- セットアップ時に作成済みの Cortex Search Service を確認
SHOW CORTEX SEARCH SERVICES IN SCHEMA SNOWMART_DB.SNOWMART_SCHEMA;

-- ドキュメントの一覧を確認
SELECT DOC_ID, DOC_SECTION FROM STORE_DOCUMENTS ORDER BY DOC_ID;
```

## Step 2-2: 自然言語でガイドラインを検索

```sql
-- 「住宅地への出店条件は？」
SELECT PARSE_JSON(
    SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
        'SNOWMART_DB.SNOWMART_SCHEMA.SNOWMART_DOC_SEARCH',
        '{
            "query": "住宅地に出店する際の条件と注意点を教えてください",
            "columns": ["DOC_SECTION", "DOC_TEXT"],
            "limit": 3
        }'
    )
) AS SEARCH_RESULTS;
```

```sql
-- 「競合が多いエリアではどうする？」
SELECT PARSE_JSON(
    SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
        'SNOWMART_DB.SNOWMART_SCHEMA.SNOWMART_DOC_SEARCH',
        '{
            "query": "競合コンビニが多いエリアへの出店はどう判断すればよいですか",
            "columns": ["DOC_SECTION", "DOC_TEXT"],
            "limit": 3
        }'
    )
) AS SEARCH_RESULTS;
```

```sql
-- 「出店候補のスコアリング方法は？」
SELECT PARSE_JSON(
    SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
        'SNOWMART_DB.SNOWMART_SCHEMA.SNOWMART_DOC_SEARCH',
        '{
            "query": "出店候補エリアをどうやって評価・採点すればいいですか",
            "columns": ["DOC_SECTION", "DOC_TEXT"],
            "limit": 2
        }'
    )
) AS SEARCH_RESULTS;
```

### 講師ポイント

- 「テーブルに文書を入れて `CREATE CORTEX SEARCH SERVICE` するだけ。Embedding モデルの選定・管理・インデックス運用が不要」
- 「AWSだと Bedrock Knowledge Base + OpenSearch Serverless + Lambda が必要な構成がこれだけで完結」
- 「次の Scene 4 でこの Search Service を Cortex Agent のツールとして組み込みます」

---

# Scene 3: Semantic View + Cortex Analyst — 自然言語でデータ分析（15分）

> **ゴール**: テーブルにビジネスの意味を定義し、日本語で質問するだけでデータ分析できるようにする

### 講師トーク

> 「売上分析をするとき、普通は『どのカラムが売上？』『都市別集計はどう書く？』を
> ドキュメントで調べてからSQLを書きますよね。
> Semantic View でテーブルに意味を一度定義しておくと、
> あとは『都市別の平均日販を教えて』と日本語で聞くだけでSQLが自動生成されます。」

## Step 3-1: Semantic View の作成

```sql
CREATE OR REPLACE SEMANTIC VIEW SNOWMART_ANALYSIS
    AS SELECT
        sa.STORE_ID,
        sa.STORE_NAME,
        sa.PREFECTURE,
        sa.CITY,
        sa.STORE_TYPE,
        sa.AREA_TYPE,
        sa.NEAREST_STATION,
        sa.POPULATION,
        sa.AVG_ANNUAL_INCOME,
        sa.DAYTIME_POPULATION_RATIO,
        sa.SALES_DATE,
        sa.SALES_AMOUNT,
        sa.CUSTOMER_COUNT,
        sa.AVG_UNIT_PRICE,
        sa.FOOD_SALES,
        sa.BEVERAGE_SALES,
        sa.DAILY_GOODS_SALES,
        comp.COMPETITOR_COUNT
    FROM STORE_SALES_ANALYSIS sa
    LEFT JOIN (
        SELECT PREFECTURE, CITY, COUNT(*) AS COMPETITOR_COUNT
        FROM COMPETITOR_STORES GROUP BY PREFECTURE, CITY
    ) comp ON sa.PREFECTURE = comp.PREFECTURE AND sa.CITY = comp.CITY

    DIMENSIONS (
        STORE_ID        WITH SYNONYMS = ('店舗ID'),
        STORE_NAME      WITH SYNONYMS = ('店舗名', '店名'),
        PREFECTURE      WITH SYNONYMS = ('都道府県', '県'),
        CITY            WITH SYNONYMS = ('市区町村', '市', '区'),
        STORE_TYPE      WITH SYNONYMS = ('店舗種別', '直営FC'),
        AREA_TYPE       WITH SYNONYMS = ('エリア種別', '立地タイプ'),
        NEAREST_STATION WITH SYNONYMS = ('最寄り駅', '駅'),
        SALES_DATE      WITH SYNONYMS = ('売上日', '日付')
    )

    METRICS (
        SALES_AMOUNT      WITH SYNONYMS = ('日次売上', '売上金額', '売上', '日販'),
        CUSTOMER_COUNT    WITH SYNONYMS = ('来客数', '顧客数'),
        AVG_UNIT_PRICE    WITH SYNONYMS = ('客単価', '平均単価'),
        FOOD_SALES        WITH SYNONYMS = ('フード売上', '食品売上'),
        BEVERAGE_SALES    WITH SYNONYMS = ('飲料売上'),
        DAILY_GOODS_SALES WITH SYNONYMS = ('日用品売上'),
        POPULATION        WITH SYNONYMS = ('人口', '商圏人口'),
        COMPETITOR_COUNT  WITH SYNONYMS = ('競合店数', '競合数')
    );
```

```sql
-- 作成確認
DESCRIBE SEMANTIC VIEW SNOWMART_ANALYSIS;
```

## Step 3-2: Cortex Analyst で自然言語クエリ

Snowsight 左メニュー → **AI & ML** → **Cortex Analyst** を開きます。

Semantic Model に `SNOWMART_DB.SNOWMART_SCHEMA.SNOWMART_ANALYSIS` を選択し、以下を入力:

**Q1**: 「都道府県別の平均日販を高い順に教えてください」
```
→ 都道府県別 AVG(SALES_AMOUNT) のSQLを自動生成
```

**Q2**: 「競合店数が少なく人口が多いエリアのTOP10を教えてください」
```
→ 出店チャンスのあるエリアが浮かび上がります
```

**Q3**: 「住宅地エリアと商業地エリアの平均来客数を比較してください」
```
→ AREA_TYPE でフィルタした比較集計を自動生成
```

**Q4**: 「昼間人口比率が高いエリアほど飲料売上が多い傾向はありますか？」
```
→ 相関分析のSQLを自動生成（Show SQL で確認できます）
```

> 「Show SQL」ボタンで生成されたSQLを確認してみましょう。自分が書くべきだったSQLが確認できます。

### 講師ポイント

- 「SYNONYMS に日本語を定義しておくと、日本語の質問でも正しく解釈されます」
- 「BIツール不要、SQLスキル不要。データを組織全体で民主化する仕組みです」
- 「AWSでいえば QuickSight Q に近いですが、Snowflake はBI追加契約なしでネイティブに使えます」

---

# Scene 4: Cortex Agent — AIエージェントで出店先を決める（23分）

> **ゴール**: データ分析（Cortex Analyst）と文書検索（Cortex Search）を統合した  
> AIエージェントを作り、「次にどこに出店すべきか」を引き出す

### 講師トーク

> 「Scene 1〜3 でバラバラに使った AI 機能を、今度は一つのエージェントに統合します。
> エージェントは質問を受けると、データを調べるべきか文書を検索すべきかを自律的に判断して回答を組み立てます。
> AWSでいえば Bedrock Agents のオーケストレーション実装ですが、Snowflake では SQL 数行で作れます。」

## Step 4-1: Cortex Agent の作成

```sql
CREATE OR REPLACE CORTEX AGENT SNOWMART_AGENT
    TOOLS = (
        ANALYST_TOOL (
            SEMANTIC_VIEW = SNOWMART_DB.SNOWMART_SCHEMA.SNOWMART_ANALYSIS,
            DESCRIPTION = 'スノーマートの店舗売上・エリア・競合データを分析します。売上、来客数、競合状況などの定量的な質問に使います。'
        ),
        SEARCH_TOOL (
            CORTEX_SEARCH_SERVICE = SNOWMART_DB.SNOWMART_SCHEMA.SNOWMART_DOC_SEARCH,
            DESCRIPTION = '出店ガイドラインや社内方針の文書を検索します。立地条件、競合対策、売上目標などの方針的な質問に使います。'
        )
    )
    INSTRUCTION = '
あなたはスノーマート（全国500店舗のコンビニチェーン）の出店戦略アナリストAIです。
データ分析が必要な質問は ANALYST_TOOL を、方針・ガイドラインの質問は SEARCH_TOOL を使ってください。
複合的な判断が必要な場合は両方のツールを組み合わせてください。
回答は日本語で、具体的な数値や根拠を含めてください。
';
```

## Step 4-2: Snowflake Intelligence で対話する

Snowsight 左メニュー → **AI & ML** → **Snowflake Intelligence** を開き、`SNOWMART_AGENT` を選択します。

**質問 1（データ確認）**:
```
売上が最も高い都道府県TOP5と、その平均日販を教えてください
```
> エージェントが ANALYST_TOOL を使って集計します。  
> 「どのツールを使ったか」が Thinking プロセスに表示されます。

**質問 2（出店チャンスを探す）**:
```
競合店舗数が少なく、人口が多いエリアはどこですか？出店チャンスが高そうなエリアをTOP5で教えてください
```
> ANALYST_TOOL で競合数・人口データを分析します。

**質問 3（ガイドラインと照合）**:
```
先ほどの候補エリアについて、出店ガイドラインの条件を満たしているか確認してください
```
> エージェントが ANALYST_TOOL（データ）と SEARCH_TOOL（ガイドライン）を **自律的に組み合わせて** 回答します。  
> これがエージェントの真価です。

**質問 4（リスク確認）**:
```
候補エリアで注意すべき回避条件や競合チェーンの特徴をガイドラインから教えてください
```
> SEARCH_TOOL が競合対策・回避条件の文書を検索します。

**質問 5（最終提案）**:
```
以上の分析をまとめて、次の出店先として最もお勧めのエリアを1つ挙げ、
データによる根拠とガイドラインへの適合性の両方から理由を説明してください
```
> データ ＋ ガイドライン を統合した最終提案が生成されます。

### 講師ポイント

- 「エージェントは質問の内容から『データが必要か』『文書が必要か』を自律的に判断します」
- 「Thinking プロセスで AI の推論過程が可視化されます。なぜその答えを出したか追跡できます」
- 「AWSだと Bedrock Agents + OpenSearch + Lambda の統合実装が必要なところが、SQL数行で完結」
- 「REST API でも呼び出せるので、社内Webアプリや Slack Bot への組み込みも可能です」

---

# まとめ（5分）

## 今日体験したSnowflake AI機能

**Cortex AI Functions**（Scene 1）

- `SENTIMENT()` — 感情スコア → AWS Amazon Comprehend 相当
- `SUMMARIZE()` — 長文要約 → Bedrock + Lambda 相当
- `CLASSIFY_TEXT()` — テキスト分類 → Comprehend Custom Classifier 相当
- `COMPLETE()` — LLM呼び出し・テキスト生成 → Bedrock API 相当

共通の強み: SQL一行、APIキー不要、データ外部流出なし

**Cortex Search**（Scene 2）

- 文書をテーブルに入れるだけで RAG 基盤が完成
- AWS: Bedrock Knowledge Base + OpenSearch Serverless 相当

**Semantic View + Cortex Analyst**（Scene 3）

- 自然言語 → SQL自動生成でデータ分析
- AWS: QuickSight Q 相当（BI追加契約不要）

**Cortex Agent**（Scene 4）

- 複数AIツールを自律的にオーケストレーション
- AWS: Bedrock Agents 相当

## すべてSnowflakeの中で完結する理由

- データが外部に出ない（セキュリティ・コンプライアンス）
- SQLとPythonだけで書ける（既存スキルがそのまま使える）
- インフラ管理ゼロ（デプロイ不要）
- データ基盤 → AI分析 → RAG → エージェント → ダッシュボードまで1プラットフォーム

## 次に試すとよい機能

- `AI_EXTRACT()` — 非構造化テキストから構造化データを抽出
- `TRANSLATE()` — 多言語対応（英語レビューの日本語変換等）
- **Snowflake Notebooks** — Jupyter互換のノートブックで Snowpark Python + AI を組み合わせ
- **Cortex Fine-tuning** — 自社データでLLMをファインチューニング

---

# Scene 5: Streamlit ダッシュボード [オプション +10分]

> **ゴール**: 分析結果をインタラクティブなダッシュボードにして非エンジニアにも使えるようにする

### 講師トーク

> 「経営層への出店提案にはビジュアルが必要ですね。
> Streamlit in Snowflake を使えば、追加サービスなしでデータアプリが作れます。
> AWSでいえば EC2 でFlaskをホストする構成が不要になります。」

## アプリ作成手順

Snowsight 左メニュー → **Projects** → **Streamlit** → **+ Streamlit App**

- App name: `SNOWMART_DASHBOARD`
- Database: `SNOWMART_DB` / Schema: `SNOWMART_SCHEMA`
- Warehouse: `COMPUTE_WH`

「Create」後、以下のコードを貼り付けて **Run** します:

```python
import streamlit as st
from snowflake.snowpark.context import get_active_session

session = get_active_session()

st.title("スノーマート 出店戦略ダッシュボード")

tab1, tab2, tab3 = st.tabs(["エリア別売上", "AI レビュー分析", "出店チャンス"])

# ── Tab 1: エリア別売上 ──────────────────────────────────
with tab1:
    st.subheader("都道府県別 平均日次売上")
    df = session.sql("""
        SELECT PREFECTURE,
               ROUND(AVG(SALES_AMOUNT)) AS AVG_DAILY_SALES,
               COUNT(DISTINCT STORE_ID) AS STORES
        FROM STORE_SALES_ANALYSIS
        GROUP BY PREFECTURE ORDER BY AVG_DAILY_SALES DESC LIMIT 15
    """).to_pandas()
    kpi1, kpi2 = st.columns(2)
    kpi1.metric("全国平均日販", f"¥{int(df['AVG_DAILY_SALES'].mean()):,}")
    kpi2.metric("集計店舗数",   f"{df['STORES'].sum()} 店")
    st.bar_chart(df.set_index("PREFECTURE")["AVG_DAILY_SALES"])
    st.dataframe(df, use_container_width=True)

# ── Tab 2: AI レビュー分析 ───────────────────────────────
with tab2:
    st.subheader("Cortex AI による感情スコア分析")
    if st.button("感情分析を実行（約30秒）"):
        with st.spinner("Cortex AI Functions で分析中..."):
            df2 = session.sql("""
                SELECT cr.STORE_ID, st.STORE_NAME, st.PREFECTURE,
                       COUNT(*) AS CNT,
                       ROUND(AVG(cr.RATING), 1) AS AVG_RATING,
                       ROUND(AVG(SNOWFLAKE.CORTEX.SENTIMENT(cr.REVIEW_TEXT)), 3) AS AVG_SENTIMENT
                FROM CUSTOMER_REVIEWS cr
                JOIN SNOWMART_STORES st ON cr.STORE_ID = st.STORE_ID
                GROUP BY cr.STORE_ID, st.STORE_NAME, st.PREFECTURE
                HAVING COUNT(*) >= 3 ORDER BY AVG_SENTIMENT ASC LIMIT 15
            """).to_pandas()
        st.bar_chart(df2.set_index("STORE_NAME")["AVG_SENTIMENT"])
        st.dataframe(df2, use_container_width=True)

# ── Tab 3: 出店チャンス ──────────────────────────────────
with tab3:
    st.subheader("出店チャンスエリア（競合少 × 人口多）")
    df3 = session.sql("""
        SELECT a.PREFECTURE, a.CITY, a.AREA_TYPE, a.POPULATION,
               COALESCE(c.CNT, 0) AS COMPETITOR_COUNT,
               ROUND(a.POPULATION / NULLIF(COALESCE(c.CNT, 0) + 1, 0)) AS SCORE
        FROM AREA_MASTER a
        LEFT JOIN (SELECT PREFECTURE, CITY, COUNT(*) AS CNT
                   FROM COMPETITOR_STORES GROUP BY PREFECTURE, CITY) c
          ON a.PREFECTURE = c.PREFECTURE AND a.CITY = c.CITY
        WHERE COALESCE(c.CNT, 0) <= 3
        ORDER BY SCORE DESC LIMIT 10
    """).to_pandas()
    if not df3.empty:
        top = df3.iloc[0]
        st.success(f"最有力候補: **{top['PREFECTURE']} {top['CITY']}** "
                   f"（{top['AREA_TYPE']} / 競合{int(top['COMPETITOR_COUNT'])}店 / 人口{int(top['POPULATION']):,}人）")
    st.dataframe(df3, use_container_width=True)

st.caption("Powered by Snowflake Cortex AI | SnowMart Data Team")
```

### 講師ポイント

- 「Tab 2 の感情分析ボタンは Scene 1 で書いたのと同じ SQL がそのまま使えます」
- 「Streamlit in Snowflake はインフラ管理ゼロ。EC2/ECS のデプロイ作業は不要です」

---

*ハンズオン資材・データ: https://github.com/sfc-gh-dmiyagawa/snowmart-handson*
