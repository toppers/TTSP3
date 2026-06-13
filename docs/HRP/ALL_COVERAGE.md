# ALL_COVERAGE.md — HRP3 kernel/ 分岐カバレッジ（zybo_z7_gcc・ASP/FMP 同条件）

> 計測日: 2026-06-14（`bb` モード＝API auto-code 20分割 + check_library）
> 方式: gcov（`COPTS="-fno-inline …" bash scripts/coverage_gcov_hrp.sh bb` → `python3 scripts/ttsp_gcov_report.py --filter /hrp3/kernel/`）
> 対象: HRP3 (`../hrp3/`) `kernel/`、ターゲット **zybo_z7_gcc**（Cortex-A9 single-core, QEMU `xilinx-zynq-a9` `-smp 1`）
> 計測範囲: check_library 3/3 ＋ API auto-code **20/20**（`auto_code_19` の gcov overlap は **M6 で解消済**＝SVN r1336）。
>
> **2026-06-14 更新（カバレッジ向上 M2/M3/M6 反映後）**：messagebuf・mem_manage・memory のテスト拡充と
> gcov overlap 回復で **branch 82.0%→87.1%（+124分岐）／line 89.5%→90.7%**。内訳・残は [`COVERAGE_RAISE_PLAN.md`](COVERAGE_RAISE_PLAN.md)。
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
行カバレッジ  (kernel/): 3029/3338 = 90.7%  (C0)
分岐カバレッジ(kernel/): 2115/2429 = 87.1%  (C1, 2026-06-14 NDEBUG + -O2インライン抑制、bb=all、M2/M3/M6反映後)
  ※カバレッジ向上 M2/M3/M6 反映後の値。着手前ベースライン（2026-06-14）は branch 82.0%(1991/2429)。
    - M6: auto_code_19 の gcov overlap 回復（.gcov_info 専用リージョン化・SVN r1336）→ +20分岐
    - M2: messagebuf 異常系/待ち/アクセス権 61テスト → messagebuf.c 51.8%→88.5%（+82分岐）
    - M3: ref_mem 新規＋prb_mem read 方向 → mem_manage.c 33.9%→80.6%・memory.c 35.0%→60.0%（+32分岐）
  ※check_library(exc/int/timer) 3/3 ＋ API auto-code 20/20 を union 集計（auto_code_19 含む）。
  ※インライン抑制（ASP/FMP 同条件）。旧・抑制なし計測（COVERAGE_STATUS.md）は line 89.4%/branch 81.7%
    （分母2533＝wait.h 等のインライン水増し）。抑制で分母2429に縮小し ASP/FMP と比較可能。
  ※主要な標準API（task/semaphore/eventflag/dataqueue/pridataq/mutex/mempfix/alarm/cyclic/wait/
    interrupt/task_*）は C1 90〜100%。残ギャップは domain.c（SOM/時間区画＝未テスト・M1調査中）と
    sys_manage.c（m系＝未実装・M4で到達可と判明）。向上計画は [`COVERAGE_RAISE_PLAN.md`](COVERAGE_RAISE_PLAN.md)。
```

## ファイル別サマリ（gcov 全分岐、union集計、NDEBUG＋インライン抑制計測）

| ファイル | 行 C0 | 到達分岐 | 全分岐 | C1 |
|---|---|---|---|---|
| alarm.c | 75/75 100% | 48 | 50 | 96.0% ◀ |
| cyclic.c | 80/80 100% | 51 | 54 | 94.4% ◀ |
| dataqueue.c | 266/266 100% | 208 | 212 | 98.1% ◀ |
| domain.c | 37/187 19.8% | 6 | 90 | 6.7% ◀ |
| eventflag.c | 176/176 100% | 168 | 172 | 97.7% ◀ |
| exception.c | 8/8 100% | 7 | 10 | 70.0% ◀ |
| interrupt.c | 118/118 100% | 89 | 96 | 92.7% ◀ |
| mem_manage.c | 64/65 98.5% | 50 | 62 | 80.6% ◀ *(M3: 33.9%→)* |
| memory.c | 37/47 78.7% | 12 | 20 | 60.0% ◀ *(M3: 35.0%→)* |
| mempfix.c | 160/160 100% | 129 | 136 | 94.9% ◀ |
| messagebuf.c | 272/288 94.4% | 193 | 218 | 88.5% ◀ *(M2: 51.8%→)* |
| mutex.c | 219/219 100% | 164 | 166 | 98.8% ◀ |
| pridataq.c | 259/259 100% | 213 | 222 | 95.9% ◀ |
| semaphore.c | 128/128 100% | 105 | 106 | 99.1% ◀ |
| startup.c | 32/32 100% | 6 | 6 | **100%** |
| svc_table.c | 0/2 0% | — | — | （拡張SVC表・本スイート未使用） |
| sys_manage.c | 175/267 65.5% | 106 | 202 | 52.5% ◀ *(M4: m系で到達可・未実装)* |
| task.c | 130/130 100% | 60 | 62 | 96.8% ◀ |
| task.h | 11/11 100% | 8 | 8 | **100%** |
| task_manage.c | 127/127 100% | 125 | 130 | 96.2% ◀ |
| task_refer.c | 81/89 91.0% | 43 | 47 | 91.5% ◀ |
| task_sync.c | 174/176 98.9% | 136 | 140 | 97.1% ◀ |
| task_term.c | 97/97 100% | 76 | 80 | 95.0% ◀ |
| time_event.c | 138/165 83.6% | 54 | 78 | 69.2% ◀ |
| time_event.h | 2/2 100% | — | — | （分岐なし） |
| time_manage.c | 59/60 98.3% | 36 | 40 | 90.0% ◀ |
| wait.c | 68/68 100% | 10 | 10 | **100%** |
| wait.h | 36/36 100% | 12 | 12 | **100%** |
| **TOTAL** | **3029/3338 90.7%** | **2115** | **2429** | **87.1%** |

> ※ `◀` = 未到達分岐あり。`—` = 分岐なし（または計測対象なし）。`(Mx: …→)` = 当該 Method で改善。
> ※ インライン抑制により wait.h は 76→12 分岐（旧 -O2 のインライン展開水増しが解消）、wait.c も論理分岐どおり 100%。
> ※ 残る大ギャップは **domain.c(6.7%)＝SOM/時間区画スケジューリングが未テスト**（M1 で実現可否調査中）と
>   **sys_manage.c(52.5%)＝m系(mrot_rdq/mget_*)が未実装**（M4 で HRP 到達可＝schedno=DOMID と判明、+90分岐見込み）。
>   いずれも HRP 固有機能。詳細は [`COVERAGE_RAISE_PLAN.md`](COVERAGE_RAISE_PLAN.md)。

### 3 プロファイル比較（C1, インライン抑制・同条件）

| Profile | C1（branch） | 出典 |
|---|---|---|
| ASP | 99.3%（1370/1379） | [`../ASP/ALL_COVERAGE.md`](../ASP/ALL_COVERAGE.md) |
| FMP | 97.1%（bb 1533/1597） | [`../FMP/ALL_COVERAGE.md`](../FMP/ALL_COVERAGE.md) |
| **HRP（zybo）** | **87.1%（2115/2429）** | 本ファイル（M2/M3/M6 反映後。着手前 82.0%） |
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
