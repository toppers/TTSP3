# WB_UNREACHABLE.md — ASP3 kernel/ 未到達分岐 詳細分析

> 更新: 2026-06-10 (xsns_dpn_W-a 追加、exception.c 5/6 に更新)  
> 対象: ASP3 3.7.2 `kernel/`、残存 36 未到達分岐（1435/1471 = 97.6%、`all` モード）  
> 方式: gcov（`bash scripts/coverage_gcov_asp.sh all`）

このファイルは **WBテストを加えてもなお到達しない分岐**（`all` モードでの残存 25 分岐）の詳細分析を行う。  
- WBテストで到達済みの分岐 → [`WB_COVERAGE.md`](WB_COVERAGE.md)  
- BBテスト + WBテスト統合の最終カバレッジ → [`ALL_COVERAGE.md`](ALL_COVERAGE.md)

**計測条件（コンパイルオプション）:**
- `ENABLE_GCOV=true` — gcov 計装ビルド（`-fprofile-arcs -ftest-coverage`）
- `-DNDEBUG`（`COPTS` 経由） — `assert()` を `((void)(0))` に展開し分岐ノードを消滅させる。これにより task.c / mutex.c / wait.c / time_event.c の assert 失敗パスが計測対象外となる
- `-O2`（zybo_z7_gcc デフォルト） — `static inline` 関数の call-site インライン展開を促進し、wait.h の追跡分岐数が増加する（§5 参照）

**分類凡例:**
- **構造的到達不能**: カーネルの不変条件（恒真 flag、整合性保証ポインタ等）により実行時に到達できない。
- **実用的到達不能**: 理論上は可能だが QEMU では非現実的な前提（64 bit カウンタ折返し、数千秒タイマ等）が必要。
- **到達困難（制約あり）**: 理論的には到達可能だが、複数条件が同時成立する必要があり、コストに対して価値が低い。
- **到達困難（内部状態依存）**: 外部 API 操作では再現が難しい内部データ構造・状態が必要。
- **計測アーティファクト**: コンパイラの最適化（インライン展開）により同一ソース行が複数 call-site インスタンスとして追跡され、一部インスタンスが未到達になるもの。論理的カバレッジは確認済み。

---

## 1. exception.c — `xsns_dpn`（1 branch, 83.3%）

**ソース** (`asp3/kernel/exception.c` L101–102):
```c
state = (kerflg && exc_sense_intmask(p_excinf) && enadsp
                        && p_runtsk != NULL) ? false : true;
```

`&&` の短絡評価により GCC（`-O2`）は 6 分岐を生成する。BB テストで 4/6、WBテスト `xsns_dpn_W-a` で +1 = 5/6 をカバー済み。

> **2026-06-10 更新**: `kerflg==false` パスは WBテスト `xsns_dpn_W-a`（`ATT_INI` 初期化ルーチンからの呼び出し）で到達済み。`WB_COVERAGE.md` §5 に詳細。当初「構造的到達不能」と分類していたが、初期化ルーチン実行タイミング（`startup.c` L112-113、`kerflg=true` の L125 より前）を利用することで到達可能であった。

| gcov 位置 | 条件 | 未到達理由 | 分類 |
|---|---|---|---|
| L102 br[2] | `-O2` 最適化後の複合条件残分岐（`p_runtsk == NULL` に対応する可能性） | アイドルループ中（実行可能タスクなし）に CPU 例外が発生する必要があるが、テストタスク実行中は常に `p_runtsk != NULL`。 | **構造的到達不能**（テスト文脈） |

**結論**: 残 1 分岐は WB テスト追加不要。

---

## 2. mutex.c — `remove_mutex` L227 br[1]（1 branch, 99.3%）

**ソース** (`asp3/kernel/mutex.c` L224–232):
```c
pp_prevmtx = &(p_tcb->p_lastmtx);
while (*pp_prevmtx != NULL) {          /* L227 */
    if (*pp_prevmtx == p_mtxcb) {
        *pp_prevmtx = p_mtxcb->p_prevmtx;
        return;
    }
    pp_prevmtx = &((*pp_prevmtx)->p_prevmtx);
}
```

