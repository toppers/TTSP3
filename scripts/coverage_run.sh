#!/bin/bash
#
#  TTSP3 カバレッジ計測ランナー
#
#  ビルド済みの全テストバイナリ（check_library / api auto_code / api scratch）を
#  QEMU + drcovプラグインで再実行し，scripts/ttsp_coverage.py で
#  カーネル非依存部（asp3/kernel/）の行カバレッジを統合レポートする．
#
#  前提：scripts/ci_run.sh 等で各 obj/ 配下に asp がビルド済みであること．
#
#  環境変数：
#    DRCOV_PLUGIN : libdrcov.so のパス（既定: 自動探索）
#    QEMU_TIMEOUT : QEMU 1実行あたりのタイムアウト秒（既定 1800）
#    COV_FILTER   : 集計対象パスフィルタ（既定 /asp3/kernel/）
#
set -u
cd "$(dirname "$0")/.."

QEMU_TIMEOUT="${QEMU_TIMEOUT:-1800}"
COV_FILTER="${COV_FILTER:-/asp3/kernel/}"

# drcovプラグインの探索
if [ -z "${DRCOV_PLUGIN:-}" ]; then
	for cand in \
		"$HOME/qemu/qemu-11.0.0/build/contrib/plugins/libdrcov.so" \
		/opt/qemu-ttsp3/lib/qemu/plugins/libdrcov.so \
		/usr/lib/qemu/plugins/libdrcov.so; do
		if [ -f "$cand" ]; then
			DRCOV_PLUGIN="$cand"
			break
		fi
	done
fi
test -f "${DRCOV_PLUGIN:-}" || {
	echo "ERROR: libdrcov.so が見つからない（DRCOV_PLUGIN で指定）"; exit 1; }
echo "plugin: $DRCOV_PLUGIN"

# 対象ディレクトリ収集（ビルド済み asp があるもの）
dirs=""
for d in obj/check_library/* obj/api_test/auto_code_* obj/api_test/scratch_code/*; do
	[ -f "$d/asp" ] && dirs="$dirs $d"
done
test -n "$dirs" || { echo "ERROR: ビルド済みテストが無い（先に ci_run.sh 等でビルド）"; exit 1; }

n=0
for d in $dirs; do
	n=$((n + 1))
	echo "[$n] run with drcov: $d"
	( cd "$d" && timeout "$QEMU_TIMEOUT" qemu-system-arm -M xilinx-zynq-a9 \
		-semihosting -m 512M -serial null -serial mon:stdio -nographic \
		-kernel asp -plugin "$DRCOV_PLUGIN",filename=coverage.drcov \
		< /dev/null > /dev/null 2>&1 )
	rc=$?
	if [ $rc -ne 0 ] || [ ! -f "$d/coverage.drcov" ]; then
		echo "WARN: drcov取得失敗: $d (rc=$rc)"
	fi
done

echo ""
python3 scripts/ttsp_coverage.py --filter "$COV_FILTER" "$@" $dirs
