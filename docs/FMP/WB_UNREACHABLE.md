# FMP 未到達分岐分析

> BBテスト（API auto-code 20分割 + check_library）での計測で未到達となった 102 分岐の分析。
> カバレッジ計測結果は [WB_COVERAGE.md](WB_COVERAGE.md) を参照。

---

## ビルド条件

| フラグ | 効果 |
|---|---|
| `ENABLE_GCOV=true` | gcov計装（`-fprofile-arcs -ftest-coverage`）を有効化 |
| `-DNDEBUG` | `assert()` 無効化。`t_stddef.h` の `#ifndef NDEBUG` で制御される assert 分岐がコードから除去される |
| `-O2` | `static inline` 関数が呼び出し元へ展開。同一ソース行が複数コールサイトで計測され，wait.h 等で「64 分岐」のような計測アーティファクトが生じる |

---

## サマリー

| # | カテゴリ | 未到達分岐数 | 主なファイル |
|---|---|---|---|
| §1 | マルチコア遅延ディスパッチパス | 約33 | alarm.c, cyclic.c, mempfix.c, mutex.c(一部), sys_manage.c, task_manage.c, task_term.c, time_manage.c |
| §2 | interrupt.c chg_ipm 複合パス | 27 | interrupt.c |
| §3 | wait.h インライン展開アーティファクト | 16 | wait.h |
| §4 | task.c サブ優先度機能 | 16 | task.c |
| §5 | time_event.c ヒープ操作・マルチコアパス | 13 | time_event.c |
| §6 | exception.c xsns_dpn 複合条件 | 3 | exception.c |
| §7 | mutex.c サブ優先度パス | 3 | mutex.c |
| §8 | alarm/cyclic force_unlock_spin | 2 | alarm.c, cyclic.c |
| §9 | startup.c / task_refer.c / task_term.c / spin_lock.c | 4 | 各1分岐 |
| **合計** | | **102 / 1677** | |

---

## §1. マルチコア遅延ディスパッチパス（FMP固有）

### 背景

FMP（Flexible Multiprocessor）では，カーネルAPIの多くに以下のパターンが追加されている：

```c
if (p_selftsk != p_my_pcb->p_schedtsk) {
    release_glock();
    dispatch();
    ercd = E_OK;
    goto unlock_and_exit;    /* ← 未到達 */
}
```

別プロセッサが同時に優先度の高いタスクを起動した場合，現在タスクが実行すべきタスクでなくなり，この `dispatch()` ルートが実行される。

**テスト環境での到達不能理由**: TTSP3のAPIテストは1タスク（または少数タスク）が順次APIを呼び出す構成。QEMUで2コア起動していても，PE2は `idle_loop` のみ実行し，PE1のスケジューリングを変更しない。そのため `p_selftsk == p_my_pcb->p_schedtsk` が常に成立する。

### 影響ファイル

| ファイル | 未到達分岐 | 未到達行（例） |
|---|---|---|
| alarm.c | 2 (alarm.cのdispatchパス) | `alm_cal` ハンドラ後処理 |
| cyclic.c | 2 | `cyc_cal` ハンドラ後処理 |
| mempfix.c | 2 | `rel_mpf` / `ini_mpf` |
| mutex.c | 2 | `unl_mtx`(L567-568), `ini_mtx`(L618-619) |
| sys_manage.c | 3 | `rot_rdq`(L277-278), `dis_dsp`(L604-606) |
| task_manage.c | 4 | `act_tsk`(L161-162), `mact_tsk`(L232-233) |
| task_term.c | 1 | `ter_tsk`(L374-375) |
| time_manage.c | 1 | `adj_tim` 後処理 |

**分類**: 到達困難（マルチコアタイミング依存）。WBテストで到達するには，PE2上のタスクがPE1のAPIコール中に優先度の高いタスクを起動するタイミング制御が必要。

---

## §2. interrupt.c chg_ipm 複合パス

`chg_ipm`（割込み優先度マスク変更）はFMP版で大幅に複雑化しており，複数の未到達パスを含む。

### §2-a. マルチコア dispatch retry パス

