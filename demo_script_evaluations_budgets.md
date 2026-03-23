# デモ台本: Cortex Agent Evaluations & Resource Budgets（7分）

## 対象: 顧客向けデモ
## 環境: SFSEAPAC-DMIYAGAWA / SNOWRETAIL_DB.SNOWRETAIL_SCHEMA
## 前提: SnowRetail Agent（Cortex Search + Cortex Analyst構成）が稼働済み

---

# ===== パート1: Cortex Agent Evaluations（約4分30秒）=====

## シーン1: 導入（30秒）

**話す内容:**

AIエージェントを構築したあと、次に重要になるのが「このエージェントはちゃんと正しく動いているのか」という品質の可視化です。

Snowflakeでは、Cortex Agent Evaluationsという機能が2026年3月にGAとなりました。
この機能を使うと、エージェントの回答品質をシステマティックに測定・比較できます。

評価メトリクスは3種類あります:
- Answer Correctness: 期待する回答と実際の回答がどれだけ一致しているか
- Logical Consistency: エージェントの推論過程に無駄なツール呼び出しや矛盾がないか
- Custom Metrics: YAML定義で独自の評価基準を作成可能（例: Groundedness、Tool Selection）

**画面:** Snowsight のトップページを表示した状態

---

## シーン2: 評価データセットの確認（30秒）

**話す内容:**

まず、評価に使うデータセットを見てみましょう。
これはSnowRetailエージェント用に作成した評価データセットです。

テーブルには INPUT_QUERY（エージェントへの質問）と GROUND_TRUTH_DATA（期待される回答やツール呼び出し情報）が入っています。

例えば「2024年の売上トップ5商品は？」という質問に対して、
期待される回答テキストと「Cortex Analystを使うべき」というツール情報が ground truth として定義されています。

Cortex Searchを使うべき質問、Analystを使うべき質問、両方使う質問など、
エージェントの様々な動作パターンをカバーするようにデータセットを設計するのがポイントです。

**画面操作:**

```sql
-- Snowsight SQL Worksheetで実行
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;
USE SCHEMA SNOWRETAIL_DB.SNOWRETAIL_SCHEMA;

-- 評価データセットの確認
SELECT * FROM EVAL_DATASET_SNOWRETAIL_AGENT;
```

**ポイント:** データセットは15行。実運用では50〜100行程度が推奨。カテゴリ（Search系、Analyst系、複合系）をバランスよく含めることが重要。

---

## シーン3: YAML評価設定ファイルの解説（45秒）

**話す内容:**

次に、評価の設定ファイルを見てみましょう。
YAML形式で、「どのエージェントを」「どのデータセットで」「どのメトリクスで」評価するかを定義します。

まず evaluation セクションで、対象のエージェントとデータセットを指定します。
次に metrics セクションで、組み込みメトリクスの correctness と logical_consistency を指定し、
さらにカスタムメトリクスとして groundedness を定義しています。

カスタムメトリクスでは、LLM-as-a-judge のプロンプトをそのまま書けます。
「ツールの出力に基づいて回答しているか」という観点でスコアリングする rubric を定義しています。
スコアは0〜1の範囲で、しきい値も自分で決められます。

**画面操作:**

以下の内容をSnowsight SQL Worksheetまたはテキストエディタで表示:

```yaml
# snowretail_eval_config.yaml

evaluation:
  agent_params:
    agent_name: SNOWRETAIL_DB.SNOWRETAIL_SCHEMA.SNOWRETAIL_AGENT
    agent_type: CORTEX AGENT
  run_params:
    label: "SnowRetail Agent 評価 v1"
    description: "EC・小売データと社内文書検索の回答品質評価"
  source_metadata:
    type: dataset
    dataset_name: SNOWRETAIL_DB.SNOWRETAIL_SCHEMA.EVAL_DATASET_SNOWRETAIL_AGENT

metrics:
  - correctness           # 組み込み: 回答の正確性
  - logical_consistency   # 組み込み: 推論の一貫性

  - name: groundedness    # カスタム: 根拠の確かさ
    score_ranges:
      min_score: [0, 0.33]
      median_score: [0.34, 0.66]
      max_score: [0.67, 1]
    prompt: |
      あなたはAIエージェントの回答の「根拠の確かさ」を評価する審査員です。

      ユーザーの質問: {{input}}
      エージェントの回答: {{output}}
      期待される回答: {{ground_truth}}

      回答の各主張がツール出力や取得データに裏付けられているか評価してください。
      裏付けのない主張が含まれる場合、スコアを下げてください。
      0（完全に根拠なし）〜 1（全て根拠あり）のスコアで評価してください。
```

**ポイント:** テンプレート変数 {{input}}, {{output}}, {{ground_truth}} が自動で埋められる。エージェントの実行トレース全体もLLM judgeに渡される。

---

## シーン4: 評価の実行（45秒）

**話す内容:**

評価の実行方法は2つあります。

1つ目はSQLでの実行です。YAML設定ファイルをステージにアップロードして、
EXECUTE_AI_EVALUATION関数を呼び出すだけです。

