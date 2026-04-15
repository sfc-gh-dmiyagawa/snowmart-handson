#!/bin/bash
# SnowMart AI ハンズオン セットアップスクリプト
# 使い方: ./setup.sh [接続名]
#   接続名を省略した場合は default 接続を使用
#   例: ./setup.sh dmiyagawa

set -e

CONN=${1:-default}
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "========================================"
echo " SnowMart AI Handson Setup"
echo " 接続: $CONN"
echo "========================================"

# Step 1: SQLセットアップ（テーブル・データ・Cortex Search作成）
echo ""
echo "[1/2] データベースとデータをセットアップ中..."
echo "  (初回は Cortex Search Service 作成のため数分かかります)"
snow sql -f "$SCRIPT_DIR/setup_snowmart.sql" -c "$CONN"
echo "  -> SQL セットアップ完了"

# Step 2: ノートブックをワークスペースにアップロード
echo ""
echo "[2/2] ノートブックをワークスペースにアップロード中..."
cortex artifact create notebook snowmart_ai_handson \
  "$SCRIPT_DIR/snowmart_ai_handson.ipynb" \
  -c "$CONN"
echo "  -> ノートブックアップロード完了"

echo ""
echo "========================================"
echo " セットアップ完了！"
echo ""
echo " 次のステップ:"
echo "   1. Snowsight を開く"
echo "   2. Projects -> Notebooks"
echo "   3. snowmart_ai_handson を開く"
echo "========================================"
