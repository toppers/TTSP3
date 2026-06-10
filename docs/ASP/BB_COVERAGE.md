# BB_COVERAGE.md — ASP3 kernel/ BBテスト（自動生成テスト）カバレッジ

> 更新: 2026-06-10
> 対象: ASP3 3.7.2 `kernel/`
> 方式: gcov（`bash scripts/coverage_gcov_asp.sh bb`）
> モード: `bb` = check_library + API オートコード 20分割（**手書き WBテストを含まない**）

このファイルは **BBテスト（方式1: TESRY/YAML からの自動生成テスト）のみ** のカバレッジを記録する。
- BBで到達できない分岐の分析と、それを埋める WBテストの説明 → [`BB_UNREACHABLE.md`](BB_UNREACHABLE.md)
- BBテスト + WBテストを統合した最終カバレッジ → [`ALL_COVERAGE.md`](ALL_COVERAGE.md)

**計測条件（コンパイルオプション）:**
- `ENABLE_GCOV=true` — gcov 計装（`-fprofile-arcs -ftest-coverage`）
- `-DNDEBUG`（`COPTS` 経由） — `assert()` を無効化し分岐ノードを消滅させる（task.c / mutex.c / wait.c / time_event.c の assert 失敗パスを計測対象外にする）
- `-O2`（zybo_z7_gcc デフォルト） — インライン展開により wait.h の追跡分岐数が増加（計測アーティファクト）

---

## BBカバレッジ サマリ

**分岐カバレッジ（C1）: 1426/1459 = 97.7%**（gcov, ttsp_gcov_report.py, union集計, 23ディレクトリ = check_library 3 + auto_code 20）

行カバレッジ（C0）: 2439/2454 = 99.4%

---

## ファイル別 BBカバレッジ

| ファイル | 行 C0 | 分岐 C1 | BBで未到達 |
|---|---|---|---|
| alarm.c | 70/70 (100.0%) | 31/32 (96.9%) | 1 ◀ |
| cyclic.c | 74/74 (100.0%) | 35/36 (97.2%) | 1 ◀ |
| dataqueue.c | 253/253 (100.0%) | 156/156 (100.0%) | — |
| eventflag.c | 165/165 (100.0%) | 122/122 (100.0%) | — |
| exception.c | 7/7 (100.0%) | 4/6 (66.7%) | 2 ◀ |
| interrupt.c | 108/110 (98.2%) | 57/58 (98.3%) | 1 ◀ |
| mempfix.c | 150/150 (100.0%) | 88/90 (97.8%) | 2 ◀ |
| mutex.c | 212/212 (100.0%) | 137/138 (99.3%) | 1 ◀ |
| pridataq.c | 243/244 (99.6%) | 152/152 (100.0%) | — |
| semaphore.c | 121/121 (100.0%) | 78/78 (100.0%) | — |
| startup.c | 25/25 (100.0%) | 4/4 (100.0%) | — |
| sys_manage.c | 152/152 (100.0%) | 62/62 (100.0%) | — |
| task.c | 110/111 (99.1%) | 64/64 (100.0%) | — |
| task.h | 4/4 (100.0%) | 2/2 (100.0%) | — |
| task_manage.c | 119/119 (100.0%) | 92/92 (100.0%) | — |
| task_refer.c | 78/78 (100.0%) | 34/35 (97.1%) | 1 ◀ |
| task_sync.c | 169/169 (100.0%) | 118/118 (100.0%) | — |
| task_term.c | 94/94 (100.0%) | 64/64 (100.0%) | — |
| time_event.c | 131/141 (92.9%) | 48/56 (85.7%) | 8 ◀ |
| time_manage.c | 55/56 (98.2%) | 21/22 (95.5%) | 1 ◀ |
| wait.c | 61/61 (100.0%) | 8/8 (100.0%) | — |
| wait.h | 38/38 (100.0%) | 49/64 (76.6%) | 15 ◀ |
| **TOTAL** | **2439/2454 (99.4%)** | **1426/1459 (97.7%)** | **33** |

> `◀` = BBテストで未到達の分岐あり。`wait.h` の 15 箇所は NDEBUG+O2 のインライン展開アーティファクト（論理的カバレッジは確認済み）。

---

## BBで未到達の分岐（概要）

BBテスト（自動生成）では計 33 分岐が未到達。これらは大きく 2 群に分かれる。

| 群 | 内容 | 対応 |
|---|---|---|
| **(A) WBテストで到達可能** | alarm.c (1) / cyclic.c (1) / exception.c (1) / mempfix.c (2) / time_event.c (3) — 計 8 分岐 | 手書き WBテスト（方式2）で到達 → `all` モードで解消。詳細 → [`BB_UNREACHABLE.md`](BB_UNREACHABLE.md) 第1部 |
| **(B) WBテストでも到達不能/困難** | wait.h (15, アーティファクト) / time_event.c (残) / exception.c (1) / interrupt.c (1) / mutex.c (1) / task_refer.c (1) / time_manage.c (1) など | 構造的・実用的到達不能、または計測アーティファクト。詳細・分類 → [`BB_UNREACHABLE.md`](BB_UNREACHABLE.md) 第2部 |

> WBテスト追加後の最終到達率（`all` モード = 1435/1471 = 97.6%）と per-API 詳細・BBテスト追加履歴は [`ALL_COVERAGE.md`](ALL_COVERAGE.md) を参照。

---

## 更新手順

```bash
# BBテストのみで再計測
bash scripts/coverage_gcov_asp.sh bb

# ファイル別 BB数値を再生成（このファイルの表を更新）
python3 scripts/ttsp_gcov_report.py --filter /asp3/kernel/ \
    obj_asp_gcov/check_library/* obj_asp_gcov/api_test/auto_code_*
```

BBテスト（YAML）を追加・変更した場合は、上記でファイル別表と TOTAL を更新する。
