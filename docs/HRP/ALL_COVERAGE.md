# ALL_COVERAGE.md — HRP3 kernel/ 分岐カバレッジ（zybo_z7_gcc・ASP/FMP 同条件）

> 計測日: 2026-06-14（`bb` モード＝API auto-code 20分割 + check_library）
> 方式: gcov（`COPTS="-fno-inline …" bash scripts/coverage_gcov_hrp.sh bb` → `python3 scripts/ttsp_gcov_report.py --filter /hrp3/kernel/`）
> 対象: HRP3 (`../hrp3/`) `kernel/`、ターゲット **zybo_z7_gcc**（Cortex-A9 single-core, QEMU `xilinx-zynq-a9` `-smp 1`）
> 計測範囲: check_library 3/3 ＋ API auto-code **19/20**（残 1 群 `auto_code_19` は gcov 計装時の memory overlap で build 脱落。下記）
>
> **本ファイルは ASP/FMP の [`ALL_COVERAGE.md`](../ASP/ALL_COVERAGE.md) と同条件（インライン抑制）で再計測した HRP 版**。
> HRP には手書き WBテスト（`*_W-*`）が無いため **`all` モード＝`bb` モード**（[`BB_COVERAGE.md`](BB_COVERAGE.md) と同様）。
> - bring-up 経緯・真因・旧条件（インライン抑制なし line 89.4%/branch 81.7%）の記録 → [`COVERAGE_STATUS.md`](COVERAGE_STATUS.md)
> - 未到達分岐の分析 → [`BB_UNREACHABLE.md`](BB_UNREACHABLE.md)
> - R5（zcu102_r5_gcc / MPU）版カバレッジ → [`COVERAGE_R5.md`](COVERAGE_R5.md)
> - 合否（PASS/FAIL）の正本 → [`../STATUS.md`](../STATUS.md)
>
> **計測条件（コンパイルオプション）:**
> - `ENABLE_GCOV=true` — gcov 計装（`--coverage -fprofile-info-section`＋`__gcov_info_to_gcda`／セミホスティング）
> - `-DNDEBUG`（`COPTS` 経由） — `assert()` を無効化し、仕様適合性でない分岐ノードを計測対象から除外
> - **`-O2` + インライン抑制**（`-fno-inline -fno-inline-functions-called-once -fno-inline-small-functions`） — `-O2` の `static inline` 展開で gcov が各 call-site を個別計測して分岐数が水増しされる（wait.h 等）アーティファクトを除去。各 inline 関数を1実体として計測し論理分岐がそのまま反映される。**ASP/FMP と同条件**（これにより 3 プロファイルの分岐数が比較可能）。

## 全体サマリ（gcov 全分岐, ttsp_gcov_report.py, union集計）

```
行カバレッジ  (kernel/): 2989/3338 = 89.5%  (C0)
分岐カバレッジ(kernel/): 1991/2429 = 82.0%  (C1, 2026-06-14 NDEBUG + -O2インライン抑制計測、bb=all モード)
  ※インライン抑制条件（ASP/FMP 同条件）での再計測。旧・抑制なし計測（COVERAGE_STATUS.md）は
    line 89.4%(2982/3334)/branch 81.7%(2070/2533)で、分母が膨らんでいた（wait.h 等のインライン水増し）。
    抑制により wait.h 76→12・wait.c 等が論理分岐どおりになり、分母 2533→2429 に縮小、branch 81.7→82.0%。
  ※check_library(exc/int/timer) 3/3 ＋ API auto-code 19/20 を union 集計。
  ※API auto-code の残 1 群 auto_code_19 は gcov 計装時のみ memory objects overlap で build 脱落
    （保護ドメインのコード/データが計装で約2倍に膨張。非gcov の合否は 20/20＝STATUS.md §1）。
  ※主要な標準API（task/semaphore/eventflag/dataqueue/pridataq/mutex/mempfix/alarm/cyclic/wait/
    interrupt/task_*）は C1 90〜100%。残ギャップは保護ドメイン機能（domain.c/mem_manage.c/memory.c/
    sys_manage.c/messagebuf.c の一部）で、保護ドメイン固有テストが未整備（ASP/FMP には無い HRP 固有部）。
```

## ファイル別サマリ（gcov 全分岐、union集計、NDEBUG＋インライン抑制計測）

