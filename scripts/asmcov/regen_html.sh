#!/bin/bash
#
#  既にビルド済みの asmcov 用テスト ELF から，依存部カバレッジ HTML を
#  「再ビルドせずに」再生成する軽量スクリプト．
#
#  coverage_asmcov_zybo.sh は smoke/bb 実行のたびに HTML（.S と .S+.c）を出すが，
#  スクラッチを1か所直して obj 内で再ビルドだけした後など，QEMU 実行と集計・HTML
#  生成だけをやり直したいときに使う（フル smoke の再実行は不要）．
#
#  使い方:
#    scripts/asmcov/regen_html.sh ASP|FMP|HRP|HRMP [OBJ_DIR]
#
#  対象: $OBJ_DIR/check_library/{exception,interrupt,timer,dep_scratch}/ の各 ELF．
#  出力: $OBJ_DIR/asmcov/html（.S のみ）, $OBJ_DIR/asmcov/html_full（.S＋.c）,
#        同 *_merged.info．
#
set -u
cd "$(dirname "$0")/../.."

PROFILE="${1:?usage: regen_html.sh ASP|FMP|HRP|HRMP [OBJ_DIR]}"
case "$PROFILE" in
	ASP)  prof=asp;  kbin=asp;  smp=1 ;;
	FMP)  prof=fmp;  kbin=fmp;  smp=2 ;;
	HRP)  prof=hrp;  kbin=hrp;  smp=1 ;;
	HRMP) prof=hrmp; kbin=hrmp; smp=2 ;;
	*) echo "ERROR: PROFILE must be ASP|FMP|HRP|HRMP"; exit 1 ;;
esac
OBJ_DIR="${2:-obj_${prof}_asmcov}"
OUT_DIR="$OBJ_DIR/asmcov"
ABS="$(cd scripts/asmcov && pwd)"
CAP_BYTES=$(( ${TRACE_CAP_MB:-96} * 1024 * 1024 ))
QEMU_TIMEOUT="${QEMU_TIMEOUT:-120}"
TESTS="exception interrupt timer dep_scratch"

test -d "$OBJ_DIR" || { echo "ERROR: $OBJ_DIR not found（先に smoke を実行してビルド）"; exit 1; }
mkdir -p "$OUT_DIR"

INFOS=""; FULL_INFOS=""
for d in $TESTS; do
	D="$OBJ_DIR/check_library/$d"
	[ -f "$D/$kbin" ] || { echo "SKIP (no ELF): $d"; continue; }
	( cd "$D" && rm -f q.fifo qemu.log; mkfifo q.fifo
	  python3 "$ABS/cap_stream.py" qemu.log "$CAP_BYTES" < q.fifo &
	  cp=$!
	  timeout "$QEMU_TIMEOUT" qemu-system-arm -M xilinx-zynq-a9 -semihosting -m 512M \
		-serial null -serial mon:stdio -nographic -smp "$smp" -kernel "$kbin" \
		-d in_asm,exec,nochain -D q.fifo < /dev/null > /dev/null 2>&1
	  wait $cp; rm -f q.fifo )
	info="$D/asmcov.info"; full="$D/asmcov_full.info"
	python3 "$ABS/branchcov.py" --elf "$D/$kbin" --log "$D/qemu.log" \
		--prefix arm-none-eabi- --include arch/arm_gcc/common --lcov "$info" 2>/dev/null >/dev/null
	python3 - "$info" "$full" <<-'PY'
		import os, sys
		src, full = sys.argv[1], sys.argv[2]
		alll, sl, keep = [], [], False
		for line in open(src):
		    if line.startswith('SF:'):
		        rp = os.path.realpath(line[3:].strip())
		        alll += ['TN:\n', 'SF:'+rp+'\n']; keep = rp.endswith('.S')
		        if keep: sl += ['TN:\n', 'SF:'+rp+'\n']
		        continue
		    alll.append(line)
		    if keep: sl.append(line)
		open(full,'w').writelines(alll); open(src,'w').writelines(sl)
	PY
	rm -f "$D/qemu.log"
	[ -s "$info" ] && INFOS="$INFOS -a $info"
	[ -s "$full" ] && FULL_INFOS="$FULL_INFOS -a $full"
	echo "done: $d"
done

[ -n "$INFOS" ] || { echo "ERROR: no info produced"; exit 1; }
lcov $INFOS      -o "$OUT_DIR/asmcov_merged.info"      --rc lcov_branch_coverage=1 2>/dev/null >/dev/null
lcov $FULL_INFOS -o "$OUT_DIR/asmcov_full_merged.info" --rc lcov_branch_coverage=1 2>/dev/null >/dev/null
genhtml "$OUT_DIR/asmcov_merged.info"      -o "$OUT_DIR/html"      --num-spaces 4 --branch-coverage --rc genhtml_branch_coverage=1 >/dev/null 2>&1
genhtml "$OUT_DIR/asmcov_full_merged.info" -o "$OUT_DIR/html_full" --num-spaces 4 --branch-coverage --rc genhtml_branch_coverage=1 >/dev/null 2>&1
echo "  .S のみ : $OUT_DIR/html/index.html"
echo "  .S＋.c  : $OUT_DIR/html_full/index.html"
awk '
	/^SF:/ { n=split($0,a,"/"); f=a[n]; lf=lh=0 }
	/^LF:/ { sub("LF:",""); lf=$0 } /^LH:/ { sub("LH:",""); lh=$0 }
	/^end_of_record/ { tlh+=lh; tlf+=lf; if (f ~ /\.S$/){slh+=lh;slf+=lf} else {clh+=lh;clf+=lf} }
	END { if (tlf>0) printf "  %s: .S %d/%d(%.1f%%) | .c等 %d/%d(%.1f%%) | 合計 %d/%d(%.1f%%)\n",
	      "'$PROFILE'",slh,slf,(slf?100*slh/slf:0),clh,clf,(clf?100*clh/clf:0),tlh,tlf,100*tlh/tlf }
' "$OUT_DIR/asmcov_full_merged.info"
