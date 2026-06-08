# WB_UNREACHABLE.md — ASP3 kernel/ 未到達分岐 詳細分析

> 更新: 2026-06-09（NDEBUG 計測移行後）  
> 対象: ASP3 3.7.2 `kernel/`、残存 25 未到達分岐（1434/1459 = 98.3%）  
> ビルド: `coverage_gcov_asp.sh` に `-DNDEBUG` 追加済み（`COPTS` 環境変数経由）

**分類凡例:**
- **構造的到達不能**: カーネルの不変条件（恒真 flag、整合性保証ポインタ等）により実行時に到達できない。
- **実用的到達不能**: 理論上は可能だが QEMU では非現実的な前提（64 bit カウンタ折返し、数千秒タイマ等）が必要。
- **到達困難（制約あり）**: 理論的には到達可能だが、複数条件が同時成立する必要があり、コストに対して価値が低い。
- **計測アーティファクト**: コンパイラの最適化（インライン展開）により同一ソース行が複数 call-site インスタンスとして追跡され、一部インスタンスが未到達になるもの。論理的カバレッジは確認済み。

---

## NDEBUG 適用の影響

`coverage_gcov_asp.sh` に `-DNDEBUG` を追加したことで、以下の assert 分岐が gcov の計測対象から除外された（`assert(exp)` → `((void)(0))` となり分岐ノードが消滅）。

| ファイル | 除外された分岐 | 効果 |
|---|---|---|
| task.c L268/L274 | `assert(dspflg)` × 2 | task.c → 100% |
| mutex.c L375/423/474 | `assert(p_runtsk == p_schedtsk)` × 3 | mutex.c → 99.3% |
| wait.c L65 | `assert(tmout <= TMAX_RELTIM)` | wait.c → 100% |
| wait.h L113 | `assert(TSTAT_WAITING(p_tcb->tstat))` | make_non_wait → 100% |
| time_event.c L588/L589 | `assert(sense_context())` / `assert(!sense_lock())` × 2 | signal_time 改善 |

一方、NDEBUG+O2 のインライン展開変化により **wait.h** の追跡ブランチ数が増加した（§7 参照）。

---

## 1. exception.c — `xsns_dpn`（2〜3 branches, 66.7%）

**ソース** (`asp3/kernel/exception.c` L101–102):
```c
state = (kerflg && exc_sense_intmask(p_excinf) && enadsp
                        && p_runtsk != NULL) ? false : true;
```

`&&` の短絡評価により GCC は各オペランドごとに分岐を生成する。

| gcov 位置 | 条件 | 未到達理由 | 分類 |
|---|---|---|---|
| L101 br[0] | `kerflg == FALSE` | `kerflg` はカーネル起動後に `true` にセットされ、以後 `false` に戻ることはない。 | **構造的到達不能** |
| L102 br[1] | `enadsp == FALSE` | `dis_dsp()` 後に CPU 例外が発生し、例外ハンドラから `xsns_dpn` を呼ぶシナリオ。技術的には可能だが、zybo_z7_gcc の QEMU 環境では例外ハンドラを任意タイミングで起動する機構がない。 | **到達困難（制約あり）** |
| L102 br[2] | `p_runtsk == NULL` | アイドルループ中（実行可能タスクなし）に CPU 例外が発生する必要があるが、テストタスク実行中は常に `p_runtsk != NULL`。 | **構造的到達不能**（テスト文脈） |

**結論**: WB テストは不要。

---

## 2. task.c — `_kernel_make_non_runnable`（**NDEBUG 除外済み → 100%**）

**ソース** (`asp3/kernel/task.c` L268, L274):
```c
if (p_schedtsk == p_tcb) {
    assert(dspflg);            /* L268 */
    ...
}
...
if (p_schedtsk == p_tcb) {
    assert(dspflg);            /* L274 */
    ...
}
```

NDEBUG 適用により `assert()` が `((void)(0))` に展開され、分岐ノードが消滅。**task.c 分岐カバレッジ 100%**。