| gcov 位置 | 条件 | 未到達理由 | 分類 |
|---|---|---|---|
| L227 br[1]（ループ NULL 終了） | リスト末尾まで走査しても `p_mtxcb` が見つからない | `remove_mutex` は `p_mtxcb` がリストに存在することを呼出し側で保証した上でのみ呼ばれる（`unl_mtx`/`ini_mtx` 等は所有権確認済み）。NULL 終了はカーネル内部の一貫性違反を意味する。 | **構造的到達不能** |

**結論**: WB テストは不要。

---

## 3. task_refer.c — `ref_tsk` L131 br[10]（1 branch, 97.1%）

**ソース** (`asp3/kernel/task_refer.c` L131):
```c
switch (tstat & TS_WAITING_MASK) {
case TS_WAITING_SLP: ...
case TS_WAITING_DLY: ...
...
```

| gcov 位置 | 条件 | 未到達理由 | 分類 |
|---|---|---|---|
| L131 br[10]（switch JT 境界チェック） | `TS_WAITING_MASK` の有効範囲外の待ち状態コード | GCC の switch ジャンプテーブル最適化が生成する「範囲外 → デフォルト」の安全チェック分岐。有効な待ち状態コードのみカーネル内部から設定される。 | **構造的到達不能** |

**結論**: WB テストは不要。

---

## 4. time_manage.c — `adj_tim` L168 br[0]（1 branch, 95.5%）

**ソース** (`asp3/kernel/time_manage.c` L168):
```c
if (current_evttim < monotonic_evttim) {
```

| gcov 位置 | 条件 | 未到達理由 | 分類 |
|---|---|---|---|
| L168 br[0] | 64 bit `EVTTIM` 折返し後に `current_evttim < monotonic_evttim` | `EVTTIM` は uint64_t。折返しには約 5.85 × 10¹¹ 年の連続動作が必要。QEMU テストでは不可能。 | **実用的到達不能** |

**結論**: WB テストは不要。

---

## 5. wait.h — インライン展開アーティファクト（15 branches, 76.6%）

**背景**: O2 最適化により、wait.h の `static inline` 関数（`make_non_wait`、`wait_dequeue_wobj` 等）が多くの call-site でインライン展開される。

gcov はインライン展開された各 call-site インスタンスを独立した分岐として追跡する。Python union スクリプトは同一ソース行の分岐数を `max(各グループのブランチ数)` で取るため、インスタンスが多いグループの数に合わせた総数（64）になる。一部の call-site インスタンスが特定のグループで到達されないと「未到達」として計上される。

| 関数 | 論理的カバレッジ | アーティファクト状況 |
|---|---|---|
| `make_non_wait` L115（if `!TSTAT_SUSPENDED`） | 両分岐を複数グループで確認済み | 一部インスタンスが特定グループで未到達 |
| `wait_dequeue_wobj` L141（if `TSTAT_WAIT_WOBJ`） | 真偽両分岐を union で確認済み | 同上 |
| `queue_insert_tpri` L67/L69 | 両分岐を確認済み | 同上 |

分類: **計測アーティファクト**（論理的カバレッジは確認済み、追加テスト不要）

---

## 6. interrupt.c — `chg_ipm` L371 br[0]（1 branch, 98.3%）

**ソース** (`asp3/kernel/interrupt.c` L371):
```c
if (p_runtsk->raster && p_runtsk->enater) {
```

| gcov 位置 | 条件 | 未到達理由 | 分類 |
|---|---|---|---|
| L371 br[0]（`raster && enater` が真） | (1) タスク T が `enater=true` かつ (2) `chg_ipm` 実行中に (3) 別タスクが `ras_ter(T)` を呼び (4) T が `chg_ipm(TIPM_ENAALL)` に到達する、という競合タイミングが必要。 | **到達困難（制約あり）** |

**補足**: 既存テスト [`chg_ipm_e.yaml`](../../api_test/ASP/interrupt/chg_ipm/chg_ipm_e.yaml) は `enadsp=false`（L369 の真分岐不成立）のパスをカバー。L371 には `enadsp=true` かつ上記競合条件の同時成立が必要。

**結論**: WB テストで到達可能だが、コストに対して優先度低。当面未対応で可。