```c
/* interrupt.c L380-387 */
  retry:
    acquire_glock();
    p_my_pcb = get_my_pcb();
    if (p_selftsk != p_my_pcb->p_schedtsk) {   /* L383 - 常にfalse */
        release_glock();
        dispatch();                              /* L385 - 未到達 */
        goto retry;                              /* L386 - 未到達 */
    }
```

§1 と同じマルチコアパターン。

### §2-b. intpri == TIPM_ENAALL かつ enadsp == true パス

```c
/* interrupt.c L388 */
if (intpri == TIPM_ENAALL && p_my_pcb->enadsp) {
    set_dspflg(p_my_pcb);
    if (p_selftsk->raster && p_selftsk->enater) {   /* L391 */
        if (task_terminate(...)) {                   /* L392 */
            exit_and_migrate(...);                   /* L393 - 未到達 */
        } else {
            release_glock();
            exit_and_dispatch();                     /* L397 - 未到達 */
        }
        ercd = E_SYS;                               /* L399 - 未到達 */
    } else {
        if (p_selftsk != p_my_pcb->p_schedtsk) {    /* L403 */
            dispatch();                              /* L405-407 - 未到達 */
        }
    }
}
```

`TIPM_ENAALL` に戻す際，dispatch有効 + タスク終了要求 + 終了許可という複合条件が重なった場合に実行される。テストでは`chg_ipm(TIPM_ENAALL)` の呼び出しが単純なAPI適合性テストのためこの組み合わせが生じない。

**分類**: 
- `raster && enater` の組み合わせ: 到達困難（内部状態依存）
- `exit_and_migrate` / `exit_and_dispatch`: `task_terminate()` の返り値分岐（true = マイグレート, false = そのまま終了）→ 実用的到達不能（CPUアフィニティ依存）
- その他のマルチコアdispatchパス: §1 と同じ

**総計**: interrupt.c 27分岐（マクロ展開による分岐を含む）

---

## §3. wait.h インライン展開アーティファクト

```c
/* fmp3/kernel/wait.h L82-93 */
Inline void
make_wait(PCB *p_my_pcb, TS tstat, TCB *p_selftsk)
{
    if (!TSTAT_SUSPENDED(p_selftsk->tstat)) {
        p_selftsk->tstat = tstat;
        make_non_runnable(p_my_pcb, p_selftsk);
    }
    else {
        /* 過渡状態で呼び出された場合 */
        p_selftsk->tstat |= tstat;             /* L92 - 未到達 */
    }
    p_selftsk->winfo.tmevtb.callback = NULL;
}
```

`wait.h` の `static inline` 関数は `-O2` により呼び出し元（semaphore.c, eventflag.c, mutex.c 等）にインライン展開される。gcov は展開後の各コールサイトを個別計測するため，元のソース16行が計64分岐として計測される（展開倍率 ×4）。

- **L92 (過渡状態分岐)**: 待ち状態（TS_WAITING）と強制待ち状態（TS_SUSPENDED）が同時成立する過渡状態。FMPでは加えてマルチコア遷移中に発生しうるが，テストでは生じない。
- **16分岐**: すべてのコールサイトで過渡状態分岐が未到達となる計測アーティファクト。

**分類**: 計測アーティファクト（-O2 inlining × 過渡状態到達不能）。WBテスト不要。

---

## §4. task.c サブ優先度機能

FMPはサブ優先度（`TA_SUBPRI`）機能をサポートする。この機能を使用するタスクは `subprio_primap` に対応ビットが立ち，サブ優先度順キューへの挿入が行われる。

### §4-a. queue_insert_subprio_head（L230-242）

```c
/* fmp3/kernel/task.c L229-242 */
Inline void
queue_insert_subprio_head(QUEUE *p_queue, TCB *p_tcb)
{
    QUEUE   *p_entry;
    uint_t  subpri = current_subpri(p_tcb);          /* L233 - 未到達 */

    for (p_entry = p_queue->p_next; p_entry != p_queue;
                                    p_entry = p_entry->p_next) {  /* L235-236 */
        if (subpri <= current_subpri((TCB *) p_entry)) {           /* L237 */
            break;
        }
    }
    queue_insert_prev(p_entry, &(p_tcb->task_queue));  /* L241 - 未到達 */
}
```

