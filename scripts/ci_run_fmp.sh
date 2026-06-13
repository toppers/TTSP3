#!/bin/bash
#
#  ci_run_fmp.sh — 後方互換ラッパ（実体は統一ランナー scripts/ci_run.sh）
#
#  FMP3 / zybo_z7_gcc の非対話CI。`.github/workflows/ci.yml` が本名で呼ぶため残置。
#  中身は `scripts/ci_run.sh FMP` と等価（プロファイル別パラメータは ci_run.sh が保持）。
#  環境変数（CI_MODE/API_DIV_NUM/QEMU_TIMEOUT/CFGERR_ALLOW_NG）も ci_run.sh に渡る。
#
exec bash "$(dirname "$0")/ci_run.sh" FMP "$@"
