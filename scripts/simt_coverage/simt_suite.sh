#!/bin/bash
set -u
WS=/home/honda/TOPPERS/TTSP3/work
inject() {
python3 - "$1" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
blk='''
LDSCRIPT := ct11mpcore_gcov.ld
COPTS := $(COPTS) --coverage -fprofile-info-section
CDEFS := $(CDEFS) -DTOPPERS_ENABLE_GCOV
LDFLAGS := $(LDFLAGS) -specs=rdimon.specs -Wl,-u,toppers_gcov_end
LIBS := $(LIBS) -Wl,--start-group -lgcov -lrdimon -lc -lgcc -Wl,--end-group
KERNEL_COBJS := $(KERNEL_COBJS) gcov_dump.o

include $(SRCDIR)/kernel/Makefile.kernel'''
s=s.replace('\ninclude $(SRCDIR)/kernel/Makefile.kernel', blk, 1)
open(p,'w').write(s)
PY
}
tests="systim1:simt_systim1::-DHRT_CONFIG1 -DSIMTIM_TEST
systim2:simt_systim2::-DHRT_CONFIG1 -DSIMTIM_TEST
systim3:simt_systim3::-DHRT_CONFIG1 -DSIMTIM_TEST
systim4:simt_systim4::-DHRT_CONFIG2 -DSIMTIM_TEST
systim1_64hrt:simt_systim1_64hrt:simt_systim1:-DHRT_CONFIG3 -DSIMTIM_TEST
systim2_64hrt:simt_systim2_64hrt:simt_systim2:-DHRT_CONFIG3 -DSIMTIM_TEST
systim3_64hrt:simt_systim3_64hrt:simt_systim3:-DHRT_CONFIG3 -DSIMTIM_TEST"
while IFS=: read -r name src cfg defs; do
  [ -z "$name" ] && continue
  d="$WS/bs_$name"; rm -rf "$d"; mkdir "$d"; cd "$d"
  cfgopt=""; [ -n "$cfg" ] && cfgopt="-c $cfg.cfg"
  ruby "$WS/asp3/configure.rb" -T simtimer_ct11mpcore_gcc -A "$src" -C test_pf.cdl $cfgopt -a "$WS/asp3/test" -O "-DTOPPERS_USE_QEMU $defs" > config.log 2>&1
  inject "$d/Makefile"
  cp "$WS/build_simt/ct11mpcore_gcov.ld" "$WS/build_simt/gcov_dump.c" "$d/"
  make > build.log 2>&1
  if [ -f asp ]; then
    rm -f objs/*.gcda
    timeout 120 qemu-system-arm -M realview-eb-mpcore -semihosting -nographic -kernel asp < /dev/null > run.log 2>&1
    echo "RUN $name: $(tr -d '\r' < run.log | grep -E 'All check|passed' | tail -1)  [gcda:$(ls objs/*.gcda 2>/dev/null|wc -l)]"
  else
    echo "BUILD FAIL $name: $(tail -2 build.log | head -1)"
  fi
  cd "$WS"
done <<< "$tests"
echo "===== UNION: simt suite の time_event/time_manage 主要関数 ====="
python3 "$WS/ttsp3/scripts/ttsp_gcov_report.py" --filter /asp3/kernel/ --by-function $WS/bs_systim* 2>/dev/null | grep -iE "^File|time_event.c|time_manage.c|set_hrt_event|signal_time|update_current_evttim|tmevtb_enqueue|tmevt_down|adj_tim|^TOTAL"
