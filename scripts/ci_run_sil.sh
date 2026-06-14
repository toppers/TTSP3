#!/bin/bash
#
#  ci_run_sil.sh — TTSP3 SILテスト 非対話CIランナー（全プロファイル統一）
#
#  ttb.sh の SILメニュー（option 2 → 1: 全ビルド）を非対話で駆動し，生成された
#  カーネルバイナリを QEMU（xilinx-zynq-a9）で実行して合否を集計する．
#  対応プロファイル：ASP / FMP / HRP / HRMP（zybo_z7_gcc・QEMU 前提）．
#
#  SILテストは第3世代カーネル向けに移植済み（docs/SIL_TEST.md）：
#    sil_test/<PROFILE>/{out.c,out.h,out.cfg} を ttb.sh(sil_test.sh) がビルド．
#
#  使い方:
#    scripts/ci_run_sil.sh [PROFILE ...]
#      引数なし: ASP FMP HRP HRMP を順に実行
#      例)  scripts/ci_run_sil.sh HRP
#           scripts/ci_run_sil.sh ASP FMP
#
#  環境変数:
#    TARGET       : ターゲット（既定 zybo_z7_gcc）
#    QEMU_TIMEOUT : QEMU 1実行のタイムアウト秒（既定 120）
#    OBJ_PREFIX   : 作業ディレクトリ接頭辞（既定 obj_）。<OBJ_PREFIX><kn>_sil を使う
#
#  終了コード: 全プロファイル緑なら 0，1つでも赤/ビルド失敗なら 1．
#
set -u
cd "$(dirname "$0")/.."

TARGET="${TARGET:-zybo_z7_gcc}"
QEMU_TIMEOUT="${QEMU_TIMEOUT:-120}"
OBJ_PREFIX="${OBJ_PREFIX:-obj_}"

PROFILES=("$@")
[ ${#PROFILES[@]} -eq 0 ] && PROFILES=(ASP FMP HRP HRMP)

FAIL=0; PASS_CNT=0; FAIL_CNT=0
declare -a SUMMARY=()

# プロファイル → カーネル名 / OS パス / QEMU SMP オプション
prof_map() { # $1=PROFILE  → グローバル KN/OS/SMP を設定
	case "$1" in
		ASP)  KN=asp;  OS=../asp3/;  SMP="-smp 1" ;;
		FMP)  KN=fmp;  OS=../fmp3/;  SMP="-smp 2" ;;
		HRP)  KN=hrp;  OS=../hrp3/;  SMP="-smp 1" ;;
		HRMP) KN=hrmp; OS=../hrmp3/; SMP="-smp 2" ;;
		*) echo "ERROR: PROFILE は ASP/FMP/HRP/HRMP（指定: $1）" >&2; return 1 ;;
	esac
	return 0
}

run_one() { # $1=PROFILE
	local prof="$1"
	prof_map "$prof" || { FAIL=1; return 1; }
	local osdir="${OS%/}"
	local obj="${OBJ_PREFIX}${KN}_sil"

	echo "===== SIL: $prof / $TARGET (obj=$obj, qemu $SMP) ====="

	# 前提チェック
	if [ ! -d "$osdir" ]; then
		echo "SKIP: $prof — $osdir (兄弟カーネル) が無い"; SUMMARY+=("SKIP $prof (no kernel)"); return 0
	fi
	if [ ! -f "sil_test/$prof/out.cfg" ]; then
		echo "SKIP: $prof — sil_test/$prof/out.cfg が無い（未移植）"; SUMMARY+=("SKIP $prof (no sil source)"); return 0
	fi
	if ! grep -q '^USE_QEMU=true' "library/$prof/target/$TARGET/ttsp_target.sh" 2>/dev/null; then
		echo "SKIP: $prof — $TARGET は USE_QEMU!=true（QEMU 前提ランナー）"; SUMMARY+=("SKIP $prof (no qemu)"); return 0
	fi

	# ビルド（ttb.sh SILメニュー: 2=SIL → 1=全ビルド → q）
	rm -rf "$obj"
	printf '2\n1\nq\n' | TTSP_TARGET_NAME="$TARGET" bash ttb.sh "$OS" "$prof" "$obj" \
		> "ci_${KN}_sil_build.log" 2>&1

	local bin="$obj/sil_test/$KN"
	if [ ! -f "$bin" ]; then
		echo "BUILD FAIL: $prof  (tail of ci_${KN}_sil_build.log)"
		grep -iE 'error:|undefined reference|Error 1|syntax error|E_[A-Z]' "ci_${KN}_sil_build.log" \
			| grep -vE 'OMIT_CHECK_USTACK_OVERLAP|given more than once' | sort -u | tail -10 | sed 's/^/    /'
		FAIL=1; FAIL_CNT=$((FAIL_CNT + 1)); SUMMARY+=("FAIL $prof (build)"); return 1
	fi

	# QEMU 実行
	( cd "$obj/sil_test" && timeout "$QEMU_TIMEOUT" qemu-system-arm -M xilinx-zynq-a9 \
		-semihosting -m 512M -serial null -serial mon:stdio -nographic \
		$SMP -kernel "$KN" < /dev/null > execute.log 2>&1 )

	# 合否判定（"All check points passed." を根拠にする）
	if tr -d '\r' < "$obj/sil_test/execute.log" 2>/dev/null | grep -q 'All check points passed\.'; then
		echo "PASS: $prof"; PASS_CNT=$((PASS_CNT + 1)); SUMMARY+=("PASS $prof")
	else
		echo "FAIL: $prof  (tail of execute.log)"
		tr -d '\r' < "$obj/sil_test/execute.log" 2>/dev/null | tail -15 | sed 's/^/    /'
		FAIL=1; FAIL_CNT=$((FAIL_CNT + 1)); SUMMARY+=("FAIL $prof (run)")
	fi
}

echo "##### TTSP3 SIL CI: profiles=[${PROFILES[*]}] target=$TARGET #####"
for p in "${PROFILES[@]}"; do
	run_one "$p"
done

echo ""
echo "##### SIL CI 結果サマリ #####"
for s in "${SUMMARY[@]}"; do echo "  $s"; done
echo "  PASS=$PASS_CNT  FAIL=$FAIL_CNT"
exit $FAIL
