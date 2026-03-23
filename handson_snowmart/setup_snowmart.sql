-- ============================================================
-- SnowMart 出店戦略ハンズオン: 講師用セットアップSQL
-- ============================================================
-- このSQLは講師が事前準備で使用するものです。
-- 参加者はシナリオ (scenario_snowmart.md) に従って手動で実行します。
--
-- 用途:
--   1. Git リポジトリからデータを取得して一括セットアップする場合
--   2. 事前にデモ環境を構築して動作確認する場合
-- ============================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;

-- ============================================================
-- Step 1: データベース・スキーマ・ステージの作成
-- ============================================================
CREATE OR REPLACE DATABASE SNOWMART_DB;
CREATE OR REPLACE SCHEMA SNOWMART_DB.SNOWMART_SCHEMA;
USE SCHEMA SNOWMART_DB.SNOWMART_SCHEMA;

CREATE OR REPLACE STAGE SNOWMART_STAGE
    DIRECTORY = (ENABLE = TRUE)
    FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1);

-- ============================================================
-- Step 2: テーブル作成
-- ============================================================

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

CREATE OR REPLACE TABLE COMPETITOR_STORES (
    COMPETITOR_ID VARCHAR(10),
    CHAIN_NAME VARCHAR(50),
    PREFECTURE VARCHAR(20),
    CITY VARCHAR(50),
    LATITUDE FLOAT,
    LONGITUDE FLOAT,
    FLOOR_AREA_SQM INT
);

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

CREATE OR REPLACE TABLE CUSTOMER_REVIEWS (
    REVIEW_ID VARCHAR(10),
    STORE_ID VARCHAR(10),
    REVIEW_DATE DATE,
    RATING INT,
    REVIEW_TEXT VARCHAR(1000),
    REVIEWER_AGE_GROUP VARCHAR(20)
);

-- ============================================================
-- Step 3: データロード
-- ============================================================
-- 事前に以下のCSVファイルを SNOWMART_STAGE にアップロードしてください:
--   snowmart_stores.csv, competitor_stores.csv, area_master.csv,
--   daily_sales.csv, customer_reviews.csv

COPY INTO SNOWMART_STORES FROM @SNOWMART_STAGE/snowmart_stores.csv
    FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1);
COPY INTO COMPETITOR_STORES FROM @SNOWMART_STAGE/competitor_stores.csv
    FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1);
COPY INTO AREA_MASTER FROM @SNOWMART_STAGE/area_master.csv
    FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1);
COPY INTO DAILY_SALES FROM @SNOWMART_STAGE/daily_sales.csv
    FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1);
COPY INTO CUSTOMER_REVIEWS FROM @SNOWMART_STAGE/customer_reviews.csv
    FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1);

-- ============================================================
-- Step 4: データ確認
-- ============================================================
SELECT 'SNOWMART_STORES' AS TABLE_NAME, COUNT(*) AS ROW_COUNT FROM SNOWMART_STORES
UNION ALL SELECT 'COMPETITOR_STORES', COUNT(*) FROM COMPETITOR_STORES
UNION ALL SELECT 'AREA_MASTER', COUNT(*) FROM AREA_MASTER
UNION ALL SELECT 'DAILY_SALES', COUNT(*) FROM DAILY_SALES
UNION ALL SELECT 'CUSTOMER_REVIEWS', COUNT(*) FROM CUSTOMER_REVIEWS;

-- ============================================================
-- Step 5: Dynamic Table 作成
-- ============================================================
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

-- ============================================================
-- Step 6: Cortex Search 用ドキュメント
-- ============================================================
CREATE OR REPLACE TABLE STORE_DOCUMENTS (
    DOC_ID VARCHAR(10),
    DOC_TITLE VARCHAR(200),
    DOC_SECTION VARCHAR(200),
    DOC_TEXT VARCHAR(5000)
);

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

-- ============================================================
-- Step 7: Cortex Search Service
-- ============================================================
CREATE OR REPLACE CORTEX SEARCH SERVICE SNOWMART_DOC_SEARCH
    ON DOC_TEXT
    ATTRIBUTES DOC_TITLE, DOC_SECTION
    WAREHOUSE = COMPUTE_WH
    TARGET_LAG = '1 hour'
    AS (
        SELECT DOC_ID, DOC_TITLE, DOC_SECTION, DOC_TEXT
        FROM STORE_DOCUMENTS
    );

-- ============================================================
-- Step 8: Streamlit アプリ（講師デモ用に手動作成）
-- ============================================================
-- Snowsight > Projects > Streamlit > + Streamlit App から作成してください
-- App name: SNOWMART_DASHBOARD
-- scenario_snowmart.md の Scene 7 に記載のベースコードを貼り付け

-- ============================================================
-- Step 9: Semantic View & Cortex Agent（Day 2 用）
-- ============================================================
-- scenario_snowmart.md の Scene 4 (Day 2) に記載のSQLを実行してください

-- ============================================================
-- 確認: 全オブジェクトの一覧
-- ============================================================
SHOW TABLES IN SCHEMA SNOWMART_DB.SNOWMART_SCHEMA;
SHOW DYNAMIC TABLES IN SCHEMA SNOWMART_DB.SNOWMART_SCHEMA;
SHOW CORTEX SEARCH SERVICES IN SCHEMA SNOWMART_DB.SNOWMART_SCHEMA;
