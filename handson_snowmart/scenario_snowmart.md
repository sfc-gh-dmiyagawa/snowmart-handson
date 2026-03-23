# SnowMart 出店戦略ハンズオン

## 概要

- **テーマ**: 架空コンビニチェーン「スノーマート」の出店戦略をデータで立案する
- **対象者**: AWS Jr. Champions（若手エンジニア）
- **構成**: Day 1（60分）+ Day 2（60分）※別日開催
- **環境**: 各自のSnowflakeトライアルアカウント
- **言語**: SQL・カラム名は英語、説明は日本語

## ストーリー

あなたはコンビニチェーン「**スノーマート**」のデータチームに配属された新メンバーです。
スノーマートは現在全国に500店舗を展開しており、来年度中に600店舗への拡大を計画しています。

あなたのミッションは：
- **Day 1**: データ基盤を構築し、分析できる状態にする
- **Day 2**: AIを活用して「次にどこに出店すべきか」を導き出す

---

## 事前準備（参加者向け）

### Snowflake トライアルアカウントの作成

1. https://signup.snowflake.com/ にアクセス
2. 以下の設定でアカウントを作成：
   - **Cloud Provider**: AWS
   - **Region**: Asia Pacific (Tokyo)
   - **Edition**: Enterprise（推奨）
3. メール認証を完了し、ログインできることを確認

### 確認事項

- Snowsight（Web UI）にログインできること
- ロール `ACCOUNTADMIN` が使えること
- ウェアハウス `COMPUTE_WH` が存在すること

---

# Day 1: データ基盤を構築する（60分）

> **ゴール**: CSVデータのロード、Marketplace活用、Time Travel/Clone、Warehouseパフォーマンス、Dynamic Tables によるパイプライン構築、Streamlit による可視化まで一気通貫で体験する

---

## Scene 1: ストーリー導入 & 環境セットアップ（5分）

### 講師トーク

> 「スノーマートのデータチームへようこそ。今日は60分で、データ基盤をゼロから構築します。
> AWSでいえば RDS + Glue + Athena + QuickSight に相当するものを、Snowflakeだけで作ります。」

### 実行SQL

```sql
-- ロールとウェアハウスの設定
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;

-- データベースとスキーマの作成
CREATE OR REPLACE DATABASE SNOWMART_DB;
CREATE OR REPLACE SCHEMA SNOWMART_DB.SNOWMART_SCHEMA;
USE SCHEMA SNOWMART_DB.SNOWMART_SCHEMA;

-- データロード用の内部ステージを作成
CREATE OR REPLACE STAGE SNOWMART_STAGE
  DIRECTORY = (ENABLE = TRUE)
  FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1);
```

### 講師ポイント

- 「`CREATE DATABASE` 一発でストレージもコンピュートも分離された環境ができます」
- 「AWSだとRDSインスタンス立てて、S3バケット作って...という手順が不要です」

---

## Scene 2: データロード（12分）

### 講師トーク

> 「スノーマートの業務データをロードします。自社店舗、競合情報、エリアデータ、売上、顧客レビューの5種類です。」

### Step 2-1: テーブル作成

```sql
-- 自社店舗マスタ
CREATE OR REPLACE TABLE SNOWMART_STORES (
    STORE_ID VARCHAR(10),
    STORE_NAME VARCHAR(100),
    PREFECTURE VARCHAR(20),
    CITY VARCHAR(50),
    LATITUDE FLOAT,
    LONGITUDE FLOAT,
    STORE_TYPE VARCHAR(10),
    FLOOR_AREA_SQM INT,
    OPEN_DATE DATE,
    NEAREST_STATION VARCHAR(100)
);

-- 競合店舗（公開情報のみ）
CREATE OR REPLACE TABLE COMPETITOR_STORES (
    COMPETITOR_ID VARCHAR(10),
    CHAIN_NAME VARCHAR(50),
    PREFECTURE VARCHAR(20),
    CITY VARCHAR(50),
    LATITUDE FLOAT,
    LONGITUDE FLOAT,
    FLOOR_AREA_SQM INT
);

-- エリアマスタ
CREATE OR REPLACE TABLE AREA_MASTER (
    AREA_ID VARCHAR(10),
    PREFECTURE VARCHAR(20),
    CITY VARCHAR(50),
    POPULATION INT,
    HOUSEHOLDS INT,
    DAYTIME_POPULATION_RATIO FLOAT,
    AVG_ANNUAL_INCOME INT,
    AREA_TYPE VARCHAR(20)
);

-- 日次売上データ
CREATE OR REPLACE TABLE DAILY_SALES (
    STORE_ID VARCHAR(10),
    SALES_DATE DATE,
    SALES_AMOUNT INT,
    CUSTOMER_COUNT INT,
    AVG_UNIT_PRICE FLOAT,
    FOOD_SALES INT,
    BEVERAGE_SALES INT,
    DAILY_GOODS_SALES INT
);

-- 顧客レビュー
CREATE OR REPLACE TABLE CUSTOMER_REVIEWS (
    REVIEW_ID VARCHAR(10),
    STORE_ID VARCHAR(10),
    REVIEW_DATE DATE,
    RATING INT,
    REVIEW_TEXT VARCHAR(1000),
    REVIEWER_AGE_GROUP VARCHAR(20)
);
```

### Step 2-2: ファイルアップロード & ロード

