-- ============================================================
-- SnowMart 出店戦略ハンズオン: セットアップSQL（完全版）
-- ============================================================
-- 【概要】
-- このSQLはセッション開始前に一括実行します。
-- GitHubから自動でデータ取得・ノートブックをデプロイします。
-- CSVの手動アップロードは不要です。
--
-- 【処理内容】
-- Step 1: 環境設定
-- Step 2: データベース・スキーマ・ステージの作成
-- Step 3: GitHub連携の設定（API統合 + Gitリポジトリ）
-- Step 4: GitHubからCSVデータを自動取得
-- Step 5: テーブル作成
-- Step 6: データロード（COPY INTO）
-- Step 7: データ確認
-- Step 8: Cortex Search 用ドキュメント格納
-- Step 9: ノートブックの自動デプロイ
-- Step 10: 全オブジェクト確認
--
-- 【セッション中に参加者が自分で実行するもの】
--   - Cortex Search Service の作成（Scene 2）
--   - Semantic View の作成（Scene 3）
--   - Cortex Agent の作成（Scene 4）
-- ============================================================


-- ============================================================
-- Step 1: 環境設定
-- ============================================================
USE ROLE ACCOUNTADMIN;
CREATE WAREHOUSE IF NOT EXISTS COMPUTE_WH;
USE WAREHOUSE COMPUTE_WH;

SELECT '【Step 1】環境設定が完了しました' AS STATUS;


-- ============================================================
-- Step 2: データベース・スキーマ・ステージの作成
-- ============================================================
CREATE OR REPLACE DATABASE SNOWMART_DB;
CREATE OR REPLACE SCHEMA SNOWMART_DB.SNOWMART_SCHEMA;
USE SCHEMA SNOWMART_DB.SNOWMART_SCHEMA;

CREATE OR REPLACE STAGE SNOWMART_STAGE
    ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE')
    DIRECTORY = (ENABLE = TRUE);

SELECT '【Step 2】データベース・スキーマ・ステージの作成が完了しました' AS STATUS;


-- ============================================================
-- Step 3: GitHub連携の設定
-- ============================================================
CREATE OR REPLACE API INTEGRATION snowmart_git_integration
    API_PROVIDER = git_https_api
    API_ALLOWED_PREFIXES = ('https://github.com/sfc-gh-dmiyagawa/')
    ENABLED = TRUE;

CREATE OR REPLACE GIT REPOSITORY snowmart_handson_repo
    API_INTEGRATION = snowmart_git_integration
    ORIGIN = 'https://github.com/sfc-gh-dmiyagawa/snowmart-handson.git';

-- 最新コミットを取得
ALTER GIT REPOSITORY snowmart_handson_repo FETCH;

SELECT '【Step 3】GitHub連携の設定が完了しました' AS STATUS;


-- ============================================================
-- Step 4: GitHubからCSVデータを自動取得
-- ============================================================
COPY FILES
    INTO @SNOWMART_DB.SNOWMART_SCHEMA.SNOWMART_STAGE
    FROM @snowmart_handson_repo/branches/main/handson_snowmart/data/;

-- 取得したファイルを確認
LS @SNOWMART_STAGE;

SELECT '【Step 4】GitHubからデータの取得が完了しました' AS STATUS;


-- ============================================================
-- Step 5: テーブル作成
-- ============================================================
CREATE OR REPLACE TABLE SNOWMART_STORES (
    STORE_ID         VARCHAR(10),
    STORE_NAME       VARCHAR(100),
    PREFECTURE       VARCHAR(20),
    CITY             VARCHAR(50),
    LATITUDE         FLOAT,
    LONGITUDE        FLOAT,
    STORE_TYPE       VARCHAR(10),
    FLOOR_AREA_SQM   INT,
    OPEN_DATE        DATE,
    NEAREST_STATION  VARCHAR(100)
);

CREATE OR REPLACE TABLE COMPETITOR_STORES (
    COMPETITOR_ID    VARCHAR(10),
    CHAIN_NAME       VARCHAR(50),
    PREFECTURE       VARCHAR(20),
    CITY             VARCHAR(50),
    LATITUDE         FLOAT,
    LONGITUDE        FLOAT,
    FLOOR_AREA_SQM   INT
);

CREATE OR REPLACE TABLE AREA_MASTER (
    AREA_ID                   VARCHAR(10),
    PREFECTURE                VARCHAR(20),
    CITY                      VARCHAR(50),
    POPULATION                INT,
    HOUSEHOLDS                INT,
    DAYTIME_POPULATION_RATIO  FLOAT,
    AVG_ANNUAL_INCOME         INT,
    AREA_TYPE                 VARCHAR(20)
);

CREATE OR REPLACE TABLE DAILY_SALES (
    STORE_ID          VARCHAR(10),
    SALES_DATE        DATE,
    SALES_AMOUNT      INT,
    CUSTOMER_COUNT    INT,
    AVG_UNIT_PRICE    FLOAT,
    FOOD_SALES        INT,
    BEVERAGE_SALES    INT,
    DAILY_GOODS_SALES INT
);

CREATE OR REPLACE TABLE CUSTOMER_REVIEWS (
    REVIEW_ID           VARCHAR(10),
    STORE_ID            VARCHAR(10),
    REVIEW_DATE         DATE,
    RATING              INT,
    REVIEW_TEXT         VARCHAR(1000),
    REVIEWER_AGE_GROUP  VARCHAR(20)
);

