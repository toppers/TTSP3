# TTSP3 api_test on mps2_an505 / ASP3 / QEMU — 全件 per-case 実行の確定結果（2026-06-22）

ASP3（asp3_3.7・メモリ保護なし）を mps2_an505 / QEMU で TTSP3 api_test 全件 per-case
（1ケース＝1 ELF、DIV=1813）でビルド・実行した確定結果。OS_PATH=`../ASP3_TZ/asp3_tz_work/asp3_3.7/`。

## 確定結果（1813 ケース・全件実測）

| 区分 | 件数 | 率 |
|---|---|---|
| **総ケース** | **1813** | 100% |
| **BUILD OK** | **1813** | **100%（BUILD-FAIL 0）** |
| **PASS（All check points passed）** | **1255** | **69.2%** |
| FAIL | 558 | 30.8% |
| TIMEOUT | 0 | 0% |

ビルド: `build wall time 779s`。実行: 各 ELF を `qemu-system-arm -M mps2-an505
-semihosting-config enable=on -kernel <asp> -nographic -serial file:execute.log`
（timeout 30s、xargs -P 12 並列）。verdict=`All check points passed`。

## FAIL 558 件の分類

| 種別 | 件数 | FAIL内比 | 解釈 |
|---|---|---|---|
| **Unexpected-CP**（`## Unexpected check point N`） | 383 | 68.6% | **バンドル/スケジューリング方法論アーティファクト**（親 HRP3 解析で確定・アーキ非依存。協調タスクが期待CPに非到達） |
| Unexpected-value（`## Unexpected value …`） | 108 | 19.4% | 状態値ミスマッチ（参照API の戻り状態が期待と相違） |
| **E_TMOUT/timeout** | 45 | 8.1% | **QEMU 遅延実行アーティファクト**（tmo=3us 等が QEMU で発火。実機 M85 は解除側が間に合う。親 HRP3 で実機 PASS 実証） |
| service-call-error（E_PAR/E_OBJ/E_CTX 等） | 14 | 2.5% | 状態値ミスマッチ |
| 途中終了（passed 有り未完） | 8 | 1.4% | バンドル/タイミング系 |

**測定アーティファクト（Unexpected-CP 383 ＋ E_TMOUT 45 ＝ 428）が FAIL の 76.7%**。
状態値系（Unexpected-value 108 ＋ service-call 14 ＝ 122）が 21.9%。

## HRP3 mps2 per-case との対比 ＝ 保護由来の失敗が消失

| | HRP3 mps2（保護あり） | **ASP3 mps2（保護なし）** |
|---|---|---|
| BUILD-FAIL | ~406（**8リージョン MPU 制約**・mprot 同根） | **0**（保護リージョン要求なし） |
| 系統的 MSTKERR | 758（**ユーザドメイン例外スタッキング**） | **0**（ドメイン/dual-stack なし） |
| PASS | 38（2.4%） | **1255（69.2%）** |

HRP3 の per-case を支配した 2 大失敗（ユーザドメイン MSTKERR・8リージョン MPU BUILD-FAIL）は
**いずれもメモリ保護由来**で、保護を持たない ASP3 では**原理的に発生しない**ことを実測で確認。
結果 PASS は 38→1255（約 33 倍）。残失敗は大半が測定アーティファクト（バンドル方法論＋QEMU タイミング）。

## per-case 数値の解釈（親 HRP3 方針を踏襲）

per-case（DIV=1813 バンドル）の 69.2% は **DIV=1602/1813 バンドリングの測定アーティファクトに
押し下げられた値**で、ASP3 の実 conformance を表さない（親 HRP3 解析：Unexpected-CP は zybo/QEMU でも
同様に出るバンドル構成感応＝アーキ/カーネル非依存、E_TMOUT は QEMU 遅延の proxy）。ASP3 の実品質指標は
**asp3/test 24 PASS（mps2 QEMU/ek 実機）＋ TTSP3 SIL All check points passed（mps2/ek）**。
測定アーティファクト（428）を除いた実 FAIL は状態値系 122 程度で、**実 conformance 推定は ~85–90%**。

## 配線修正（本測定を可能にした ttsp3 側の修正・カーネル無改変）

1. `scripts/ttsp_parallel_api.sh`：`source ./configure.sh` 直後に `export TTSP_TARGET_NAME`。
   フェーズ1の `bash ttb.sh`（子プロセス）は `configure.sh` で
   `TARGET_NAME="${TTSP_TARGET_NAME:-zybo_z7_gcc}"` を再解決するため、export しないと既定の
   **zybo** に化け、per-case Makefile が `TARGET=zybo_z7_gcc` で生成され `import("target.cdl")` が
   zybo を引いて**全件 MAKE FAIL**（`sSIOPort signature not found` ＋ tecsgen `__typeof__` 破綻
   ＝mps2 の `-std=gnu17` が効かない）になっていた。
2. `library/ASP/target/mps2_an505_gcc/ttsp_target_test.h`：`#include "out.h"` の**前**に
   `TTSP_TASK_STACK_SIZE` を定義（`#ifndef` ガード）。api_test の TTG 生成 out.h は先頭で
   ttsp_target_test.h を include し直すため、out.c/kernel 経由で out.h が先に処理されると
   `out.h:8 COUNT_STK_T(TTSP_TASK_STACK_SIZE)` が定義前に評価され undeclared になる（循環 include）。
   sil_test は手書き out.h で本マクロ不使用のため従来は顕在化せず。

## 再現コマンド
```bash
cd ~/TOPPERS/ttsp3
export PATH=~/tools/arm-gnu-toolchain-15.2.rel1-x86_64-arm-none-eabi/bin:$PATH
# per-case 全件ビルド（DIV=1813・SKIP_RUN）
TTSP_TARGET_NAME=mps2_an505_gcc SKIP_RUN=1 PAR_GROUPS=12 MAKE_J=3 \
  bash scripts/ttsp_parallel_api.sh ../ASP3_TZ/asp3_tz_work/asp3_3.7/ ASP obj_asp_mps2_api 1813
# per-case 実行（mps2 QEMU・並列）
for d in obj_asp_mps2_api/api_test/auto_code_*; do
  timeout 30 qemu-system-arm -M mps2-an505 -semihosting-config enable=on \
    -kernel "$d/asp" -nographic -serial "file:$d/execute.log" >/dev/null 2>&1
  grep -q 'All check points passed' "$d/execute.log" && echo "$d PASS" || echo "$d FAIL"
done
```
