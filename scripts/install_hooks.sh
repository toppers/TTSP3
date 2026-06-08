#!/bin/bash
#  install_hooks.sh — git hooks を導入（versioned な scripts/git_hooks を使う）
#  方法: core.hooksPath を scripts/git_hooks に向ける（クローン毎に1回実行）
set -u
cd "$(dirname "$0")/.."
git config core.hooksPath scripts/git_hooks
echo "core.hooksPath = scripts/git_hooks に設定しました（pre-commit有効）。"
echo "前提: python3 + 'markitdown[xlsx]'（または pandas+openpyxl）が導入済みであること。"