| ファイル | 行 C0 | 到達分岐 | 全分岐 | C1 |
|---|---|---|---|---|
| alarm.c | 75/75 100% | 48 | 50 | 96.0% ◀ |
| cyclic.c | 80/80 100% | 50 | 54 | 92.6% ◀ |
| dataqueue.c | 266/266 100% | 207 | 212 | 97.6% ◀ |
| domain.c | 37/187 19.8% | 6 | 90 | 6.7% ◀ |
| eventflag.c | 176/176 100% | 166 | 172 | 96.5% ◀ |
| exception.c | 8/8 100% | 7 | 10 | 70.0% ◀ |
| interrupt.c | 118/118 100% | 88 | 96 | 91.7% ◀ |
| mem_manage.c | 33/65 50.8% | 21 | 62 | 33.9% ◀ |
| memory.c | 26/47 55.3% | 7 | 20 | 35.0% ◀ |
| mempfix.c | 160/160 100% | 128 | 136 | 94.1% ◀ |
| messagebuf.c | 272/288 94.4% | 113 | 218 | 51.8% ◀ |
| mutex.c | 219/219 100% | 164 | 166 | 98.8% ◀ |
| pridataq.c | 259/259 100% | 212 | 222 | 95.5% ◀ |
| semaphore.c | 128/128 100% | 103 | 106 | 97.2% ◀ |
| startup.c | 32/32 100% | 6 | 6 | **100%** |
| svc_table.c | 0/2 0% | — | — | （拡張SVC表・本スイート未使用） |
| sys_manage.c | 175/267 65.5% | 106 | 202 | 52.5% ◀ |
| task.c | 130/130 100% | 60 | 62 | 96.8% ◀ |
| task.h | 11/11 100% | 8 | 8 | **100%** |
| task_manage.c | 127/127 100% | 125 | 130 | 96.2% ◀ |
| task_refer.c | 81/89 91.0% | 43 | 47 | 91.5% ◀ |
| task_sync.c | 176/176 100% | 137 | 140 | 97.9% ◀ |
| task_term.c | 97/97 100% | 75 | 80 | 93.8% ◀ |
| time_event.c | 138/165 83.6% | 54 | 78 | 69.2% ◀ |
| time_event.h | 2/2 100% | — | — | （分岐なし） |
| time_manage.c | 59/60 98.3% | 35 | 40 | 87.5% ◀ |
| wait.c | 68/68 100% | 10 | 10 | **100%** |
| wait.h | 36/36 100% | 12 | 12 | **100%** |
| **TOTAL** | **2989/3338 89.5%** | **1991** | **2429** | **82.0%** |

> ※ `◀` = 未到達分岐あり。`—` = 分岐なし（または計測対象なし）。
> ※ インライン抑制により wait.h は 76→12 分岐（旧 -O2 のインライン展開水増しが解消）、wait.c も論理分岐どおり 100%。
> ※ 低 C1 の domain.c(6.7%)/mem_manage.c(33.9%)/memory.c(35.0%)/sys_manage.c(52.5%)/messagebuf.c(51.8%) は
>   **保護ドメイン・メモリ保護機能**で、HRP 固有かつ保護ドメイン下の正常系/異常系テストが未整備（ASP/FMP に対応部が無い）。

### 3 プロファイル比較（C1, インライン抑制・同条件）

| Profile | C1（branch） | 出典 |
|---|---|---|
| ASP | 99.3%（1370/1379） | [`../ASP/ALL_COVERAGE.md`](../ASP/ALL_COVERAGE.md) |
| FMP | 97.1%（bb 1533/1597） | [`../FMP/ALL_COVERAGE.md`](../FMP/ALL_COVERAGE.md) |
| **HRP（zybo）** | **82.0%（1991/2429）** | 本ファイル |
| HRP（zcu102_r5/MPU） | 81.2%（2056/2533）※ | [`COVERAGE_R5.md`](COVERAGE_R5.md) |

> ※ R5 はインライン抑制なし条件で計測。HRP が ASP/FMP より低いのは保護ドメイン機能（domain.c 等）の
>   テスト未整備分。標準 API 部分は ASP/FMP 同様 90〜100%。

## 更新手順

```bash
# ベースライン再計測（ASP/FMP 同条件＝インライン抑制を COPTS で渡す）
COPTS="-fno-inline -fno-inline-functions-called-once -fno-inline-small-functions" \
    bash scripts/coverage_gcov_hrp.sh bb

# このファイルのファイル別表を再生成する集計
python3 scripts/ttsp_gcov_report.py --filter /hrp3/kernel/ \
    obj_hrp_gcov/check_library/* obj_hrp_gcov/api_test/auto_code_*
```

> 関連：合否は [`../STATUS.md`](../STATUS.md)（§2 にカバレッジ要約、§1 に合否）。能力差は [`../TARGETS.md`](../TARGETS.md)。
