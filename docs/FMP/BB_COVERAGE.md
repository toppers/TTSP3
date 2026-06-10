# BB_COVERAGE.md — FMP3 kernel/ BBテスト（自動生成テスト）カバレッジ

> 更新: 2026-06-10（-O2 + インライン抑制で再計測）
> 対象: FMP3 3.4.0 `kernel/`
> 方式: gcov（`bash scripts/coverage_gcov_fmp.sh bb`）
> ターゲット: zybo_z7_gcc (Cortex-A9 dual-core, QEMU, -smp 2)
> モード: `bb` = check_library + API オートコード 20分割（**手書き WBテストを含まない**）

このファイルは **BBテスト（方式1: TESRY/YAML からの自動生成テスト）のみ** のカバレッジを記録する。
- BBで到達できない分岐の分析と、それを埋める WBテストの説明 → [`BB_UNREACHABLE.md`](BB_UNREACHABLE.md)
- BBテスト + WBテストを統合した最終カバレッジ → [`ALL_COVERAGE.md`](ALL_COVERAGE.md)

**計測条件（コンパイルオプション）:**
- `ENABLE_GCOV=true` — gcov 計装（`-fprofile-arcs -ftest-coverage`）
- `-DNDEBUG`（`COPTS` 経由） — `assert()` を無効化し分岐ノードを消滅させる（assert 失敗パスは仕様適合性の分岐ではないため計測対象外）
- **`-O2` + インライン抑制**（`-fno-inline -fno-inline-functions-called-once -fno-inline-small-functions`）
  - **理由**: `-O2` は `static inline`（TOPPERS の `Inline` マクロ）関数を多数の呼出し元へ展開し、gcov が各 call-site インスタンスを個別計測することで同一ソース行の分岐数が水増しされる（例: wait.h）計測アーティファクトを生む。インライン抑制で各 inline 関数を1実体として計測し、ソースの論理分岐がそのまま反映され、bb/all の分母も一致する。`-O0` ではなく `-O2` を維持するのは codegen を production 同等に保ち、`-O0` で観測された実行時クラッシュ・タイミング変化を避けるため（詳細理由は ASP [`../ASP/BB_COVERAGE.md`](../ASP/BB_COVERAGE.md) 計測条件と同一）。

---

## BBカバレッジ サマリ

**分岐カバレッジ（C1）: 1533/1597 = 96.0%**（gcov, ttsp_gcov_report.py, union集計, 23ディレクトリ = check_library 3 + auto_code 20・2026-06-10 再計測）

行カバレッジ（C0）: 3522/3621 = 97.3%

> 2026-06-10 再計測で現状化（旧 1513/1597=94.7%）。**+20 分岐**＝サブ優先度BB（chg_spr_F-e-1/3/4/6）と
> interrupt負テストBB（`{ras,dis,ena,clr,prb}_int_F-e-1`）の寄与（いずれも auto_code 20グループ内・dir数不変）。

---

## ファイル別 BBカバレッジ

