# simt_coverage — ASP3 公式 simt テストによるタイマー分岐カバレッジ（参考トラック）

zybo 実 GIC タイマでは「実用的到達不能」な `kernel/time_event.c`・`kernel/time_manage.c` の
時刻関連分岐（HRTCNT_BOUND / signal_time nocall / 64bit 折返し）を、ASP3 開発元の
**simt（simulation timer）テスト**で C1 到達させるための補助ファイル。**asp3 を無改変**で、
ワークスペース側（build dir）のみで gcov 計測する。詳細・実証結果は
[`docs/ASP/BB_UNREACHABLE.md`](../../docs/ASP/BB_UNREACHABLE.md) 第3部。

| ファイル | 役割 |
|---|---|
| `ct11mpcore_gcov.ld` | `ct11mpcore.ld` ＋ `.gcov_info` 収集 ＋ `_heap`/`_heap_limit`（gcov 用）|
| `gcov_dump.c` | `software_term_hook` で `__gcov_info_to_gcda()` をセミホスティング出力（zybo 機構を流用）|
| `simt_suite.sh` | systim1-4 + 64hrt×3 を simtimer_ct11mpcore_gcc + gcov でビルド・QEMU(realview-eb-mpcore) 実行・union |

## 使い方（asp3 兄弟ディレクトリ、ビルド dir をワークスペースに作る）
1. `configure.rb -T simtimer_ct11mpcore_gcc -A <test> -C test_pf.cdl -a asp3/test -O "-DTOPPERS_USE_QEMU -DHRT_CONFIG{1,2,3} -DSIMTIM_TEST"`
2. 生成 Makefile の `include $(SRCDIR)/kernel/Makefile.kernel` 直前に gcov ブロックを挿入
   （`LDSCRIPT := ct11mpcore_gcov.ld` / `--coverage -fprofile-info-section` / `-DTOPPERS_ENABLE_GCOV` /
    `-specs=rdimon.specs -Wl,-u,toppers_gcov_end` / `-lgcov -lrdimon` / `KERNEL_COBJS += gcov_dump.o`）
3. `ct11mpcore_gcov.ld` と `gcov_dump.c` をビルド dir にコピー → `make`
4. `qemu-system-arm -M realview-eb-mpcore -semihosting -nographic -kernel asp` → `objs/*.gcda`
5. `ttsp_gcov_report.py --filter /asp3/kernel/ --by-function <build dirs>` で集計

`simt_suite.sh` は 1-5 を全テストで自動実行する（要編集: ビルド dir パス）。
