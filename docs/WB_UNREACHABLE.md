# WB_UNREACHABLE.md — ASP3 kernel/ 未到達分岐 詳細分析

> 作成: 2026-06-09  
> 対象: ASP3 3.7.2 `kernel/`、残存 19 未到達分岐（1386/1405 = 98.6%）  
> 分類凡例:
> - **構造的到達不能**: コードの不変条件（恒真 flag、整合性保証ポインタ等）により実行時に到達できない。テストしても意味がない。
> - **実用的到達不能**: 理論上は可能だが実機・QEMU で再現するには非現実的な前提（64 bit カウンタ折返し、数千秒のタイマ周期等）が必要。
> - **到達困難（制約あり）**: 理論的には到達可能だが、複数の条件が同時に成立する必要があり、テストコストに対して価値が低い。

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
| L101 br[0] | `kerflg == FALSE` | `kerflg` はカーネル起動後に `true` にセットされ、以後 `false` に戻ることはない（`exit_kernel` 等で参照されるが起動後は恒真）。 | **構造的到達不能** |
| L102 br[1] | `enadsp == FALSE` | `dis_dsp()` 後に CPU 例外が発生し、例外ハンドラから `xsns_dpn` を呼ぶシナリオ。技術的には可能だが、zybo_z7_gcc の QEMU テスト環境では例外ハンドラを任意タイミングで起動する機構がない。 | **到達困難（制約あり）** |
| L102 br[2] | `p_runtsk == NULL` | `p_runtsk` が `NULL` になるのはアイドルループ（タスクが 1 つも実行可能でない）のとき。その状態で CPU 例外が発生し `xsns_dpn` が呼ばれる必要があるが、テストタスク実行中は常に `p_runtsk != NULL`。 | **構造的到達不能**（テスト文脈） |

**結論**: WB テストは不要。

---

## 2. task.c — `_kernel_make_non_runnable`（2 branches, 96.8%）

**ソース** (`asp3/kernel/task.c` L268, L274):
```c
if (p_schedtsk == p_tcb) {
    assert(dspflg);            /* L268 */
    p_schedtsk = ...;
}
...
if (p_schedtsk == p_tcb) {
    assert(dspflg);            /* L274 */
    p_schedtsk = ...;
}
```

| gcov 位置 | 条件 | 未到達理由 | 分類 |
|---|---|---|---|
| L268 br（assert 失敗パス） | `dspflg == false` かつ `p_schedtsk == p_tcb` | `p_schedtsk` がタスクに設定されている（実行可能状態）のに `dspflg` が偽であることは、カーネルの不変条件に反する（`dspflg` はスケジューリング可能なタスクが存在する場合に真）。正常動作ではこの組み合わせは発生しない。 | **構造的到達不能** |
| L274 br（assert 失敗パス） | 同上 | 同上（`queue_empty` 真の場合と偽の場合の両分岐で同じ assert） | **構造的到達不能** |

**結論**: WB テストは不要。

---

## 3. mutex.c（4 branches, 97.2%）

### 3-a. `remove_mutex` L227 br[1]

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
| L227 br[1]（ループ NULL 終了） | リストを末尾まで走査しても `p_mtxcb` が見つからない | `remove_mutex` は `p_mtxcb` がリストに存在することが呼出し側で保証された上でしか呼ばれない（`unl_mtx`/`ini_mtx` 等はすべて所有権を確認済み）。NULL 終了は「ミューテックスが見つからない」ことを意味し、カーネル内部の一貫性違反。 | **構造的到達不能** |

### 3-b. `loc_mtx` / `ploc_mtx` / `tloc_mtx` L375/423/474 br[0]

**ソース** (`asp3/kernel/mutex.c` L375 等):
```c
assert(p_runtsk == p_schedtsk);
```

| gcov 位置 | 条件 | 未到達理由 | 分類 |
|---|---|---|---|
| L375/423/474（assert 失敗パス） | `p_runtsk != p_schedtsk` | 上限優先度ミューテックスを獲得した直後は、実行タスクの優先度が上昇して `p_schedtsk` に昇格するため、`p_runtsk == p_schedtsk` は恒真。`p_runtsk != p_schedtsk` になるにはミューテックス獲得中にディスパッチが発生する必要があるが、CPU ロック中は不可能。 | **構造的到達不能** |

**結論**: WB テストは不要（4 branches とも）。

---

## 4. task_refer.c — `ref_tsk` L131 br[10]（1 branch, 97.1%）

**ソース** (`asp3/kernel/task_refer.c` L131):
```c
switch (tstat & TS_WAITING_MASK) {
case TS_WAITING_SLP: ...
case TS_WAITING_DLY: ...
case TS_WAITING_SEM: ...
...
```