| ファイル | 行 C0 | 分岐 C1 | BBで未到達 |
|---|---|---|---|
| alarm.c | 107/108 (99.1%) | 48/50 (96.0%) | 2 ◀ |
| check.h | 66/66 (100.0%) | 24/24 (100.0%) | — |
| cyclic.c | 110/111 (99.1%) | 46/48 (95.8%) | 2 ◀ |
| dataqueue.c | 317/333 (95.2%) | 132/132 (100.0%) | — |
| eventflag.c | 204/208 (98.1%) | 106/106 (100.0%) | — |
| exception.c | 12/12 (100.0%) | 7/10 (70.0%) | 3 ◀ |
| interrupt.c | 117/123 (95.1%) | 99/116 (85.3%) | 17 ◀ |
| mempfix.c | 182/186 (97.8%) | 72/74 (97.3%) | 2 ◀ |
| mutex.c | 251/256 (98.0%) | 127/132 (96.2%) | 5 ◀ |
| pridataq.c | 299/312 (95.8%) | 128/128 (100.0%) | — |
| semaphore.c | 153/157 (97.5%) | 64/64 (100.0%) | — |
| spin_lock.c | 91/91 (100.0%) | 37/38 (97.4%) | 1 ◀ |
| startup.c | 96/96 (100.0%) | 29/30 (96.7%) | 1 ◀ |
| sys_manage.c | 290/298 (97.3%) | 93/96 (96.9%) | 3 ◀ |
| task.c | 164/167 (98.2%) | 71/78 (91.0%) | 7 ◀ |
| task.h | 17/17 (100.0%) | 8/8 (100.0%) | — |
| task_manage.c | 265/271 (97.8%) | 149/152 (98.0%) | 3 ◀ |
| task_refer.c | 86/86 (100.0%) | 32/33 (97.0%) | 1 ◀ |
| task_sync.c | 224/228 (98.2%) | 98/98 (100.0%) | — |
| task_term.c | 129/137 (94.2%) | 59/60 (98.3%) | 1 ◀ |
| time_event.c | 171/185 (92.4%) | 63/76 (82.9%) | 13 ◀ |
| time_event.h | 2/2 (100.0%) | —（分岐なし） | — |
| time_manage.c | 67/68 (98.5%) | 20/22 (90.9%) | 2 ◀ |
| wait.c | 66/66 (100.0%) | 8/8 (100.0%) | — |
| wait.h | 36/37 (97.3%) | 13/14 (92.9%) | 1 ◀ |
| **TOTAL** | **3522/3621 (97.3%)** | **1533/1597 (96.0%)** | **64** |

> インライン抑制により wait.h は 14 分岐に正規化（旧 -O2 のインライン水増しが解消。1 分岐のみ未到達）、wait.c・task.h は 100%。`-O2` 維持で auto_code 全20グループが segfault せず計測できる（`-O0` は一部グループがクラッシュ）。

---

## BBで未到達の分岐（概要）

BBテスト（自動生成）では計 84 分岐が未到達。2 群に分かれる。

| 群 | 内容 | 対応 |
|---|---|---|
| **(A) WBテストで到達可能（7分岐）** | alarm.c (1) / cyclic.c (1) / exception.c (2) / time_event.c (3) | 手書き WBテスト（方式2）で到達 → `all` で 84→77。詳細 → [`BB_UNREACHABLE.md`](BB_UNREACHABLE.md) 第1部 |
| **(B) all モードでも残る未到達（52分岐・2026-06-10 再計測）** | interrupt.c (17・`VALID_INTNO`構造的dead/check_intno_cfg複合/chg_ipm) / time_event (10) / マルチコア遅延ディスパッチ各所（timing） など。※サブ優先度(旧12+7)・割込み番号異常系(旧29→17)は 2026-06-10 のBB/WB追加で大幅縮小 | マルチコアタイミング依存・構造的到達不能等。詳細・分類 → [`BB_UNREACHABLE.md`](BB_UNREACHABLE.md) 第2部 / [`TIMING_TEST.md`](TIMING_TEST.md) |

> exception.c の 2 分岐（`check_tskctx()==false` / `p_runtsk==NULL`）は `xsns_dpn_W-a` / `xsns_dpn_W-b`（custom idle 方式）で到達し、`all` で 9/10。これにより (A) が 6→7、(B) が 78→77 となった（残 1 分岐 `kerflg_table==false` は構造的到達不能）。

> WBテスト追加後の最終到達率（`all` モード = 1545/1597 = 96.7%）とファイル別 all 数値・ASP比較は [`ALL_COVERAGE.md`](ALL_COVERAGE.md) を参照。

---

## 更新手順

```bash
# BBテストのみで再計測（スクリプトが -O2+インライン抑制 +NDEBUG を自動適用）
bash scripts/coverage_gcov_fmp.sh bb

# ファイル別 BB数値を再生成（このファイルの表を更新）
python3 scripts/ttsp_gcov_report.py --filter /fmp3/kernel/ \
    obj_fmp_gcov/check_library/* obj_fmp_gcov/api_test/auto_code_*
```

BBテスト（YAML）を追加・変更した場合は、上記でファイル別表と TOTAL を更新する。