```sql
-- ============================================
-- ファイルのアップロード
-- ============================================
-- Snowsight の左メニュー > Data > Databases > SNOWMART_DB > SNOWMART_SCHEMA > Stages > SNOWMART_STAGE
-- 「+ Files」ボタンから以下のCSVファイルをアップロードしてください：
--   - snowmart_stores.csv
--   - competitor_stores.csv
--   - area_master.csv
--   - daily_sales.csv
--   - customer_reviews.csv

-- ============================================
-- COPY INTO でテーブルにロード
-- ============================================
COPY INTO SNOWMART_STORES FROM @SNOWMART_STAGE/snowmart_stores.csv FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1);
COPY INTO COMPETITOR_STORES FROM @SNOWMART_STAGE/competitor_stores.csv FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1);
COPY INTO AREA_MASTER FROM @SNOWMART_STAGE/area_master.csv FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1);
COPY INTO DAILY_SALES FROM @SNOWMART_STAGE/daily_sales.csv FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1);
COPY INTO CUSTOMER_REVIEWS FROM @SNOWMART_STAGE/customer_reviews.csv FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1);
```

### Step 2-3: データ確認

```sql
-- 各テーブルの行数を確認
SELECT 'SNOWMART_STORES' AS TABLE_NAME, COUNT(*) AS ROW_COUNT FROM SNOWMART_STORES
UNION ALL SELECT 'COMPETITOR_STORES', COUNT(*) FROM COMPETITOR_STORES
UNION ALL SELECT 'AREA_MASTER', COUNT(*) FROM AREA_MASTER
UNION ALL SELECT 'DAILY_SALES', COUNT(*) FROM DAILY_SALES
UNION ALL SELECT 'CUSTOMER_REVIEWS', COUNT(*) FROM CUSTOMER_REVIEWS;

-- 自社店舗の中身をチラ見
SELECT * FROM SNOWMART_STORES LIMIT 10;

-- 都道府県別の店舗数
SELECT PREFECTURE, COUNT(*) AS STORE_COUNT
FROM SNOWMART_STORES
GROUP BY PREFECTURE
ORDER BY STORE_COUNT DESC
LIMIT 10;
```

### 講師ポイント

- 「CSVアップロード → COPY INTO → 即クエリ。ETLパイプラインなしでここまで来ました」
- 「18万行の売上データも数秒でロードされます」

---

## Scene 3: Marketplace 体験（8分）

### 講師トーク

> 「出店戦略には天気データも重要です。雨の日は客足が減りますよね。
> このデータ、自分で集める必要はありません。Snowflake Marketplace にあります。」

### Step 3-1: Marketplace からデータを取得

1. Snowsight 左メニュー → **Marketplace**
2. 検索バーに **「Prepper Open Data Bank Japanese Weather」** と入力
3. **「Prepper Open Data Bank - Japanese Weather Data」** を選択
4. **「Get」** ボタンをクリック
5. データベース名はデフォルトのままで「Get」を確認

> **講師補足**: 「Get ボタンを押すだけです。S3からダウンロードしてロードする、みたいな作業は一切不要。
> これがSnowflakeのデータシェアリングです。コピーすら作られません。」

### Step 3-2: 天気データを確認

```sql
-- Marketplace から取得した天気データベースを確認
-- ※データベース名は取得時の名前に合わせてください
SHOW DATABASES LIKE '%WEATHER%';

-- テーブル一覧を確認
SHOW TABLES IN DATABASE PREPPER_OPEN_DATA_BANK___JAPANESE_WEATHER_DATA;

-- 天気データの中身を確認
SELECT * FROM PREPPER_OPEN_DATA_BANK___JAPANESE_WEATHER_DATA.PUBLIC.JAPANESE_WEATHER_DATA
LIMIT 10;
```

### Step 3-3: 売上 × 天気の簡単な分析

```sql
-- 天気データのカラム構造を確認してから、以下のようなJOINを試す
-- ※天気データの実際のカラム名に合わせて調整してください

-- 例: 東京の売上と天気の関係を見る
-- SELECT
--     s.SALES_DATE,
--     SUM(s.SALES_AMOUNT) AS TOTAL_SALES,
--     SUM(s.CUSTOMER_COUNT) AS TOTAL_CUSTOMERS,
--     w.PRECIPITATION,
--     w.AVG_TEMPERATURE
-- FROM DAILY_SALES s
-- JOIN SNOWMART_STORES st ON s.STORE_ID = st.STORE_ID
-- JOIN <WEATHER_TABLE> w ON s.SALES_DATE = w.DATE AND st.PREFECTURE = w.PREFECTURE
-- WHERE st.PREFECTURE = '東京都'
-- GROUP BY s.SALES_DATE, w.PRECIPITATION, w.AVG_TEMPERATURE
-- ORDER BY s.SALES_DATE;
```

### 講師ポイント

- 「Marketplace のデータは常に最新が反映されます。一度Getすれば自動更新です」
- 「AWS Data Exchange と似た概念ですが、データのコピーが不要な点が大きな違いです」

---

## Scene 4: Time Travel & Zero-Copy Clone（8分）

### 講師トーク

> 「本番運用で一番怖いのは、データの誤削除ですよね。Snowflakeなら過去に戻れます。」

### Step 4-1: Time Travel 体験