| gcov 位置 | 条件 | 未到達理由 | 分類 |
|---|---|---|---|
| L131 br[10]（switch JT 境界チェック） | `TS_WAITING_MASK` のビット範囲外の待ち状態コード | GCC の switch ジャンプテーブル最適化が生成する「範囲外ならデフォルト」の安全チェック分岐。待ち状態コードは `TS_WAITING_SLP`（0x04）〜`TS_WAITING_MTX`（0x54 相当）の有効値のみカーネル内部から設定される。範囲外の値は正常動作では発生しない。 | **構造的到達不能** |

**結論**: WB テストは不要。

---

## 5. time_manage.c — `adj_tim` L168 br[0]（1 branch, 95.5%）

**ソース** (`asp3/kernel/time_manage.c` L165–172):
```c
#ifdef UINT64_MAX
    if (current_evttim - previous_evttim < (EVTTIM) adjtim
            && monotonic_evttim - previous_evttim < (EVTTIM) adjtim) {
        if (current_evttim < monotonic_evttim) {   /* L168 */
            ...
        }
        monotonic_evttim = current_evttim;
    }
```

| gcov 位置 | 条件 | 未到達理由 | 分類 |
|---|---|---|---|
| L168 br[0]（`current_evttim < monotonic_evttim`） | 64 bit `EVTTIM` が折り返した後、`current_evttim` が `monotonic_evttim` より小さくなる | `EVTTIM` は uint64_t で、折り返しには約 1.8 × 10¹⁹ µs ≈ 5.85 × 10¹¹ 年の連続動作が必要。QEMU テストでは事実上不可能。 | **実用的到達不能** |

**結論**: WB テストは不要。

---

## 6. wait.c — `_kernel_make_wait_tmout` L65 br[0]（1 branch, 90.0%）

**ソース** (`asp3/kernel/wait.c` L61–69):
```c
if (tmout == TMO_FEVR) {
    ...
} else {
    assert(tmout <= TMAX_RELTIM);   /* L65 */
    ...
    tmevtb_enqueue_reltim(p_tmevtb, (RELTIM) tmout);
}
```

| gcov 位置 | 条件 | 未到達理由 | 分類 |
|---|---|---|---|
| L65 br[0]（assert 失敗パス） | `tmout > TMAX_RELTIM` | `_kernel_make_wait_tmout` を呼ぶすべての API（`twai_sem` 等）は呼出し前に `CHECK_PAR(VALID_TMOUT(tmout))` で `tmout <= TMAX_RELTIM` を検証済み。無効なタイムアウト値はこの関数に到達しない。 | **構造的到達不能** |

**結論**: WB テストは不要。

---

## 7. wait.h — `make_non_wait` assert（1 branch, 93.8%）

**ソース** (`asp3/kernel/wait.h` L113):
```c
Inline void
make_non_wait(TCB *p_tcb)
{
    assert(TSTAT_WAITING(p_tcb->tstat));
    ...
```

| gcov 位置 | 条件 | 未到達理由 | 分類 |
|---|---|---|---|
| assert 失敗パス | `!TSTAT_WAITING(p_tcb->tstat)`（タスクが待ち状態でない） | `make_non_wait` はタスクが待ち状態であることを確認した上でのみ呼ばれる（`wait_complete`、`wait_tmout`、`rel_wai` 等の内部で待ちキューを確認後に呼出し）。待ち状態でないタスクへの呼出しはカーネル内部の一貫性違反。 | **構造的到達不能** |

**結論**: WB テストは不要。

---

## 8. interrupt.c — `chg_ipm` L371 br[0]（1 branch, 98.3%）

**ソース** (`asp3/kernel/interrupt.c` L369–378):
```c
if (intpri == TIPM_ENAALL && enadsp) {
    set_dspflg();
    if (p_runtsk->raster && p_runtsk->enater) {   /* L371 */
        task_terminate(p_runtsk);
        exit_and_dispatch();
        ercd = E_SYS;
    }
    ...
```

| gcov 位置 | 条件 | 未到達理由 | 分類 |
|---|---|---|---|
| L371 br[0]（`raster && enater` が真） | 自タスクへ `ras_ter` が呼ばれており (`raster=true`) かつ自タスク終了が許可 (`enater=true`) の状態で `chg_ipm(TIPM_ENAALL)` を呼ぶ | 必要な前提: (1) あるタスク T が `dis_ter()` を済ませていない状態（`enater=true` のデフォルト）、(2) T が `chg_ipm` で `intpri != TIPM_ENAALL` の状態に入っている（割込みマスク変更中）、(3) その間に別タスクが `ras_ter(T)` を呼ぶ（`raster=true`）、(4) T が `chg_ipm(TIPM_ENAALL)` を呼んで L371 に到達。条件 (2)(3) の競合タイミングが厳密に必要。 | **到達困難（制約あり）** |

**補足**: 既存テスト `chg_ipm_e.yaml` は `intpri == TIPM_ENAALL && enadsp=false`（L369 の真分岐に入らない）のパスをカバー。L371 を通るには `enadsp=true` かつ上記 (1)〜(4) の同時成立が必要。

**結論**: 理論的には WB テストで到達可能だが、コストに対して優先度低。当面は未対応で可。