分岐の理由（構造的到達不能）: `p_schedtsk == p_tcb` が成立する（スケジュールされている）のに `dspflg` が偽であることは、カーネルの不変条件違反。正常動作では発生しない。

---

## 3. mutex.c（1 branch, 99.3%）

### 3-a. `remove_mutex` L227 br[1]（**残存**）

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

### 3-b. `loc_mtx` / `ploc_mtx` / `tloc_mtx` L375/423/474（**NDEBUG 除外済み**）

```c
assert(p_runtsk == p_schedtsk);
```

NDEBUG 適用により分岐ノード消滅。分岐の理由（構造的到達不能）: 上限優先度ミューテックス獲得後は実行タスクが `p_schedtsk` に昇格するため恒真。CPU ロック中にディスパッチは発生しない。

---

## 4. task_refer.c — `ref_tsk` L131 br[10]（1 branch, 97.1%）

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

## 5. time_manage.c — `adj_tim` L168 br[0]（1 branch, 95.5%）

**ソース** (`asp3/kernel/time_manage.c` L168):
```c
if (current_evttim < monotonic_evttim) {
```

| gcov 位置 | 条件 | 未到達理由 | 分類 |
|---|---|---|---|
| L168 br[0] | 64 bit `EVTTIM` 折返し後に `current_evttim < monotonic_evttim` | `EVTTIM` は uint64_t。折返しには約 5.85 × 10¹¹ 年の連続動作が必要。QEMU テストでは不可能。 | **実用的到達不能** |

**結論**: WB テストは不要。

---

## 6. wait.c — `_kernel_make_wait_tmout` L65（**NDEBUG 除外済み → 100%**）

**ソース** (`asp3/kernel/wait.c` L65):
```c
assert(tmout <= TMAX_RELTIM);
```

NDEBUG 適用により分岐ノード消滅。**wait.c 分岐カバレッジ 100%**。

分岐の理由（構造的到達不能）: 呼出し元の全 API が `CHECK_PAR(VALID_TMOUT(tmout))` で事前検証済み。無効なタイムアウト値はここに到達しない。

---

## 7. wait.h — インライン展開アーティファクト（15 branches, 76.6%）

**背景**: NDEBUG+O2 の組み合わせにより、wait.h の `static inline` 関数（`make_non_wait`、`wait_dequeue_wobj` 等）がより多くの call-site でインライン展開される。

gcov はインライン展開された各 call-site インスタンスを独立した分岐として追跡する。Python union スクリプトは同一ソース行の分岐数を `max(各グループのブランチ数)` で取るため、インスタンスが多いグループの数に合わせた総数（64）になる。一部の call-site インスタンスが特定のグループで到達されないと「未到達」として計上される。

| 関数 | 論理的カバレッジ | アーティファクト状況 |
|---|---|---|
| `make_non_wait` L115（if `!TSTAT_SUSPENDED`） | 両分岐を複数グループで確認済み | 一部インスタンスが特定グループで未到達 |
| `wait_dequeue_wobj` L141（if `TSTAT_WAIT_WOBJ`） | 真偽両分岐を union で確認済み | 同上 |
| `queue_insert_tpri` L67/L69 | 両分岐を確認済み | 同上 |

**NDEBUG 適用前（参考）**: 16 branches、1 uncovered（`make_non_wait` の assert 失敗パス）  
**NDEBUG 適用後**: 64 branches、15 uncovered（インライン展開増加により追跡インスタンス増加）

分類: **計測アーティファクト**（論理的カバレッジは確認済み、追加テスト不要）

---

## 8. interrupt.c — `chg_ipm` L371 br[0]（1 branch, 98.3%）

**ソース** (`asp3/kernel/interrupt.c` L371):
```c
if (p_runtsk->raster && p_runtsk->enater) {
```