```sql
-- 現在の行数を確認
SELECT COUNT(*) FROM DAILY_SALES;

-- 「誤って」売上データを削除してしまった！
DELETE FROM DAILY_SALES WHERE SALES_DATE >= '2024-10-01';

-- やばい！データが消えた！
SELECT COUNT(*) FROM DAILY_SALES;
-- → 大幅に減っている...

-- Time Travel で120秒前のデータを確認
SELECT COUNT(*) FROM DAILY_SALES AT(OFFSET => -120);
-- → 元の行数が見える！

-- テーブルを復旧する
CREATE OR REPLACE TABLE DAILY_SALES AS
SELECT * FROM DAILY_SALES AT(OFFSET => -120);

-- 復旧完了を確認
SELECT COUNT(*) FROM DAILY_SALES;
```

### Step 4-2: Zero-Copy Clone

```sql
-- 本番DBをまるごとクローン（開発環境として使う）
CREATE OR REPLACE DATABASE SNOWMART_DB_DEV CLONE SNOWMART_DB;

-- クローンの中身を確認
SELECT COUNT(*) FROM SNOWMART_DB_DEV.SNOWMART_SCHEMA.DAILY_SALES;
-- → 本番と同じ行数！

-- ストレージ使用量を確認（追加コストゼロ）
SELECT TABLE_NAME, BYTES, ROW_COUNT
FROM SNOWMART_DB_DEV.INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'SNOWMART_SCHEMA';
```

### 講師ポイント

- 「Time Travel はデフォルトで過去1日分。Enterprise Editionなら90日まで拡張可能」
- 「Clone は**メタデータのコピーだけ**なので、500GBのDBでも一瞬。ストレージ追加ゼロ」
- 「AWSだとRDSスナップショット→リストアで数十分かかるものが、数秒です」

---

## Scene 5: Warehouse パフォーマンス（5分）

### 講師トーク

> 「Snowflakeはコンピュートとストレージが分離しています。ウェアハウスのサイズを変えるだけで、クエリが速くなります。」

### Step 5-1: XS で重いクエリを実行

```sql
-- XS ウェアハウスで実行
ALTER WAREHOUSE COMPUTE_WH SET WAREHOUSE_SIZE = 'XSMALL';

-- 全店舗の月次サマリーを計算（少し重めのクエリ）
SELECT
    st.PREFECTURE,
    st.STORE_TYPE,
    DATE_TRUNC('MONTH', s.SALES_DATE) AS SALES_MONTH,
    COUNT(DISTINCT s.STORE_ID) AS STORE_COUNT,
    SUM(s.SALES_AMOUNT) AS TOTAL_SALES,
    SUM(s.CUSTOMER_COUNT) AS TOTAL_CUSTOMERS,
    AVG(s.AVG_UNIT_PRICE) AS AVG_PRICE,
    SUM(s.FOOD_SALES) AS TOTAL_FOOD,
    SUM(s.BEVERAGE_SALES) AS TOTAL_BEVERAGE,
    SUM(s.DAILY_GOODS_SALES) AS TOTAL_DAILY_GOODS
FROM DAILY_SALES s
JOIN SNOWMART_STORES st ON s.STORE_ID = st.STORE_ID
JOIN AREA_MASTER a ON st.PREFECTURE = a.PREFECTURE AND st.CITY = a.CITY
GROUP BY st.PREFECTURE, st.STORE_TYPE, DATE_TRUNC('MONTH', s.SALES_DATE)
ORDER BY TOTAL_SALES DESC;
-- → 実行時間を確認（Query Profile で確認）
```

### Step 5-2: M にサイズアップして再実行

```sql
-- Medium にサイズアップ（数秒で完了）
ALTER WAREHOUSE COMPUTE_WH SET WAREHOUSE_SIZE = 'MEDIUM';

-- 同じクエリを再実行
SELECT
    st.PREFECTURE,
    st.STORE_TYPE,
    DATE_TRUNC('MONTH', s.SALES_DATE) AS SALES_MONTH,
    COUNT(DISTINCT s.STORE_ID) AS STORE_COUNT,
    SUM(s.SALES_AMOUNT) AS TOTAL_SALES,
    SUM(s.CUSTOMER_COUNT) AS TOTAL_CUSTOMERS,
    AVG(s.AVG_UNIT_PRICE) AS AVG_PRICE,
    SUM(s.FOOD_SALES) AS TOTAL_FOOD,
    SUM(s.BEVERAGE_SALES) AS TOTAL_BEVERAGE,
    SUM(s.DAILY_GOODS_SALES) AS TOTAL_DAILY_GOODS
FROM DAILY_SALES s
JOIN SNOWMART_STORES st ON s.STORE_ID = st.STORE_ID
JOIN AREA_MASTER a ON st.PREFECTURE = a.PREFECTURE AND st.CITY = a.CITY
GROUP BY st.PREFECTURE, st.STORE_TYPE, DATE_TRUNC('MONTH', s.SALES_DATE)
ORDER BY TOTAL_SALES DESC;
-- → XS のときより速い！
```

```sql
-- 使い終わったらXSに戻す（コスト節約）
ALTER WAREHOUSE COMPUTE_WH SET WAREHOUSE_SIZE = 'XSMALL';
```

### 講師ポイント

- 「サイズ変更はオンラインで即座。再起動不要です」
- 「XS→Mで4倍のコンピュートリソース。料金も4倍ですが、処理が速い分すぐ終わるのでコスト効率は同等」
- 「AWSでいえば、EC2のインスタンスタイプをダウンタイムなしで変更できるイメージです」
- 「Query Profile を開くと、どこに時間がかかったか可視化できます」

---