```sql
-- YAMLファイルをステージにアップロード（事前準備）
PUT file:///path/to/snowretail_eval_config.yaml
    @SNOWRETAIL_DB.SNOWRETAIL_SCHEMA.EVAL_CONFIG_STAGE
    AUTO_COMPRESS=FALSE OVERWRITE=TRUE;

-- 評価を実行
SELECT SNOWFLAKE.CORTEX.EXECUTE_AI_EVALUATION(
  config_file => '@SNOWRETAIL_DB.SNOWRETAIL_SCHEMA.EVAL_CONFIG_STAGE/snowretail_eval_config.yaml'
);
```

2つ目はSnowsight GUIからの実行です。
AI & ML セクションの Evaluations から、New Evaluation で
エージェント、データセット、メトリクスを選択して実行できます。

評価が走ると、各質問に対してエージェントが実際に回答を生成し、
LLMジャッジがその回答を採点します。15問のデータセットだと数分で完了します。

**画面操作:** （事前に評価を実行済みの場合は結果画面に遷移する準備）

**ポイント:** 本番運用ではSQLのほうが再現性が高く、CI/CDパイプラインにも組み込みやすい。

---

## シーン5: 結果の閲覧と比較（60秒）

**話す内容:**

評価が完了したら、Snowsight で結果を確認しましょう。

AI & ML > Evaluations を開くと、アプリケーション一覧が表示されます。
SnowRetail Agentを選択すると、実行したRunの一覧が見えます。

Runを開くと、まず集計結果が表示されます。
- Answer Correctness の平均スコア
- Logical Consistency の平均スコア
- Groundedness（カスタム）の平均スコア

さらに、レコード単位で詳細を見ることができます。
各質問に対して、エージェントが何を回答したか、どのツールを呼び出したか、
そしてそれぞれのメトリクスのスコアがいくつだったかが確認できます。

例えば、Searchを使うべき質問でAnalystを呼んでいたり、
回答がツール出力と矛盾している場合は、スコアが低くなります。
こういったケースを特定して、エージェントの instructions を改善していくわけです。

もう一つ重要な機能が「比較」です。
エージェントの設定を変更したあと、同じデータセットで再度評価を実行し、
2つのRunを選択して Compare すると、メトリクスの改善・劣化を一目で比較できます。

**画面操作:**
1. Snowsight左メニュー > AI & ML > Evaluations
2. SNOWRETAIL_AGENT をクリック
3. Run一覧から最新のRunをクリック
4. 集計スコア → 個別レコードのスコアを確認
5. （複数Run がある場合）2つ選択して Compare

**ポイント:** 「評価→改善→再評価」のサイクルを回すことが品質向上の鍵。

---

# ===== パート2: Resource Budgets for Cortex Agents（約2分）=====

## シーン6: 課題提起（20秒）

**話す内容:**

エージェントの品質を担保する仕組みができたところで、
次に本番運用で重要になるのが「コスト管理」です。

AIエージェントはユーザーの質問に応じて、LLM呼び出し、Search、Analyst と
複数のサービスを動的に使うため、使い方によってはコストが予想以上に膨らむリスクがあります。

Snowflakeでは、Cortex Agent専用のResource Budgets機能でこれに対応できます。

**画面:** Snowsight の Cost Management ページを表示

---

## シーン7: タグベースのコスト管理フロー（30秒）

**話す内容:**

Resource Budgets はSnowflakeの「タグベースのコスト管理モデル」を活用しています。
流れは3ステップです。

まず、コスト管理用のタグを作成し、エージェントに適用します。

```sql
-- Step 1: タグを作成
CREATE TAG cost_mgmt_db.tags.cost_center
  ALLOWED_VALUES 'snowretail-team'
  COMMENT = 'Cortex Agent コスト管理用タグ';

-- Step 2: エージェントにタグを適用
ALTER AGENT SNOWRETAIL_DB.SNOWRETAIL_SCHEMA.SNOWRETAIL_AGENT
  SET TAG cost_mgmt_db.tags.cost_center = 'snowretail-team';
```

次に、Budgetを作成して月間のクレジット上限を設定します。

```sql
-- Step 3: Budgetを作成し月間上限を設定
USE SCHEMA budgets_db.budgets_schema;
CREATE SNOWFLAKE.CORE.BUDGET snowretail_budget();
CALL snowretail_budget!SET_SPENDING_LIMIT(5000);  -- 月5000クレジット

-- タグとBudgetを紐付け
CALL snowretail_budget!SET_RESOURCE_TAGS(
  [[(SELECT SYSTEM$REFERENCE('TAG', 'cost_mgmt_db.tags.cost_center',
     'SESSION', 'applybudget')), 'snowretail-team']],
  'UNION'
);
```

これだけで、SnowRetail Agentのクレジット消費が月5000クレジットの枠で管理されます。

**ポイント:** GUIからも Admin > Cost Management > Budgets で同様の設定が可能。

