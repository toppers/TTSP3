# BB_COVERAGE.md — ASP3 kernel/ BBテスト（自動生成テスト）カバレッジ

> 更新: 2026-06-10（-O2 + インライン抑制で再計測）
> 対象: ASP3 3.7.2 `kernel/`
> 方式: gcov（`bash scripts/coverage_gcov_asp.sh bb`）
> モード: `bb` = check_library + API オートコード 20分割（**手書き WBテストを含まない**）

このファイルは **BBテスト（方式1: TESRY/YAML からの自動生成テスト）のみ** のカバレッジを記録する。
- BBで到達できない分岐の分析と、それを埋める WBテストの説明 → [`BB_UNREACHABLE.md`](BB_UNREACHABLE.md)
- BBテスト + WBテストを統合した最終カバレッジ → [`ALL_COVERAGE.md`](ALL_COVERAGE.md)

**計測条件（コンパイルオプション）:**
- `ENABLE_GCOV=true` — gcov 計装（`-fprofile-arcs -ftest-coverage`）
- `-DNDEBUG`（`COPTS` 経由） — `assert()` を無効化し分岐ノードを消滅させる（assert 失敗パスは仕様適合性の分岐ではないため計測対象外）
- **`-O2` + インライン抑制**（`-fno-inline -fno-inline-functions-called-once -fno-inline-small-functions`）
  - **理由**: `-O2` は `static inline`（TOPPERS の `Inline` マクロ）関数を多数の呼出し元へ展開し、gcov が各 call-site インスタンスを個別計測することで同一ソース行の分岐数が水増しされる（例: wait.h 16→64 分岐）計測アーティファクトを生む。さらに bb/all でビルド差により分母が変動する。インライン抑制で各 inline 関数を1実体として計測し、ソースの論理分岐がそのまま反映され、bb/all の分母も一致する。`-O0` ではなく `-O2` を維持するのは codegen を production 同等に保ち、`-O0` で観測された実行時クラッシュ・タイミング変化を避けるため。

---

## BBカバレッジ サマリ

**分岐カバレッジ（C1）: 1360/1379 = 98.6%**（`chg_ipm_f` 追加後）（gcov, ttsp_gcov_report.py, union集計, 23ディレクトリ = check_library 3 + auto_code 20）

行カバレッジ（C0）: 2447/2458 = 99.6%

---

## ファイル別 BBカバレッジ

| ファイル | 行 C0 | 分岐 C1 | BBで未到達 |
|---|---|---|---|
| alarm.c | 70/70 (100.0%) | 31/32 (96.9%) | 1 ◀ |
| cyclic.c | 74/74 (100.0%) | 35/36 (97.2%) | 1 ◀ |
| dataqueue.c | 253/253 (100.0%) | 152/152 (100.0%) | — |
| eventflag.c | 165/165 (100.0%) | 120/120 (100.0%) | — |
| exception.c | 7/7 (100.0%) | 6/8 (75.0%) | 2 ◀ |
| interrupt.c | 110/110 (100.0%) | 60/62 (96.8%) | 2 ◀ |
| mempfix.c | 150/150 (100.0%) | 86/88 (97.7%) | 2 ◀ |
| mutex.c | 212/212 (100.0%) | 135/136 (99.3%) | 1 ◀ |
| pridataq.c | 244/244 (100.0%) | 148/148 (100.0%) | — |
| semaphore.c | 121/121 (100.0%) | 76/76 (100.0%) | — |
| startup.c | 25/25 (100.0%) | 4/4 (100.0%) | — |
| sys_manage.c | 152/152 (100.0%) | 62/62 (100.0%) | — |
| task.c | 114/114 (100.0%) | 52/52 (100.0%) | — |
| task.h | 4/4 (100.0%) | —（分岐なし） | — |
| task_manage.c | 119/119 (100.0%) | 92/92 (100.0%) | — |
| task_refer.c | 78/78 (100.0%) | 34/35 (97.1%) | 1 ◀ |
| task_sync.c | 169/169 (100.0%) | 116/116 (100.0%) | — |
| task_term.c | 94/94 (100.0%) | 62/62 (100.0%) | — |
| time_event.c | 131/141 (92.9%) | 48/56 (85.7%) | 8 ◀ |
| time_manage.c | 55/56 (98.2%) | 21/22 (95.5%) | 1 ◀ |
| wait.c | 61/61 (100.0%) | 6/6 (100.0%) | — |
| wait.h | 39/39 (100.0%) | 14/14 (100.0%) | — |
| **TOTAL** | **2447/2458 (99.6%)** | **1360/1379 (98.6%)** | **19** |

> インライン抑制により wait.h（旧 49/64=76.6%）・wait.c・task.c のインライン展開アーティファクトが解消し、各 100%（論理分岐がそのまま計測される）。

---

## BBで未到達の分岐（概要）

BBテスト（自動生成）では計 19 分岐が未到達。2 群に分かれる。

| 群 | 内容 | 対応 |
|---|---|---|
| **(A) WBテストで到達可能（9分岐）** | alarm.c (1) / cyclic.c (1) / exception.c (1) / mempfix.c (2) / time_event.c (4) | 手書き WBテスト（方式2）で到達 → `all` モードで解消。詳細 → [`BB_UNREACHABLE.md`](BB_UNREACHABLE.md) 第1部 |
| **(B) WBテストでも到達不能/困難（10分岐）** | exception.c (1) / interrupt.c (2: clr_int/ras_int GIC恒真) / mutex.c (1) / task_refer.c (1) / time_event.c (4) / time_manage.c (1) | 構造的・実用的到達不能、または到達困難（競合/64bit折返し/HRTCNT_BOUND 等）。詳細・分類 → [`BB_UNREACHABLE.md`](BB_UNREACHABLE.md) 第2部 |

> WBテスト追加後の最終到達率（`all` モード = 1369/1379 = 99.3%）とファイル別 all 数値は [`ALL_COVERAGE.md`](ALL_COVERAGE.md) を参照。

---

## 更新手順

```bash
# BBテストのみで再計測（スクリプトが -O2+インライン抑制 +NDEBUG を自動適用）
bash scripts/coverage_gcov_asp.sh bb

# ファイル別 BB数値を再生成（このファイルの表を更新）
python3 scripts/ttsp_gcov_report.py --filter /asp3/kernel/ \
    obj_asp_gcov/check_library/* obj_asp_gcov/api_test/auto_code_*
```

BBテスト（YAML）を追加・変更した場合は、上記でファイル別表と TOTAL を更新する。