## Scene 6: Dynamic Tables でパイプライン構築（8分）

### 講師トーク

> 「分析用のサマリーテーブルを作りたい場合、普通はETLジョブを書きますよね。
> Snowflake の Dynamic Tables なら、SELECT文を書くだけで自動更新パイプラインが完成します。」

### Step 6-1: Dynamic Table の作成

```sql
USE SCHEMA SNOWMART_DB.SNOWMART_SCHEMA;

-- 店舗 × エリア × 売上 を結合した分析用テーブル
CREATE OR REPLACE DYNAMIC TABLE STORE_SALES_ANALYSIS
    TARGET_LAG = '1 hour'
    WAREHOUSE = COMPUTE_WH
AS
SELECT
    s.STORE_ID,
    st.STORE_NAME,
    st.PREFECTURE,
    st.CITY,
    st.STORE_TYPE,
    st.FLOOR_AREA_SQM,
    st.NEAREST_STATION,
    a.POPULATION,
    a.DAYTIME_POPULATION_RATIO,
    a.AVG_ANNUAL_INCOME,
    a.AREA_TYPE,
    s.SALES_DATE,
    s.SALES_AMOUNT,
    s.CUSTOMER_COUNT,
    s.AVG_UNIT_PRICE,
    s.FOOD_SALES,
    s.BEVERAGE_SALES,
    s.DAILY_GOODS_SALES
FROM DAILY_SALES s
JOIN SNOWMART_STORES st ON s.STORE_ID = st.STORE_ID
LEFT JOIN AREA_MASTER a ON st.PREFECTURE = a.PREFECTURE AND st.CITY = a.CITY;
```

### Step 6-2: 動作確認

```sql
-- Dynamic Table の状態を確認
SHOW DYNAMIC TABLES LIKE 'STORE_SALES_ANALYSIS';

-- データを確認（自動的にリフレッシュされる）
SELECT * FROM STORE_SALES_ANALYSIS LIMIT 10;

-- このテーブルを使って分析
SELECT
    PREFECTURE,
    AREA_TYPE,
    COUNT(DISTINCT STORE_ID) AS STORE_COUNT,
    ROUND(AVG(SALES_AMOUNT)) AS AVG_DAILY_SALES,
    ROUND(AVG(CUSTOMER_COUNT)) AS AVG_DAILY_CUSTOMERS
FROM STORE_SALES_ANALYSIS
GROUP BY PREFECTURE, AREA_TYPE
ORDER BY AVG_DAILY_SALES DESC
LIMIT 20;
```

### 講師ポイント

- 「SELECT文を書いただけで、自動更新されるパイプラインが完成しました」
- 「`TARGET_LAG = '1 hour'` は『元データが変わったら1時間以内に反映する』という意味」
- 「AWS Glue のジョブ定義 + CloudWatch スケジューラ + S3出力 をこの1文で代替しています」

---

## Scene 7: Streamlit で可視化 + Cortex Code でブラッシュアップ（10分）

### 講師トーク

> 「ここまでのデータを、ダッシュボードで可視化しましょう。
> Snowflake 上で直接 Streamlit アプリをデプロイできます。さらに、AIの力でコードを改善します。」

### Step 7-1: Streamlit in Snowflake のデプロイ

1. Snowsight 左メニュー → **Projects** → **Streamlit**
2. **「+ Streamlit App」** をクリック
3. 以下を設定：
   - **App name**: `SNOWMART_DASHBOARD`
   - **Warehouse**: `COMPUTE_WH`
   - **Database**: `SNOWMART_DB`
   - **Schema**: `SNOWMART_SCHEMA`
4. 「Create」をクリック

### Step 7-2: ベースコードを貼り付け

エディタに以下のベースコードを貼り付けてください：

```python
import streamlit as st
from snowflake.snowpark.context import get_active_session

st.set_page_config(page_title="SnowMart Dashboard", layout="wide")
st.title("SnowMart 店舗分析ダッシュボード")

session = get_active_session()

# 都道府県別の売上サマリー
df_pref = session.sql("""
    SELECT
        PREFECTURE,
        COUNT(DISTINCT STORE_ID) AS STORE_COUNT,
        ROUND(AVG(SALES_AMOUNT)) AS AVG_DAILY_SALES,
        SUM(SALES_AMOUNT) AS TOTAL_SALES
    FROM STORE_SALES_ANALYSIS
    GROUP BY PREFECTURE
    ORDER BY TOTAL_SALES DESC
    LIMIT 15
""").to_pandas()

st.subheader("都道府県別 売上サマリー（上位15）")
st.bar_chart(df_pref.set_index("PREFECTURE")["TOTAL_SALES"])

# 月次トレンド
df_monthly = session.sql("""
    SELECT
        DATE_TRUNC('MONTH', SALES_DATE) AS MONTH,
        SUM(SALES_AMOUNT) AS TOTAL_SALES,
        SUM(CUSTOMER_COUNT) AS TOTAL_CUSTOMERS
    FROM STORE_SALES_ANALYSIS
    GROUP BY MONTH
    ORDER BY MONTH
""").to_pandas()

st.subheader("月次売上トレンド")
st.line_chart(df_monthly.set_index("MONTH")["TOTAL_SALES"])
```

5. **「Run」** ボタンをクリックしてアプリを実行

### Step 7-3: Cortex Code in Snowsight でブラッシュアップ

Streamlit エディタの **AI アシスタント**（Cortex）を使って、アプリを改善します。