---

## シーン8: 閾値アクションの設定（40秒）

**話す内容:**

Budget を設定しただけでは通知されないので、閾値アクションを設定します。

まず、80%到達時にメール通知を送る設定です。

```sql
-- メール通知の設定
CALL snowretail_budget!SET_EMAIL_NOTIFICATIONS(
  'budgets_notification_integration',
  'admin@example.com'
);
CALL snowretail_budget!SET_NOTIFICATION_THRESHOLD(80);
```

次に、100%到達時にアクセスを自動的に失効させるストアドプロシージャを登録します。

```sql
-- アクセス失効用のストアドプロシージャ
CREATE OR REPLACE PROCEDURE sp_revoke_agent_access(
  agent_name STRING, role_name STRING
)
RETURNS STRING
LANGUAGE SQL
AS
BEGIN
  EXECUTE IMMEDIATE
    'REVOKE ROLE agent_' || agent_name || '_role FROM ROLE ' || role_name;
  RETURN 'Access revoked for ' || agent_name;
END;

-- 100%到達時にアクセス失効を実行
CALL snowretail_budget!ADD_CUSTOM_ACTION(
  SYSTEM$REFERENCE('PROCEDURE',
    'budgets_db.budgets_schema.sp_revoke_agent_access(string, string)'),
  ARRAY_CONSTRUCT('SNOWRETAIL_AGENT', 'ANALYST_ROLE'),
  'ACTUAL', 100
);
```

つまり、「80%で管理者にアラート → 100%で自動的にアクセス遮断」という
段階的なコスト制御が実現できます。

**ポイント:** 閾値アクションはカスタムなので、REVOKE以外にも Slack通知やログ記録など自由に定義可能。

---

## シーン9: 例外処理 - 繁忙期の対応（30秒）

**話す内容:**

実運用では「今月は繁忙期だから一時的に上限を超えて使いたい」というケースもあります。

Resource Budgets では、100%を超える閾値（最大500%）を設定できます。

例えば、100%で一度アクセスを停止した後、管理者が手動で一部ユーザーのアクセスを復元し、
200%に達したら再度停止する、という運用が可能です。

```sql
-- 管理者が手動でアクセスを復元
CALL sp_reinstate_agent_access('SNOWRETAIL_AGENT', 'power_user_role');

-- 200%をハードリミットとして設定
CALL snowretail_budget!ADD_CUSTOM_ACTION(
  SYSTEM$REFERENCE('PROCEDURE',
    'budgets_db.budgets_schema.sp_revoke_agent_access(string, string)'),
  ARRAY_CONSTRUCT('SNOWRETAIL_AGENT', 'power_user_role'),
  'ACTUAL', 200
);
```

また、月初めの予算サイクル開始時にアクセスを自動復元するアクションも設定でき、
毎月リセットされる運用が自動化できます。

---

# ===== パート3: まとめ（30秒）=====

## シーン10: まとめ

**話す内容:**

本日ご紹介した2つの機能をまとめます。

Cortex Agent Evaluations は、エージェントの回答品質を定量的に測定し、
設定変更の効果を比較できる機能です。
組み込みメトリクスに加え、YAML でカスタムメトリクスも定義でき、
SQLまたはGUIから実行できます。

Resource Budgets for Cortex Agents は、エージェントの月間コストに上限を設け、
閾値ベースで通知やアクセス制御を自動化する機能です。

この2つを組み合わせることで、
「品質を評価・改善しながら、コストも適切に管理する」
というAIエージェントの本番運用サイクルが実現できます。

**画面:** まとめスライドまたはSnowsightのトップページ

---

# ===== デモ準備チェックリスト =====

## 事前準備（必須）

- [ ] SnowRetail Agent が稼働していることを確認
- [ ] EVAL_DATASET_SNOWRETAIL_AGENT テーブルにデータがあることを確認（15行）
- [ ] eval_config.yaml を作成し EVAL_CONFIG_STAGE にアップロード
- [ ] 評価を1回以上実行済み（デモ中に結果を見せるため）
- [ ] Snowsight AI & ML > Evaluations で結果が表示されることを確認
- [ ] （可能であれば）設定を変えた2回目の評価も実行済み（Compare機能のデモ用）

## 事前準備（推奨）

- [ ] Resource Budgets 用のDB/Schema/タグを事前作成
- [ ] Budgets の画面（Admin > Cost Management）で表示を確認

## 時間配分サマリー

- シーン1: 導入 ................... 0:30
- シーン2: データセット確認 ....... 0:30
- シーン3: YAML設定解説 ........... 0:45
- シーン4: 評価実行 ............... 0:45
- シーン5: 結果閲覧・比較 ......... 1:00
- シーン6: コスト課題提起 ......... 0:20
- シーン7: タグベース管理 ......... 0:30
- シーン8: 閾値アクション ......... 0:40
- シーン9: 例外処理 ............... 0:30
- シーン10: まとめ ................ 0:30
- ───────────────────────────
- 合計 ............................ 7:00
