#!/bin/bash
#
#  run_one.sh — 1テスト（を含む auto_code 群）だけを build して実行する
#
#  「カーネルを直した。あのテストは通る？」の反復を速くするための補助。
#  分割（manifest）生成の都合で全20群を build するが、実行は対象群のみ。
#
#  使い方:
#    scripts/run_one.sh <PROFILE> <target> <test_substring> [div]
#  例:
#    scripts/run_one.sh FMP linux_gcc ter_tsk_f_4_1_1
#    scripts/run_one.sh ASP zybo_z7_gcc act_tsk
#
#  対応実行系: linux_gcc=native / zybo_z7_gcc(Cortex-A9)=QEMU。
#  その他ターゲットはビルドと群特定まで行い、実行コマンドを表示する。
#
set -u
cd "$(dirname "$0")/.."

PROFILE="${1:?usage: run_one.sh <PROFILE> <target> <test_substring> [div]}"
TARGET="${2:?target}"
PAT="${3:?test_substring}"
DIV="${4:-20}"

case "$PROFILE" in
	ASP)  OS=../asp3/;  KN=asp ;;
	FMP)  OS=../fmp3/;  KN=fmp ;;
	HRP)  OS=../hrp3/;  KN=hrp ;;
	HRMP) OS=../hrmp3/; KN=hrmp ;;
	*) echo "ERROR: PROFILE は ASP/FMP/HRP/HRMP" >&2; exit 2 ;;
esac
OBJ="obj_one_${KN}_${TARGET}"

echo "=== build（全${DIV}群・実行はスキップ）: $PROFILE $TARGET ==="
TTSP_TARGET_NAME="$TARGET" SKIP_RUN=1 TTSP_MAKE_OPT="${TTSP_MAKE_OPT:-}" \
	bash scripts/ttsp_parallel_api.sh "$OS" "$PROFILE" "$OBJ" "$DIV" > "/tmp/run_one_$KN.log" 2>&1
nbin=$(grep -c 'BUILD OK' "/tmp/run_one_$KN.log" 2>/dev/null || echo 0)
echo "  binaries: ${nbin}/${DIV}（ログ: /tmp/run_one_$KN.log）"

grpdir=$(grep -l "$PAT" "$OBJ"/api_test/auto_code_*/out.c 2>/dev/null | head -1)
if [ -z "$grpdir" ]; then
	echo "ERROR: '$PAT' を含む群が見つからない（テスト名の部分一致を確認）" >&2; exit 1
fi
grp=$(dirname "$grpdir"); gname=$(basename "$grp")
echo "=== '$PAT' を含む群: $gname を実行 ==="

run_native() { ( cd "$grp" && timeout 90 ./fmp > execute.log 2>&1 ); }
run_qemu_a9() {
	local smp=""; { [ "$PROFILE" = FMP ] || [ "$PROFILE" = HRMP ]; } && smp="-smp 2"
	( cd "$grp" && timeout 600 qemu-system-arm -M xilinx-zynq-a9 -semihosting -m 512M \
		-serial null -serial mon:stdio -nographic $smp -kernel "$KN" < /dev/null > execute.log 2>&1 )
}
case "$TARGET" in
	linux_gcc)    run_native ;;
	zybo_z7_gcc)  run_qemu_a9 ;;
	*) echo "（$TARGET の自動実行は未対応。$grp で手動実行してください）"; exit 0 ;;
esac

if grep -q 'All check points passed' "$grp/execute.log"; then
	echo "RESULT: PASS  ($gname)"
	exit 0
else
	echo "RESULT: FAIL  ($gname)"
	grep -oE 'Unexpected[^.]*\.|Assertion[^,]*|fatal[^.]*' "$grp/execute.log" | head -3 | sed 's/^/    /'
	exit 1
fi