以下のようなプロンプトを試してください：

**プロンプト例 1**: 
> 「都道府県でフィルタリングできるセレクトボックスを追加してください」

**プロンプト例 2**: 
> 「エリアタイプ別の平均売上を横棒グラフで追加してください」

**プロンプト例 3**: 
> 「店舗タイプ（直営/FC）の売上比較をメトリクスカードで表示してください」

### 講師ポイント

- 「Streamlit in Snowflake はデータが外に出ません。ガバナンスが保たれたまま可視化できます」
- 「AIにコードを書かせることで、Streamlit の経験がなくてもダッシュボードが作れます」
- 「QuickSight や Tableau なしで、コードベースのダッシュボードが即デプロイ可能です」

---

## Scene 8: Day 1 まとめ & Day 2 予告（4分）

### 講師トーク

> 「60分で何をやったか振り返りましょう：
> 
> 1. データベース作成 → データロード
> 2. Marketplace から天気データを即取得
> 3. Time Travel でデータ復旧、Clone で開発環境を一瞬で作成
> 4. Warehouse のサイズ変更でパフォーマンスチューニング
> 5. Dynamic Tables で自動更新パイプライン
> 6. Streamlit + AI でダッシュボード構築
> 
> AWS でこれと同等のことをやろうとすると、RDS + S3 + Glue + Athena + Data Exchange + QuickSight + ... と複数サービスの組み合わせが必要です。
> Snowflake はこれがオールインワンで、しかもコンピュートとストレージが分離されています。
> 
> **次回予告**: Day 2 では、このデータに AI を載せます。
> 顧客レビューの感情分析、社内ドキュメント検索、そしてAIエージェントに『どこに出店すべきか？』を聞きます。」

---

# Day 2: AI で出店戦略を立てる（60分）

> **ゴール**: Cortex AI Functions、Cortex Search、Cortex Agent を使い、AIの力で出店戦略を導き出す。Cortex Code でデータ分析を体験する。

---

## Scene 1: 振り返り & 動作確認（5分）

### 講師トーク

> 「Day 1 で構築したデータ基盤を使って、今日は AI の力で出店戦略を立てます。
> まずはデータが残っているか確認しましょう。」

### 実行SQL

```sql
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;
USE SCHEMA SNOWMART_DB.SNOWMART_SCHEMA;

-- データの確認
SELECT 'SNOWMART_STORES' AS TBL, COUNT(*) AS CNT FROM SNOWMART_STORES
UNION ALL SELECT 'DAILY_SALES', COUNT(*) FROM DAILY_SALES
UNION ALL SELECT 'CUSTOMER_REVIEWS', COUNT(*) FROM CUSTOMER_REVIEWS
UNION ALL SELECT 'STORE_SALES_ANALYSIS', COUNT(*) FROM STORE_SALES_ANALYSIS;
```

### 講師ポイント

- 「Dynamic Table が自動リフレッシュされているか確認。Snowflakeが勝手にやってくれています」

---

## Scene 2: Cortex AI Functions — レビュー分析（15分）

### 講師トーク

> 「500件の顧客レビューがあります。全部読むのは大変ですよね。
> Snowflake の Cortex AI Functions を使えば、SQL一行で感情分析・要約・分類ができます。」

### Step 2-1: 感情分析（SENTIMENT）

```sql
-- レビューの感情スコアを計算（-1: ネガティブ 〜 +1: ポジティブ）
SELECT
    REVIEW_ID,
    STORE_ID,
    RATING,
    REVIEW_TEXT,
    SNOWFLAKE.CORTEX.SENTIMENT(REVIEW_TEXT) AS SENTIMENT_SCORE
FROM CUSTOMER_REVIEWS
ORDER BY SENTIMENT_SCORE ASC
LIMIT 20;
```

```sql
-- 店舗別の平均感情スコア（低い店舗に課題あり）
SELECT
    cr.STORE_ID,
    st.STORE_NAME,
    st.PREFECTURE,
    COUNT(*) AS REVIEW_COUNT,
    ROUND(AVG(cr.RATING), 1) AS AVG_RATING,
    ROUND(AVG(SNOWFLAKE.CORTEX.SENTIMENT(cr.REVIEW_TEXT)), 3) AS AVG_SENTIMENT
FROM CUSTOMER_REVIEWS cr
JOIN SNOWMART_STORES st ON cr.STORE_ID = st.STORE_ID
GROUP BY cr.STORE_ID, st.STORE_NAME, st.PREFECTURE
HAVING COUNT(*) >= 3
ORDER BY AVG_SENTIMENT ASC
LIMIT 10;
```

### Step 2-2: テキスト要約（SUMMARIZE）

```sql
-- ネガティブレビューをまとめて要約
SELECT SNOWFLAKE.CORTEX.SUMMARIZE(
    ARRAY_TO_STRING(
        ARRAY_AGG(REVIEW_TEXT) WITHIN GROUP (ORDER BY RATING ASC),
        '\n'
    )
) AS NEGATIVE_REVIEW_SUMMARY
FROM CUSTOMER_REVIEWS
WHERE RATING <= 2;
```

### Step 2-3: テキスト分類（CLASSIFY_TEXT）

```sql
-- レビューをカテゴリに自動分類
SELECT
    REVIEW_ID,
    REVIEW_TEXT,
    SNOWFLAKE.CORTEX.CLASSIFY_TEXT(
        REVIEW_TEXT,
        ['接客・サービス', '品揃え・商品', '立地・アクセス', '店内環境・清潔さ', '価格']
    ) AS CATEGORY
FROM CUSTOMER_REVIEWS
LIMIT 20;
```