---

## 7. time_event.c — 内部タイムイベント管理（4 branches, 92.9%）

### 7-a. `_kernel_update_current_evttim` L390 br[0]

| gcov 位置 | 条件 | 未到達理由 | 分類 |
|---|---|---|---|
| L390 br[0]（`current_evttim < monotonic_evttim`） | 64 bit EVTTIM 折返し後の単調増加保証パス | §4 と同構造。約 5.8 × 10¹¹ 年の連続動作が必要。 | **実用的到達不能** |

### 7-b. `_kernel_set_hrt_event` L439 br[0]

| gcov 位置 | 条件 | 未到達理由 | 分類 |
|---|---|---|---|
| L439 br[0]（`hrtcnt > HRTCNT_BOUND`） | 次タイムイベントまで HRTCNT_BOUND（≈ 4,000 秒）超の待ち | QEMU テストの時間スケールでは発生しない。 | **実用的到達不能** |

### 7-c. `_kernel_signal_time` L624 br（`nocall == 0`）

| gcov 位置 | 条件 | 未到達理由 | 分類 |
|---|---|---|---|
| L624 br[0]（`nocall == 0`） | HRT 割込みが発生したが期限切れイベントが 0 件 | spurious interrupt / early fire が必要。QEMU の cycle-accurate モデルでは再現困難。 | **実用的到達不能**（タイミング依存） |

### 7-d. `_kernel_tmevt_down`（内部状態依存 ×1）

| gcov 位置 | 条件 | 未到達理由 | 分類 |
|---|---|---|---|
| sift-down 内部分岐 ×1 | 特定のヒープ配置でのみ通る経路 | `tmevt_down` の L221/L231 周辺は WBテスト [`time_event_W-a`](../../api_test/ASP/time_event/time_event_W-a/out.c) で大半を到達済み（[`WB_COVERAGE.md`](WB_COVERAGE.md) §5）だが、残 1 分岐は更に特定のヒープ深さ・配置を要し、外部 API 操作での再現が難しい。 | **到達困難（内部状態依存）** |

**結論（time_event.c 全体）**: 残 4 未到達分岐はすべて WB テスト追加不要（実用的到達不能 ×3 + 内部状態依存 ×1）。

---

## サマリ（残存 36 未到達分岐、`all` モード: 1435/1471 = 97.6%）

| ファイル | 未到達数 | 分類 | 対応方針 |
|---|---|---|---|
| wait.h | 17 | 計測アーティファクト（O2 インライン展開増加） | 不要 |
| time_event.c | 8 | 実用的到達不能 ×3 + 内部状態依存 ×1 + アーティファクト ×4 | 不要 |
| wait.c | 2 | 計測アーティファクト（WBテストビルドで分岐数増加） | 不要 |
| exception.c | 1 | 構造的到達不能（`p_runtsk==NULL` テスト文脈） | 不要 |
| interrupt.c | 1 | 到達困難（競合タイミング依存） | 低優先度・未対応で可 |
| mutex.c | 1 | 構造的到達不能（L227 NULL exit） | 不要 |
| task_refer.c | 1 | 構造的到達不能（JT 境界チェック） | 不要 |
| time_manage.c | 1 | 実用的到達不能（64 bit 折返し） | 不要 |
| task.c | 4 | 計測アーティファクト（インライン展開） | 不要 |
| **合計** | **36** | — | 全て WB テスト追加不要と判断 |

> **補注（分母増加について）**: `all` モードの分母 1471 は `bb` モードの 1459 より 12 多い。WBテストのビルドが `-O2` の最適化差異により wait.c/wait.h/time_event.c 等の分岐数を若干多く報告する計測アーティファクトによる。カバー済み分岐数（分子: 1435）が実質的なカバレッジを表す。

**現状の 97.6%（1435/1471、`all` モード）はテスト充足率として十分。**  
wait.h/wait.c の未到達分岐はインライン展開アーティファクトであり論理的カバレッジは確認済み。  
残存 7 箇所（アーティファクト除く）は、カーネルの不変条件・物理的制約・タイミング依存性により到達不能または到達困難であり、テストを追加しても仕様適合性の確認にはならない。
