#!/bin/bash
#
#  ci_run.sh — CI用：TTSP3を非対話で configure → build → QEMU実行する骨格。
#  ttb.sh は対話メニューのため、CIではメニュー相当の処理を直接呼ぶ。
#  実際の手順は ttb.sh / configure.sh / scripts/*.sh の内部に合わせて実装すること。
#
set -euo pipefail

# 前提：本スクリプトは ttsp3/ で実行。../asp3 が存在すること。
test -d ../asp3 || { echo "ERROR: ../asp3 (sibling kernel) not found"; exit 1; }

# 1) 設定確認（configure.sh は事前にCIで OS_PATH/PROFILE_NAME を設定済み想定）
grep -q 'OS_PATH="../asp3/"' configure.sh || { echo "ERROR: OS_PATH"; exit 1; }

# 2) TODO: ttb.sh のメニュー処理を非対話で呼ぶ
#    例）ターゲット依存チェック → SIL → API を順に build & QEMU 実行し、
#        各結果を execute.log に追記する。
#    ttb.sh の関数（ttsp_main_menu 等）を source して個別に呼ぶ実装が必要。
echo "TODO: implement non-interactive driving of ttb.sh (target-dep -> SIL -> API)"
echo "  - build each suite against ../asp3 (zybo_z7_gcc)"
echo "  - run on qemu-system-arm -M xilinx-zynq-a9 ... and tee to execute.log"

exit 1   # 実装後に削除
