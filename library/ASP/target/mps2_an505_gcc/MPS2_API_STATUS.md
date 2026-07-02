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

---

## ★A2 切り分け＋タイマ停止モードで PASS 1807/1813=99.7%（2026-07-02 確定）

### 再測定ベースライン（カーネル無改変・asp3_tz_work main `1d2ba24` の asp3_3.7）
PASS **1293**/1813（71.3%）。旧 1255 との差はタイミング揺れ（UNEXPECTED_CP↔PASS の入替わり）。
状態値系（UNEXPECTED_VALUE 119＋SVC_ERROR 10＋OTHER 8）＝**137**。

### 切り分け（状態値系 137）
- **全 137 件が tick 制御（`ttsp_target_stop_tick`/`gain_tick`）を使う `_ten` 系**（out.c grep で確認）
- 再々実行で 124 決定的 FAIL／13 フレーキー（時刻が止まらずレース化と整合）
- **zybo（A-profile・FUNC_TIME 動作環境）per-case では 137/137 全件 PASS**
  → アーキ非依存（スイート/仕様差）0 件・真のカーネルバグ 0 件・**全件 mps2 の tick 制御不全**

### 根因（target_timer.c／SysTick HRT）
`stop_tick`＝`target_hrt_terminate` は SysTick を止めるが、`gain_tick`＝`hrt_raise_event_body` と
signal_time 経由の `hrt_set_event_body` が **`hrt_program`（HRT_CTRL_RUN 書込み）で SysTick を再起動**
してしまい、凍結が解除されて実時間が流れ込む（timer check の `(system1+1)==system2` 不成立と同根）。

### 修正＝テスト用時刻停止モード（カーネルポート側・パッチ）
`docs/patches/asp3-mps2_an505-target_timer-test-stop-mode.patch`：`hrt_stopped` を追加し、
停止中は offset=0・program は再起動せず・raise_event は `hrt_base += 1us`＋手動ペンディング・
initialize は時刻継続で再開。**check_library timer が All check points passed** に。

### 修正後 per-case 全件（1813）
| 区分 | 素 | パッチ後 |
|---|---|---|
| **PASS** | 1293 | **1807（99.7%）** |
| UNEXPECTED_CP | 334 | **0** |
| E_TMOUT | 49 | **0** |
| 状態値系 | 137 | **6** |
| 回帰（PASS→FAIL） | — | **0** |

**重要な訂正**：旧解釈「Unexpected-CP＝バンドル方法論アーティファクト（アーキ非依存）・E_TMOUT＝QEMU
遅延アーティファクト」は、少なくとも本ターゲットの per-case では**どちらも tick 制御不全の間接症状**
だった（tick が止まらない→協調タスクの待ち合わせ・タイムアウトが実時間依存化）。パッチで全量解消。

### 残 FAIL 6（すべて tick と無関係のターゲット特性）
| ケース | 症状 | 分類 |
|---|---|---|
| clr_int_b / dis_int_b / ena_int_b / ras_int_b | 不正 intno に E_OK | NVIC の有効番号範囲がテスト前提と不一致（FMP linux_gcc 既知残と同型）。glue の不正 intno 定義見直しで回収可能性あり |
| prb_int_b | E_OBJ 期待に 0 | 同上 |
| CRE_TSK_h_1 | スタックアドレス不一致 | USE_TSKINICTXB（stk 非保持）系（STATUS §3 の既知ファミリ） |

**実 conformance ＝ 1807/1813（99.7%）**（残 6 はターゲット特性でありカーネル不適合ではない）。
再現データ：/tmp/a2_results.tsv（素）・/tmp/a2fix_results.tsv（パッチ後）・/tmp/a2_zybo_compare.tsv（zybo 比較）。