`change_priority` (L363) 内の `if ((subprio_primap & PRIMAP_BIT(newpri)) != 0U)` が常に偽（サブ優先度未使用）のため，インライン展開後のコード（L383-387周辺）も含め実行されない。

### §4-b. change_priority サブ優先度分岐（L382-387）

```c
/* fmp3/kernel/task.c L382-388 */
if ((subprio_primap & PRIMAP_BIT(newpri)) != 0U) {  /* L382 - 常にfalse */
    if (mtxmode) {
        queue_insert_subprio_head(...);  /* L384 */
    }
    else {
        queue_insert_subprio_tail(...);  /* L387 */
    }
}
```

**分類**: 実用的到達不能（`TA_SUBPRI` 未使用のテスト設定）。

`task_manage.c` の `chg_spr` (L600-607) も同様のサブ優先度パス（`change_subprio` 呼び出し後のdispatch分岐含む）が未到達。

---

## §5. time_event.c ヒープ操作・マルチコアパス

### §5-a. tmevt_down 多段ヒープ下降（L251-257）

```c
/* fmp3/kernel/time_event.c L228-258 (tmevt_down) */
while ((child = LCHILD(index)) <= LAST_INDEX(p_tmevt_heap)) {
    if (...right child earlier...) { child = child + 1; }
    if (EVTTIM_LE(evttim, HEAP_NODE(child)->evttim)) { break; }
    /* ← ここで break しない場合（子ノードの方が早い）: */
    HEAP_NODE(index) = HEAP_NODE(child);  /* L251 - 未到達 */
    HEAP_NODE(index)->index = index;      /* L252 - 未到達 */
    index = child;                        /* L257 - 未到達 */
}
```

ヒープの「下向き調整」内部ループ。タイムイベントが3段以上にわたって存在し，かつ新しく挿入するイベントが最下位でない場合に実行される。テストではタイムイベント量が少なくこのパスに到達しない（ASPと同様）。

### §5-b. tmevtb_delete go-up パス（L321-327）

```c
/* fmp3/kernel/time_event.c L315-334 (tmevtb_delete) */
if (index > ROOT_INDEX
        && EVTTIM_LT(event_evttim, HEAP_NODE(parent, ...)->evttim)) {
    HEAP_NODE(index) = HEAP_NODE(parent);  /* L321 - 未到達 */
    HEAP_NODE(index)->index = index;       /* L322 - 未到達 */
    index = tmevt_up(parent, ...);         /* L327 - 未到達 */
}
else {
    index = tmevt_down(index, ...);
}
```

削除後のヒープ再編で「上向き」調整が必要になるケース（削除ノードの後継イベントが祖先より早い場合）。テストでは生じない（ASPと同様）。

### §5-c. 非TM processor 転送パス（L168, L522, L546, L583, L627）

FMPでは，タイムイベント処理プロセッサ（TM processor）が`p_tevtcb != NULL`を持ち，他のPEは`p_tevtcb == NULL`となる。その場合P_TM_PCBへ転送するパスが各関数に存在する：

```c
/* 例: time_event.c L521-523 (tmevtb_register) */
if (p_pcb->p_tevtcb == NULL) {
    p_pcb = P_TM_PCB;  /* L522 - 未到達 */
}
```

`initialize_event_time` の `else { p_my_pcb->p_tevtcb = NULL; }` (L168) も同様。

zybo_z7_gcc (dual Cortex-A9) 構成ではPE1・PE2ともに自プロセッサのタイムイベントを管理するため，`p_tevtcb == NULL` になるPEが存在しない。

### §5-d. HRTCNT_BOUND パス（L474）

```c
/* time_event.c L469-478 (set_hrt_event, #else !USE_64BIT_HRTCNT) */
if (hrtcnt > HRTCNT_BOUND) {
    target_hrt_set_event(p_pcb->prcid, HRTCNT_BOUND);  /* L474 - 未到達 */
}
```

次のタイムイベントが現在時刻から `HRTCNT_BOUND` を超える未来に設定された場合。テストではそのような長期タイムアウトが存在しない。

### §5-e. signal_time syslog パス（L757）

```c
/* time_event.c L756-759 */
if (nocall == 0) {
    syslog_1(LOG_NOTICE, "no time event processed...");  /* L757 - 未到達 */
}
```

