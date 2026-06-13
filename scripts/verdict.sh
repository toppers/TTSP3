#!/bin/bash
#
#  verdict.sh — TTSP3 API オートコード実行結果を「正規化 VERDICT 1行」に判定する
#
#  AI/CI が緑数を手集計して STATUS.md と照合する手間を無くすためのヘルパ。
#  実行済み obj ディレクトリ（api_test/auto_code_*/execute.log を含む）を読み、
#  期待ベースライン（EXPECT_GREEN）と比較して退行か否かを判定する。
#
#  使い方:
#    scripts/verdict.sh <PROFILE> <target> <obj_dir> [div]
#  例:
#    scripts/verdict.sh FMP linux_gcc obj_fmp_posix 20
#
#  出力（末尾の機械可読1行）:
#    VERDICT: <PROFILE>/<target> API=N/M expected>=E fail=[g..] => OK(baseline)|REGRESSION
#  終了コード: 0=OK / 1=REGRESSION / 2=使い方エラー
#
#  期待ベースライン（EXPECT_GREEN）は docs/STATUS.md の実測値が正本。
#  値を更新したら STATUS.md と本テーブルの両方を直すこと（出典は STATUS.md）。
#
set -u
cd "$(dirname "$0")/.."

PROFILE="${1:-}"; TARGET="${2:-}"; OBJ="${3:-}"; DIV="${4:-20}"
if [ -z "$PROFILE" ] || [ -z "$TARGET" ] || [ -z "$OBJ" ]; then
	echo "usage: $0 <PROFILE> <target> <obj_dir> [div]" >&2; exit 2
fi

#  期待 API 緑数（auto_code N/DIV）。出典: docs/STATUS.md（最終確認 2026-06-13）
declare -A EXPECT_GREEN=(
	["FMP/zybo_z7_gcc"]=20
	["FMP/linux_gcc"]=13      # 既知残7（clr_int/prb_int/CRE_TSK stk/adj_tim）。STATUS §3
	["ASP/zybo_z7_gcc"]=20
	["HRP/zybo_z7_gcc"]=20
	["HRMP/zybo_z7_gcc"]=14   # 5群 chg_spr link失敗+1群NG（HRMP3 3.4）。STATUS 注6
)
KEY="$PROFILE/$TARGET"
EXP="${EXPECT_GREEN[$KEY]:-}"

green=0; fail=""
for i in $(seq 1 "$DIV"); do
	log="$OBJ/api_test/auto_code_$i/execute.log"
	if [ -f "$log" ] && tr -d '\r' < "$log" | grep -q 'All check points passed'; then
		green=$((green+1))
	else
		fail="$fail $i"
	fi
done
fail="${fail# }"

if [ -z "$EXP" ]; then
	echo "VERDICT: $KEY API=$green/$DIV expected=? fail=[$fail] => UNKNOWN(no-baseline; add to verdict.sh/STATUS.md)"
	exit 0
fi

if [ "$green" -ge "$EXP" ]; then
	echo "VERDICT: $KEY API=$green/$DIV expected>=$EXP fail=[$fail] => OK(baseline)"
	exit 0
else
	echo "VERDICT: $KEY API=$green/$DIV expected>=$EXP fail=[$fail] => REGRESSION(緑数がベースライン未満)"
	exit 1
fi