### 講師ポイント

- 「`SNOWFLAKE.CORTEX.SENTIMENT()` — SQL一行で感情分析。Python不要、APIキー不要」
- 「これらはすべてSnowflake内で処理されます。データが外部に出ません」
- 「AWSだと Comprehend + Lambda + API Gateway の構成が必要になるところです」

---

## Scene 3: Cortex Search — 社内ナレッジ検索（10分）

### 講師トーク

> 「スノーマートには出店ガイドラインという社内文書があります。
> 『駅前出店の条件は？』と聞いたら、文書から関連箇所を見つけて答えてくれる仕組みを作りましょう。」

### Step 3-1: ガイドライン文書をテーブルに格納

```sql
-- ドキュメント格納用テーブル
CREATE OR REPLACE TABLE STORE_DOCUMENTS (
    DOC_ID VARCHAR(10),
    DOC_TITLE VARCHAR(200),
    DOC_SECTION VARCHAR(200),
    DOC_TEXT VARCHAR(5000)
);

-- 出店ガイドラインの主要セクションを挿入
INSERT INTO STORE_DOCUMENTS VALUES
('D001', '出店ガイドライン', '立地選定基準 - 必須条件',
 '最寄り駅から徒歩5分以内、または主要道路沿いで車のアクセスが良いこと。商圏人口（半径500m）が5,000人以上であること。店舗面積として最低60平方メートルを確保できること。24時間営業が可能な立地条件であること。'),
('D002', '出店ガイドライン', '立地選定基準 - 推奨条件',
 '昼間人口比率が1.2以上のエリアは弁当・飲料カテゴリの売上が高い傾向にある。大学や専門学校の半径1km以内は若年層の集客が見込める。病院・公共施設の近隣は安定した集客が期待できる。住宅地の場合、世帯数が3,000以上のエリアを優先する。'),
('D003', '出店ガイドライン', '競合分析の指針',
 '低密度エリア（半径500m内に競合0〜1店）は出店優先度が高い。中密度エリア（競合2〜3店）は差別化戦略が必要。高密度エリア（競合4店以上）は原則として出店を見送る。ただし駅直結や大型商業施設内など圧倒的優位性がある場合は例外とする。'),
('D004', '出店ガイドライン', '回避条件',
 '半径300m以内にスノーマートの既存店舗がある場合は原則出店しない。半径500m以内に競合コンビニが5店舗以上ある場合は差別化要因が明確でない限り出店を見送る。過去3年以内にコンビニの閉店が2件以上あったエリアは要注意とする。'),
('D005', '出店ガイドライン', '売上目標の目安',
 '都心商業地は日販50万円以上を目標。都心オフィス街は日販45万円以上。郊外住宅地は日販30万円以上。郊外ロードサイドは日販35万円以上。月間売上が800万円を下回る場合、3ヶ月連続で改善計画を策定する。'),
('D006', '出店ガイドライン', '天候・季節要因への対応',
 '梅雨時期は来客数が平均10〜15%減少するが客単価は上昇する傾向。夏季は飲料・アイスの売上が年間平均の1.5倍。冬季はおでん・中華まん等のFF売上が増加。台風・大雪時は来客数が50%以上減少する場合あり。'),
('D007', '出店ガイドライン', '2024年度の戦略変更点',
 'EC連携として店舗受取サービスの需要増に対応し宅配ボックス設置スペースの確保を推奨。省人化としてセルフレジ導入を標準化、新規出店は原則セルフレジ2台以上を設置。フードロス削減のためAIによる需要予測システムの導入を全店で推進中。'),
('D008', '出店ガイドライン', '競合チェーン別の特徴',
 'セブン-イレブンはPB商品が強く品質重視の顧客層。ファミリーマートはファストフードが強く若年層に人気。ローソンはスイーツ・ヘルシー系に強く女性客比率が高い。上記チェーンが手薄なカテゴリで差別化を図ることが重要。');
```

### Step 3-2: Cortex Search Service の作成

```sql
-- Cortex Search Service を作成
CREATE OR REPLACE CORTEX SEARCH SERVICE SNOWMART_DOC_SEARCH
    ON DOC_TEXT
    ATTRIBUTES DOC_TITLE, DOC_SECTION
    WAREHOUSE = COMPUTE_WH
    TARGET_LAG = '1 hour'
    AS (
        SELECT
            DOC_ID,
            DOC_TITLE,
            DOC_SECTION,
            DOC_TEXT
        FROM STORE_DOCUMENTS
    );
```

### Step 3-3: 検索テスト

```sql
-- 「駅前の出店条件」を検索
SELECT PARSE_JSON(
    SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
        'SNOWMART_DB.SNOWMART_SCHEMA.SNOWMART_DOC_SEARCH',
        '{
            "query": "駅前に出店する場合の条件は何ですか？",
            "columns": ["DOC_SECTION", "DOC_TEXT"],
            "limit": 3
        }'
    )
) AS SEARCH_RESULTS;

-- 「競合が多いエリアでの戦略」を検索
SELECT PARSE_JSON(
    SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
        'SNOWMART_DB.SNOWMART_SCHEMA.SNOWMART_DOC_SEARCH',
        '{
            "query": "競合が多いエリアではどうすればいいですか？",
            "columns": ["DOC_SECTION", "DOC_TEXT"],
            "limit": 3
        }'
    )
) AS SEARCH_RESULTS;
```