SELECT '【Step 5】テーブル作成が完了しました' AS STATUS;


-- ============================================================
-- Step 6: データロード
-- ============================================================
COPY INTO SNOWMART_STORES
    FROM @SNOWMART_STAGE/snowmart_stores.csv
    FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1);

COPY INTO COMPETITOR_STORES
    FROM @SNOWMART_STAGE/competitor_stores.csv
    FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1);

COPY INTO AREA_MASTER
    FROM @SNOWMART_STAGE/area_master.csv
    FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1);

COPY INTO DAILY_SALES
    FROM @SNOWMART_STAGE/daily_sales.csv
    FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1);

COPY INTO CUSTOMER_REVIEWS
    FROM @SNOWMART_STAGE/customer_reviews.csv
    FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1);

SELECT '【Step 6】データロードが完了しました' AS STATUS;


-- ============================================================
-- Step 7: データ確認
-- ============================================================
SELECT 'SNOWMART_STORES'   AS TABLE_NAME, COUNT(*) AS ROW_COUNT FROM SNOWMART_STORES
UNION ALL SELECT 'COMPETITOR_STORES', COUNT(*) FROM COMPETITOR_STORES
UNION ALL SELECT 'AREA_MASTER',       COUNT(*) FROM AREA_MASTER
UNION ALL SELECT 'DAILY_SALES',       COUNT(*) FROM DAILY_SALES
UNION ALL SELECT 'CUSTOMER_REVIEWS',  COUNT(*) FROM CUSTOMER_REVIEWS;

-- 期待値:
--   SNOWMART_STORES   = 500
--   COMPETITOR_STORES = 1000
--   AREA_MASTER       = 50
--   DAILY_SALES       = 約 365,000
--   CUSTOMER_REVIEWS  = 500



-- ============================================================
-- Step 8: Cortex Search 用ドキュメント格納
-- ============================================================
CREATE OR REPLACE TABLE STORE_DOCUMENTS (
    DOC_ID      VARCHAR(10),
    DOC_TITLE   VARCHAR(200),
    DOC_SECTION VARCHAR(200),
    DOC_TEXT    VARCHAR(5000)
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
 'セブン-イレブンはPB商品が強く品質重視の顧客層。ファミリーマートはファストフードが強く若年層に人気。ローソンはスイーツ・ヘルシー系に強く女性客比率が高い。上記チェーンが手薄なカテゴリで差別化を図ることが重要。'),
('D009', '出店ガイドライン', '住宅地出店の特殊条件',
 '住宅地でのコンビニは近隣住民との関係が重要。深夜営業は周辺住民の意見を事前ヒアリングすること。駐車場は最低4台分を確保し、来客のターンオーバーを高める設計とする。日配品（惣菜・弁当）の品揃えを充実させ、夕方需要を取り込む。'),
('D010', '出店ガイドライン', '出店候補エリア評価スコアリング',
 '以下の5項目を各20点満点で評価し、合計80点以上を出店可とする。(1)商圏人口・昼間人口 (2)競合密度（少ないほど高得点） (3)既存スノーマート店との距離（近すぎると減点） (4)エリアの所得水準 (5)立地アクセス（駅近・幹線道路沿い等）');

SELECT '【Step 8】Cortex Search 用ドキュメントの格納が完了しました' AS STATUS;



-- ============================================================
-- Step 9: ノートブックの自動デプロイ
-- ============================================================
CREATE OR REPLACE NOTEBOOK SNOWMART_AI_HANDSON
    FROM '@snowmart_handson_repo/branches/main/handson_snowmart/'
    MAIN_FILE = 'snowmart_ai_handson.ipynb'
    QUERY_WAREHOUSE = COMPUTE_WH;

ALTER NOTEBOOK SNOWMART_AI_HANDSON ADD LIVE VERSION FROM LAST;

SELECT '【Step 9】ノートブックのデプロイが完了しました' AS STATUS;
-- Snowsight 左メニュー > Projects > Notebooks > SNOWMART_AI_HANDSON を開く


-- ============================================================
-- Step 10: 全オブジェクト確認
-- ============================================================
SHOW TABLES              IN SCHEMA SNOWMART_DB.SNOWMART_SCHEMA;
SHOW NOTEBOOKS           IN SCHEMA SNOWMART_DB.SNOWMART_SCHEMA;

-- ============================================================
-- セットアップ完了チェックリスト
-- ============================================================
-- [ ] SNOWMART_STORES       : 500行
-- [ ] COMPETITOR_STORES     : 1000行
-- [ ] AREA_MASTER           : 50行
-- [ ] DAILY_SALES           : 約180,000行
-- [ ] CUSTOMER_REVIEWS      : 500行
-- [ ] STORE_DOCUMENTS       : 10行
-- [ ] SNOWMART_DOC_SEARCH   : Cortex Search Service が ACTIVE 状態
-- [ ] SNOWMART_AI_HANDSON   : Notebook が Snowsight から開ける状態
--
-- セッション中に参加者が作成するオブジェクト（このSQLには含めない）:
-- [ ] SNOWMART_ANALYSIS     : Semantic View（Scene 3 で作成）
-- [ ] SNOWMART_AGENT        : Cortex Agent（Scene 4 で作成）
-- ============================================================