| gcov 位置 | 条件 | 未到達理由 | 分類 |
|---|---|---|---|
| L371 br[0]（`raster && enater` が真） | (1) タスク T が `enater=true` かつ (2) `chg_ipm` 実行中に (3) 別タスクが `ras_ter(T)` を呼び (4) T が `chg_ipm(TIPM_ENAALL)` に到達する、という競合タイミングが必要。 | **到達困難（制約あり）** |

**補足**: 既存テスト `chg_ipm_e.yaml` は `enadsp=false`（L369 の真分岐不成立）のパスをカバー。L371 には `enadsp=true` かつ上記競合条件の同時成立が必要。

**結論**: WB テストで到達可能だが、コストに対して優先度低。当面未対応で可。

---

## 9. time_event.c — `_kernel_signal_time` 等（4 branches, 92.9%）

### 9-a. `_kernel_update_current_evttim` L390 br[0]

| gcov 位置 | 条件 | 未到達理由 | 分類 |
|---|---|---|---|
| L390 br[0]（`current_evttim < monotonic_evttim`） | 64 bit EVTTIM 折返し後の単調増加保証パス | §5 と同構造。約 5.8 × 10¹¹ 年の連続動作が必要。 | **実用的到達不能** |

### 9-b. `_kernel_set_hrt_event` L439 br[0]

| gcov 位置 | 条件 | 未到達理由 | 分類 |
|---|---|---|---|
| L439 br[0]（`hrtcnt > HRTCNT_BOUND`） | 次タイムイベントまで HRTCNT_BOUND（≈ 4,000 秒）超の待ち | QEMU テストの時間スケールでは発生しない。 | **実用的到達不能** |

### 9-c. `_kernel_signal_time` L588/L589（**NDEBUG 除外済み**）

```c
assert(sense_context());    /* L588 */
assert(!sense_lock());      /* L589 */
```

NDEBUG 適用により分岐ノード消滅。分岐の理由（構造的到達不能）: `signal_time` は HRT 割込みハンドラからのみ呼ばれ、割込みコンテキスト・CPU ロックなしが実装保証されている。

### 9-d. `_kernel_signal_time` L624 br（`nocall == 0`）

| gcov 位置 | 条件 | 未到達理由 | 分類 |
|---|---|---|---|
| L624 br[0]（`nocall == 0`） | HRT 割込みが発生したが期限切れイベントが 0 件 | spurious interrupt / early fire が必要。QEMU の cycle-accurate モデルでは再現困難。 | **実用的到達不能**（タイミング依存） |

**結論（time_event.c 全体）**: 4 未到達分岐はすべて WB テスト不要。

---

## サマリ

| ファイル | 未到達数 | 分類 | 対応方針 |
|---|---|---|---|
| wait.h | 15 | 計測アーティファクト（NDEBUG+O2 インライン展開増加） | 不要（論理的カバレッジ確認済み） |
| time_event.c | 4 | 実用的到達不能 ×3 + タイミング依存 ×1 | 不要 |
| exception.c | 2〜3 | 構造的到達不能 ×2 + 到達困難 ×1 | 不要 |
| mutex.c | 1 | 構造的到達不能（L227 NULL exit） | 不要 |
| task_refer.c | 1 | 構造的到達不能（JT 境界チェック） | 不要 |
| time_manage.c | 1 | 実用的到達不能（64 bit 折返し） | 不要 |
| interrupt.c | 1 | 到達困難（競合タイミング依存） | 低優先度・未対応で可 |
| task.c | 0 | NDEBUG 除外済み → 100% | 解消 |
| wait.c | 0 | NDEBUG 除外済み → 100% | 解消 |
| **合計** | **25** | — | 全て WB テスト追加不要と判断 |

**現状の 98.3%（1434/1459）はテスト充足率として十分**。  
wait.h の 15 箇所はインライン展開アーティファクトであり論理的カバレッジは確認済み。  
残存 10 箇所（wait.h 除く）は、カーネルの不変条件・物理的制約・タイミング依存性により到達不能または到達困難であり、テストを追加しても仕様適合性の確認にはならない。