### 講師ポイント

- 「社内文書を入れるだけで、自然言語で検索できるRAG基盤が完成しました」
- 「ベクトル検索を自動で行ってくれるので、Embedding モデルの選定やインデックス管理が不要です」
- 「AWSだと Bedrock Knowledge Base + OpenSearch Serverless の構成に相当します」

---

## Scene 4: Cortex Agent / Snowflake Intelligence（15分）

### 講師トーク

> 「いよいよ最終兵器、AIエージェントの登場です。
> 売上データの分析（Cortex Analyst）と社内文書の検索（Cortex Search）を統合して、
> 自然言語で『どこに出店すべきか？』と聞けるエージェントを作ります。」

### Step 4-1: Semantic View の作成（Cortex Analyst 用）

```sql
-- Cortex Analyst 用の Semantic View を作成
-- ※ Semantic View は Snowsight UI から作成することも可能です

CREATE OR REPLACE SEMANTIC VIEW SNOWMART_DB.SNOWMART_SCHEMA.SNOWMART_SEMANTIC_VIEW
  AS SEMANTIC MODEL YAML $$
semantic_model:
  name: snowmart_analysis
  description: "スノーマートの店舗・売上・エリア分析用セマンティックモデル"

  tables:
    - name: store_sales_analysis
      base_table:
        database: SNOWMART_DB
        schema: SNOWMART_SCHEMA
        table: STORE_SALES_ANALYSIS
      dimensions:
        - name: store_id
          expr: STORE_ID
          description: "店舗ID"
        - name: store_name
          expr: STORE_NAME
          description: "店舗名"
        - name: prefecture
          expr: PREFECTURE
          description: "都道府県"
        - name: city
          expr: CITY
          description: "市区町村"
        - name: store_type
          expr: STORE_TYPE
          description: "店舗タイプ（直営 or FC）"
        - name: area_type
          expr: AREA_TYPE
          description: "エリアタイプ（商業地、住宅地、オフィス街、郊外、駅前繁華街）"
        - name: nearest_station
          expr: NEAREST_STATION
          description: "最寄り駅"
        - name: sales_date
          expr: SALES_DATE
          description: "売上日"
      measures:
        - name: total_sales
          expr: SUM(SALES_AMOUNT)
          description: "売上合計"
        - name: total_customers
          expr: SUM(CUSTOMER_COUNT)
          description: "来客数合計"
        - name: avg_unit_price
          expr: AVG(AVG_UNIT_PRICE)
          description: "平均客単価"
        - name: avg_daily_sales
          expr: AVG(SALES_AMOUNT)
          description: "平均日販"
        - name: total_food_sales
          expr: SUM(FOOD_SALES)
          description: "食品売上合計"
        - name: total_beverage_sales
          expr: SUM(BEVERAGE_SALES)
          description: "飲料売上合計"
        - name: store_count
          expr: COUNT(DISTINCT STORE_ID)
          description: "店舗数"
        - name: population
          expr: MAX(POPULATION)
          description: "エリア人口"
        - name: daytime_pop_ratio
          expr: MAX(DAYTIME_POPULATION_RATIO)
          description: "昼間人口比率"
        - name: avg_income
          expr: MAX(AVG_ANNUAL_INCOME)
          description: "平均年収"
        - name: floor_area
          expr: AVG(FLOOR_AREA_SQM)
          description: "平均売場面積"
$$;
```

### Step 4-2: Cortex Agent の作成

```sql
CREATE OR REPLACE CORTEX AGENT SNOWMART_AGENT
  COMMENT = 'スノーマート出店戦略AIエージェント'
FROM SPECIFICATION $$
models:
  orchestration: auto

instructions:
  system: |
    あなたはスノーマート（コンビニチェーン）の出店戦略アドバイザーです。
    売上データ、エリア情報、競合情報、社内ガイドラインを横断的に活用して、
    出店戦略に関する質問に答えてください。日本語で回答してください。
  orchestration: |
    売上や店舗の数値に関する質問は Analyst ツールを使ってください。
    出店基準や社内ルールに関する質問は Search ツールを使ってください。
    出店戦略の提案では、両方のツールを組み合わせて根拠のある回答をしてください。
  response: |
    常に具体的な数値やデータに基づいて回答してください。
    回答は簡潔に、箇条書きを活用してください。

tools:
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: Analyst
      description: "売上データ、店舗情報、エリア情報を分析するツール"
  - tool_spec:
      type: cortex_search
      name: DocSearch
      description: "出店ガイドライン等の社内文書を検索するツール"
  - tool_spec:
      type: data_to_chart
      name: data_to_chart
      description: "データをチャートで可視化するツール"

tool_resources:
  Analyst:
    semantic_view: "SNOWMART_DB.SNOWMART_SCHEMA.SNOWMART_SEMANTIC_VIEW"
  DocSearch:
    name: "SNOWMART_DB.SNOWMART_SCHEMA.SNOWMART_DOC_SEARCH"
    max_results: "5"
$$;
```

### Step 4-3: エージェントと対話（Snowflake Intelligence）

1. Snowsight 左メニュー → **AI & ML** → **Cortex Agent**
2. **SNOWMART_AGENT** を選択
3. 以下の質問を試す：

**質問例 1（データ分析）**:
> 「売上トップ10の店舗を教えてください。共通する特徴はありますか？」