---

## 9. time_event.c — `_kernel_signal_time` 等（6 branches, 90.0%）

### 9-a. `_kernel_update_current_evttim` L390 br[0]

**ソース** (`asp3/kernel/time_event.c` L388–394):
```c
if (monotonic_evttim - previous_evttim < (EVTTIM) hrtcnt_advance) {
    if (current_evttim < monotonic_evttim) {   /* L390 */
        ...
    }
    monotonic_evttim = current_evttim;
}
```

| gcov 位置 | 条件 | 未到達理由 | 分類 |
|---|---|---|---|
| L390 br[0]（`current_evttim < monotonic_evttim`） | 64 bit EVTTIM 折返し後の単調増加保証パス | `time_manage.c` L168 と同じ構造。uint64_t 折返しに約 5.8 × 10¹¹ 年の連続動作が必要。 | **実用的到達不能** |

### 9-b. `_kernel_set_hrt_event` L439 br[0]

**ソース** (`asp3/kernel/time_event.c` L428, L439–441):
```c
target_hrt_set_event(HRTCNT_BOUND);    /* L428: ヒープ空のとき */
...
if (hrtcnt > HRTCNT_BOUND) {           /* L439 */
    target_hrt_set_event(HRTCNT_BOUND);
```

| gcov 位置 | 条件 | 未到達理由 | 分類 |
|---|---|---|---|
| L439 br[0]（`hrtcnt > HRTCNT_BOUND`） | 次タイムイベントまでの HRT カウントが `HRTCNT_BOUND`（≈ 4,294,000,000 ticks ≈ 4,000 秒）を超える | `HRTCNT_BOUND` の定義上、4 秒以上後のタイムイベントを登録するシナリオが必要。QEMU テストの時間スケールでは通常発生しない。テストのタイムアウトより長い待ち時間設定になる。 | **実用的到達不能** |

### 9-c. `_kernel_signal_time` L588/L589（assert 失敗パス）

**ソース** (`asp3/kernel/time_event.c` L588–589):
```c
assert(sense_context());    /* L588: 割込みコンテキストであること */
assert(!sense_lock());      /* L589: CPU ロックされていないこと */
```

| gcov 位置 | 条件 | 未到達理由 | 分類 |
|---|---|---|---|
| L588 br（assert 失敗） | `!sense_context()`（タスクコンテキストから呼ばれた） | `signal_time` は HRT 割込みハンドラから呼ばれる。タスクコンテキストから呼ばれることはカーネル内部の実装誤り。 | **構造的到達不能** |
| L589 br（assert 失敗） | `sense_lock()`（CPU ロック中に呼ばれた） | HRT 割込みハンドラは CPU ロックなしで実行されることが保証されている。 | **構造的到達不能** |

### 9-d. `_kernel_signal_time` L624 br（`nocall == 0`）

**ソース** (`asp3/kernel/time_event.c` L585–626):
```c
uint_t  nocall = 0;
...
/* タイムイベントキュー処理ループ */
...
        nocall += 1;
...
if (nocall == 0) {   /* L624: 1件もイベント処理しなかった */
    target_hrt_clear_event();
```

| gcov 位置 | 条件 | 未到達理由 | 分類 |
|---|---|---|---|
| L624 br[0]（`nocall == 0`） | HRT 割込みが発生したが、期限切れタイムイベントが 1 件もなかった | HRT 割込みが `target_hrt_set_event` のセット時刻より早く発生するタイミング依存の状況（spurious interrupt または early fire）が必要。QEMU の cycle-accurate モデルでは再現困難。 | **実用的到達不能**（タイミング依存） |

**結論（time_event.c 全体）**: 6 未到達分岐はすべて WB テスト不要。

---

## サマリ

| ファイル | 未到達数 | 分類 | 対応方針 |
|---|---|---|---|
| exception.c | 2〜3 | 構造的到達不能 (×2) + 到達困難 (×1) | 不要 |
| task.c | 2 | 構造的到達不能 | 不要 |
| mutex.c | 4 | 構造的到達不能 | 不要 |
| task_refer.c | 1 | 構造的到達不能（JT 境界チェック） | 不要 |
| time_manage.c | 1 | 実用的到達不能（64 bit 折返し） | 不要 |
| wait.c | 1 | 構造的到達不能（assert） | 不要 |
| wait.h | 1 | 構造的到達不能（assert） | 不要 |
| interrupt.c | 1 | 到達困難（競合タイミング依存） | 低優先度・未対応で可 |
| time_event.c | 6 | 実用的到達不能 ×3 + 構造的 ×2 + タイミング依存 ×1 | 不要 |
| **合計** | **19** | — | 全て WB テスト追加不要と判断 |

**現状の 98.6%（1386/1405）はテスト充足率として十分**。
残存 19 未到達分岐はすべて、カーネルの不変条件・物理的制約・タイミング依存性により到達不能または到達困難であり、テストを追加しても仕様適合性の確認にはならない。