HRT割込み発生時にタイムイベントが処理されなかった場合。テストでは常にいずれかのタイムイベントが処理される。

**分類**: §5-a, §5-b = 到達困難（内部状態依存：ヒープ深さ依存）。§5-c = 実用的到達不能（テスト設定のTM processor構成）。§5-d = 到達困難（制約あり：テストシナリオの制限）。§5-e = 実用的到達不能。

---

## §6. exception.c xsns_dpn 複合条件

```c
/* fmp3/kernel/exception.c L105-121 (xsns_dpn) */
if (check_tskctx()) {
    p_my_pcb = get_my_pcb();
    state = (kerflg_table[INDEX_PRC(p_my_pcb->prcid)]
                    && exc_sense_intmask(p_excinf)
                            && p_my_pcb->enadsp
                            && p_my_pcb->p_runtsk != NULL) ? false : true;
}
else {
    state = true;    /* タスクコンテキストの場合: ディスパッチ保留 */
}
```

複合論理条件のうち一部の短絡評価パスが未到達（ASPと同様）。`xsns_dpn` はCPU例外ハンドラ内でのみ呼ばれるため，通常のAPIテストでは特定の条件組み合わせに到達しない。

**分類**: 実用的到達不能（CPU例外ハンドラ内の特定組み合わせ）。

---

## §7. mutex.c サブ優先度パス

```c
/* fmp3/kernel/mutex.c L248-258 (mutex_raise_priority) */
if (newpri <= p_tcb->priority) {
    if (newpri < p_tcb->priority
            || ((subprio_primap & PRIMAP_BIT(p_tcb->priority)) != 0U
                                            && !(p_tcb->boosted))) {  /* L251 */
        p_tcb->boosted = true;
        change_priority(...);
    }
```

```c
/* fmp3/kernel/mutex.c L276-283 (mutex_drop_priority) */
if (newpri != p_tcb->priority
        || ((subprio_primap & PRIMAP_BIT(p_tcb->priority)) != 0U
                                        && !(p_tcb->boosted))) {  /* L280 */
    change_priority(...);
```

`subprio_primap` が常に0（サブ優先度未使用）のため，`&&` の右辺 `!(p_tcb->boosted)` が評価されない。

**分類**: 実用的到達不能（サブ優先度未使用のテスト設定，§4と同一要因）。

---

## §8. alarm.c / cyclic.c force_unlock_spin パス

```c
/* fmp3/kernel/alarm.c L316-321 (alm_cal) */
if (sense_lock()) {
    force_unlock_spin(p_my_pcb);  /* L317 - 未到達 */
}
else {
    lock_cpu();
}
```

アラームハンドラ/周期ハンドラが`sense_lock() == true`（スピンロック保持状態）で返った場合のクリーンアップ。ハンドラ内でスピンロックを取得したまま返ることはAPIの誤使用に相当し，適合性テストでは生じない。cyclic.c L338 も同様。

**分類**: 実用的到達不能（正常なハンドラ実装では発生しない誤使用パス）。WBテスト不要。

---

## §9. その他（各1分岐）

### §9-a. spin_lock.c loc_spn 待機ループ（1分岐）

```c
/* fmp3/kernel/spin_lock.c L209 (loc_spn, エミュレーション方式) */
while (LOCKFLAG(p_spninib)) {
    /* スピン待ち（他PEがロック保持中）*/
    release_glock();
    unlock_cpu();
    while (LOCKFLAG(p_spninib)) { ... }
    lock_cpu();
    acquire_glock();
}
```

スピンロックが既に他PEにより取得済みの場合のスピン待ちループ。テストでは `loc_spn` 呼び出し時に常にロックが空いている（単一シナリオ実行）ため，待機ループに入らない。

**分類**: 到達困難（マルチコア同時ロック競合依存）。

### §9-b. startup.c 非TM processor sta_ker パス（1分岐）

```c
/* fmp3/kernel/startup.c L221 (sta_ker) */
if (p_my_pcb->p_tevtcb != NULL) {
    while (try_glock());
    set_hrt_event(p_my_pcb);
    release_glock();
}
/* else: p_tevtcb == NULL のプロセッサはhrt_eventを設定しない */
```