**質問例 2（天候影響）**:
> 「都道府県別の平均日販を比較してください」

**質問例 3（ガイドライン参照）**:
> 「競合が3店以上あるエリアに出店する場合、何に注意すべきですか？」

**質問例 4（出店提案 — 横断回答）**:
> 「横浜市に新規出店するとしたら、どのエリアタイプが最適ですか？根拠も含めて教えてください」

### 講師ポイント

- 「構造化データ（SQL）と非構造化データ（文書検索）を1つのエージェントが横断して回答」
- 「Text-to-SQL + RAG + チャート生成がオールインワン」
- 「質問に応じてエージェントが自動的にツールを選択・組み合わせている点に注目」

---

## Scene 5: Cortex Code でデータ分析（10分）

### 講師トーク

> 「最後に、Cortex Code を使ったデータ分析を体験します。
> 自然言語で指示するだけで、SQLを書いて実行し、結果を解釈してくれます。」

### Step 5-1: Cortex Code in Snowsight を開く

1. Snowsight の **SQL Worksheet** を開く
2. AI アシスタント（Cortex）を使って以下を試す

### Step 5-2: 分析プロンプトを試す

以下のプロンプトをAIアシスタントに入力してみてください：

**プロンプト 1（探索的分析）**:
> 「STORE_SALES_ANALYSIS テーブルを使って、直営店とFC店の売上パフォーマンスを比較するクエリを書いてください」

**プロンプト 2（異常値検出）**:
> 「日販が極端に低い店舗を特定するクエリを書いてください。月別の推移も見たいです」

**プロンプト 3（出店候補分析）**:
> 「COMPETITOR_STORES と AREA_MASTER を使って、競合が少なく人口が多いエリアを見つけるクエリを書いてください」

### 講師ポイント

- 「SQLの文法を覚えていなくても、やりたいことを自然言語で伝えればOK」
- 「生成されたSQLを確認・修正してから実行できるので、安全です」
- 「GitHub Copilot のSQL版、というイメージです」

---

## Scene 6: まとめ & 次のステップ（5分）

### 講師トーク

> 「2日間のハンズオンお疲れさまでした。振り返りましょう：
> 
> **Day 1 でやったこと：**
> - データベース構築 & CSVロード
> - Marketplace から外部データを即取得
> - Time Travel & Clone で安全なデータ管理
> - Warehouse サイズ変更でパフォーマンス調整
> - Dynamic Tables で自動更新パイプライン
> - Streamlit でダッシュボード構築（AIでコード改善）
> 
> **Day 2 でやったこと：**
> - Cortex AI Functions でレビューの感情分析・要約・分類
> - Cortex Search で社内文書の自然言語検索（RAG）
> - Cortex Agent で全データソースを横断するAIエージェント
> - Cortex Code でAI駆動のデータ分析
> 
> **まとめ：**
> Snowflake は単なるデータベースではなく、データ基盤からAI活用までをカバーするプラットフォームです。
> AWSのサービスでいえば、RDS + S3 + Glue + Athena + Data Exchange + SageMaker + Bedrock + QuickSight に相当する機能が、1つのプラットフォームに統合されています。
> 
> そして今日使った全ての機能は、データがSnowflakeの外に出ることなく動作しています。
> ガバナンスとセキュリティが保たれたまま、AIを活用できる。これがSnowflakeの強みです。」

### 参考リンク

- Snowflake 公式ドキュメント: https://docs.snowflake.com/
- Cortex AI Functions: https://docs.snowflake.com/en/user-guide/snowflake-cortex/llm-functions
- Cortex Agents: https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents
- Snowflake Marketplace: https://app.snowflake.com/marketplace
- Cortex Code CLI: https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code

---

## 付録A: トラブルシューティング

### よくある問題

**Q: COPY INTO でエラーが出る**
- ファイルのエンコーディングが UTF-8 であることを確認
- ヘッダー行のスキップ設定 (`SKIP_HEADER = 1`) を確認
- カラム数がテーブル定義と一致していることを確認

**Q: Marketplace で「Get」ボタンが見えない**
- ロールが `ACCOUNTADMIN` または `IMPORT SHARE` 権限を持つロールであることを確認
- リージョンが Asia Pacific (Tokyo) であることを確認

**Q: Cortex AI Functions がエラーになる**
- `SNOWFLAKE.CORTEX` スキーマへのアクセス権を確認
- Enterprise Edition 以上であることを確認

**Q: Dynamic Table のデータが空**
- `SHOW DYNAMIC TABLES` でステータスを確認
- リフレッシュが完了するまで数分待つ

**Q: Cortex Search Service の作成に時間がかかる**
- 初回のインデックス構築には数分かかることがあります
- `SHOW CORTEX SEARCH SERVICES` でステータスを確認

**Q: Day 2 でデータが消えている**
- トライアルアカウントの有効期限（30日）を確認
- ウェアハウスが SUSPENDED の場合は `ALTER WAREHOUSE COMPUTE_WH RESUME` を実行

---

## 付録B: クリーンアップ

ハンズオン終了後、リソースをクリーンアップする場合：

```sql
-- 作成したオブジェクトを削除
DROP DATABASE IF EXISTS SNOWMART_DB;
DROP DATABASE IF EXISTS SNOWMART_DB_DEV;

-- ウェアハウスのサイズを戻す
ALTER WAREHOUSE COMPUTE_WH SET WAREHOUSE_SIZE = 'XSMALL';
```
