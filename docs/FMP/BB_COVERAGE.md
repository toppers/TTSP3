# BB_COVERAGE.md — FMP3 kernel/ BBテスト（自動生成テスト）カバレッジ

> 更新: 2026-06-10
> 対象: FMP3 3.4.0 `kernel/`
> 方式: gcov（`bash scripts/coverage_gcov_fmp.sh bb`）
> ターゲット: zybo_z7_gcc (Cortex-A9 dual-core, QEMU, -smp 2)
> モード: `bb` = check_library + API オートコード 20分割（**手書き WBテストを含まない**）

このファイルは **BBテスト（方式1: TESRY/YAML からの自動生成テスト）のみ** のカバレッジを記録する。
- BBで到達できない分岐の分析と、それを埋める WBテストの説明 → [`BB_UNREACHABLE.md`](BB_UNREACHABLE.md)
- BBテスト + WBテストを統合した最終カバレッジ → [`ALL_COVERAGE.md`](ALL_COVERAGE.md)

**計測条件（コンパイルオプション）:**
- `ENABLE_GCOV=true` — gcov 計装（`-fprofile-arcs -ftest-coverage`）
- `-DNDEBUG`（`COPTS` 経由） — `assert()` を無効化し分岐ノードを消滅させる（`t_stddef.h` の `#ifndef NDEBUG` で制御）
- `-O2`（zybo_z7_gcc デフォルト） — `static inline` 関数のインライン展開により wait.h 等の追跡分岐数が増加（計測アーティファクト）

---

## BBカバレッジ サマリ

**分岐カバレッジ（C1）: 1576/1677 = 94.0%**（gcov, ttsp_gcov_report.py, union集計, 23ディレクトリ = check_library 3 + auto_code 20）

行カバレッジ（C0）: 3507/3620 = 96.9%

---

## ファイル別 BBカバレッジ

| ファイル | 行 C0 | 分岐 C1 | BBで未到達 |
|---|---|---|---|
| alarm.c | 107/108 (99.1%) | 48/50 (96.0%) | 2 ◀ |
| check.h | 66/66 (100.0%) | 24/24 (100.0%) | — |
| cyclic.c | 110/111 (99.1%) | 46/48 (95.8%) | 2 ◀ |
| dataqueue.c | 317/333 (95.2%) | 136/136 (100.0%) | — |
| eventflag.c | 204/208 (98.1%) | 108/108 (100.0%) | — |
| exception.c | 12/12 (100.0%) | 5/8 (62.5%) | 3 ◀ |
| interrupt.c | 114/123 (92.7%) | 85/112 (75.9%) | 27 ◀ |
| mempfix.c | 182/186 (97.8%) | 74/76 (97.4%) | 2 ◀ |
| mutex.c | 250/256 (97.7%) | 127/134 (94.8%) | 7 ◀ |
| pridataq.c | 298/312 (95.5%) | 132/132 (100.0%) | — |
| semaphore.c | 153/157 (97.5%) | 66/66 (100.0%) | — |
| spin_lock.c | 91/91 (100.0%) | 37/38 (97.4%) | 1 ◀ |
| startup.c | 96/96 (100.0%) | 29/30 (96.7%) | 1 ◀ |
| sys_manage.c | 290/298 (97.3%) | 93/96 (96.9%) | 3 ◀ |
| task.c | 154/166 (92.8%) | 76/92 (82.6%) | 16 ◀ |
| task.h | 17/17 (100.0%) | 8/8 (100.0%) | — |
| task_manage.c | 265/271 (97.8%) | 148/152 (97.4%) | 4 ◀ |
| task_refer.c | 86/86 (100.0%) | 32/33 (97.0%) | 1 ◀ |
| task_sync.c | 224/228 (98.2%) | 98/98 (100.0%) | — |
| task_term.c | 129/137 (94.2%) | 59/60 (98.3%) | 1 ◀ |
| time_event.c | 171/185 (92.4%) | 65/78 (83.3%) | 13 ◀ |
| time_event.h | 2/2 (100.0%) | 2/2 (100.0%) | — |
| time_manage.c | 67/68 (98.5%) | 20/22 (90.9%) | 2 ◀ |
| wait.c | 66/66 (100.0%) | 10/10 (100.0%) | — |
| wait.h | 36/37 (97.3%) | 48/64 (75.0%) | 16 ◀ |
| **TOTAL** | **3507/3620 (96.9%)** | **1576/1677 (94.0%)** | **101** |

> `◀` = BBテストで未到達の分岐あり。`wait.h` の 16 箇所は NDEBUG+O2 のインライン展開アーティファクト（論理的カバレッジは確認済み）。

---

## BBで未到達の分岐（概要）

BBテスト（自動生成）では計 101 分岐が未到達。これらは大きく 2 群に分かれる。

| 群 | 内容 | 対応 |
|---|---|---|
| **(A) WBテストで到達可能** | alarm.c (1) / cyclic.c (1) / exception.c (1) / time_event.c (3) — 計 6 分岐 | 手書き WBテスト（方式2）で到達 → `all` モードで解消（101→95）。詳細 → [`BB_UNREACHABLE.md`](BB_UNREACHABLE.md) 第1部 |
| **(B) WBテストでも到達不能/困難** | マルチコア遅延ディスパッチ (~33) / interrupt.c chg_ipm (27) / wait.h (16, アーティファクト) / サブ優先度機能 (19) / time_event.c (残) / その他 | 構造的・実用的到達不能、マルチコアタイミング依存、計測アーティファクト、または未実装の WBテスト候補（サブ優先度）。詳細・分類 → [`BB_UNREACHABLE.md`](BB_UNREACHABLE.md) 第2部 |

> WBテスト追加後の最終到達率（`all` モード = 1582/1677 = 94.3%）とファイル別 all 数値・ASP比較は [`ALL_COVERAGE.md`](ALL_COVERAGE.md) を参照。

---

## 更新手順

```bash
# BBテストのみで再計測
bash scripts/coverage_gcov_fmp.sh bb

# ファイル別 BB数値を再生成（このファイルの表を更新）
python3 scripts/ttsp_gcov_report.py --filter /fmp3/kernel/ \
    obj_fmp_gcov/check_library/* obj_fmp_gcov/api_test/auto_code_*
```

BBテスト（YAML）を追加・変更した場合は、上記でファイル別表と TOTAL を更新する。