zybo_z7_gcc構成（dual A9）では，PE1・PE2ともに`p_tevtcb != NULL`（各プロセッサが独立してタイムイベントを管理）。`p_tevtcb == NULL`（TM専用外プロセッサ）のケースが存在しないため，false分岐が未到達。

**分類**: 実用的到達不能（ターゲット設定に依存）。

### §9-c. task_refer.c マルチコア参照パス（1分岐）

```c
/* fmp3/kernel/task_refer.c L117 (ref_tsk) */
else if (p_tcb == p_pcb->p_runtsk) {
    pk_rtsk->tskstat = TTS_RUN;  /* 他PE上で実行中 */
}
```

`ref_tsk` で参照対象タスクが別プロセッサ上で実行中（TTS_RUN）かどうかのチェック。テストでは参照対象タスクが常に同一PE上に存在するか，RUNNABLE/WAITING状態で参照されるため，別PEで実行中の状態が参照されない。

**分類**: 到達困難（マルチコア状態参照タイミング依存）。

### §9-d. task_term.c ras_ter 自己終了パス（1分岐）

```c
/* fmp3/kernel/task_term.c L290-298 (ras_ter) */
if (p_selftsk->raster && p_my_pcb->dspflg) {
    if (task_terminate(p_my_pcb, p_selftsk)) {
        exit_and_migrate(p_my_pcb, p_selftsk);  /* L292 - 未到達 */
    } else {
        release_glock();
        exit_and_dispatch();                     /* L296 - 未到達 */
    }
    ercd = E_SYS;                               /* L298 - 構造的到達不能 */
}
```

`ras_ter` 自己呼び出し（自タスクに終了要求）で，その時点でディスパッチ可能状態の場合の即時終了パス。テストでは`ras_ter`呼び出し時のdspflg状態が該当しない。また，`exit_and_migrate` / `exit_and_dispatch` は non-returning 関数のため，L298は構造的到達不能。

**分類**: 到達困難（内部状態依存）+ 構造的到達不能（L298）。

---

## 未到達分岐 総括

| カテゴリ | 分岐数 | 備考 |
|---|---|---|
| マルチコア遅延ディスパッチパス（§1,§2の一部） | ～35 | FMP固有。並行実行シナリオ不在 |
| interrupt.c chg_ipm 複合パス（§2） | 27 | dispatch + 終了フロー複合 |
| wait.h インライン展開アーティファクト（§3） | 16 | 計測アーティファクト |
| サブ優先度機能（§4, §7） | 19 | TA_SUBPRI 未使用設定 |
| time_event.c ヒープ・マルチコアパス（§5） | 13 | ヒープ深度依存 + TM設定 |
| exception.c xsns_dpn（§6） | 3 | CPU例外内複合条件 |
| alarm/cyclic force_unlock_spin（§8） | 2 | 誤使用パス |
| その他（§9） | 4 | 各ファイル1分岐 |
| **合計** | **102 / 1677** | 93.9% branch coverage |

---

## WBテスト設計の考察

上記102分岐に対するWBテスト追加の実現性：

| カテゴリ | WBテスト化 | 理由 |
|---|---|---|
| マルチコア遅延ディスパッチ | 困難 | PE間タイミング制御が必要 |
| interrupt.c 終了フロー | 困難 | chg_ipm + raster + enater の複合状態制御 |
| wait.h アーティファクト | 不要 | 計測の性質上，実際には実行済み |
| サブ優先度機能 | 可能 | `TA_SUBPRI` タスクをcfgに追加すれば到達可能 |
| time_event.c ヒープ深度 | 可能 | 多数の同時タイムイベント設定で到達可能 |
| time_event.c 非TM path | 困難 | ターゲットHW構成依存 |
| exception.c xsns_dpn | 困難 | ASPと同様 |
| alarm/cyclic force_unlock | 不要 | 誤使用パス |

**サブ優先度機能 WBテスト**が最もROIが高い候補：`TA_SUBPRI` 属性タスクを複数作成し，mutex の優先度継承とサブ優先度の相互作用を試験することで，§4, §7 の 19分岐に到達できる可能性がある。
