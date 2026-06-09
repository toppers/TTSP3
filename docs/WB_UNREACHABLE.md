# WB_UNREACHABLE.md — ASP3 kernel/ 分岐カバレッジ詳細分析

> 更新: 2026-06-09  
> 対象: ASP3 3.7.2 `kernel/`、残存 25 未到達分岐（1434/1459 = 98.3%、`all` モード）  
> ビルド: `coverage_gcov_asp.sh all`  
> コンパイルオプション（カバレッジ数値に影響するもの）:  
> - `ENABLE_GCOV=true` — gcov 計装ビルド（`-fprofile-arcs -ftest-coverage`）  
> - `-DNDEBUG`（`COPTS` 経由） — `assert()` を `((void)(0))` に展開し分岐ノードを消滅させる。これにより task.c / mutex.c / wait.c / time_event.c の assert 失敗パスが計測対象外となり、実質的なカバレッジ数値が上昇する  
> - `-O2`（zybo_z7_gcc デフォルト） — `static inline` 関数の call-site インライン展開を促進し、wait.h の追跡分岐数が増加する（§5 参照）

**分類凡例:**
- **構造的到達不能**: カーネルの不変条件（恒真 flag、整合性保証ポインタ等）により実行時に到達できない。
- **実用的到達不能**: 理論上は可能だが QEMU では非現実的な前提（64 bit カウンタ折返し、数千秒タイマ等）が必要。
- **到達困難（制約あり）**: 理論的には到達可能だが、複数条件が同時成立する必要があり、コストに対して価値が低い。
- **到達困難（内部状態依存）**: 外部 API 操作では再現が難しい内部データ構造・状態が必要。
- **到達可能（BBテスト非網羅）**: 自動生成 BB テストでは生成されないシナリオだが、手書き WBテストで到達可能。
- **計測アーティファクト**: コンパイラの最適化（インライン展開）により同一ソース行が複数 call-site インスタンスとして追跡され、一部インスタンスが未到達になるもの。論理的カバレッジは確認済み。

---

# 未到達分岐（`all` モードで残存）

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

## 2. mutex.c（1 branch, 99.3%）

### 2-a. `remove_mutex` L227 br[1]（**残存**）

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

**補足**: 既存テスト [`chg_ipm_e.yaml`](../api_test/ASP/interrupt/chg_ipm/chg_ipm_e.yaml) は `enadsp=false`（L369 の真分岐不成立）のパスをカバー。L371 には `enadsp=true` かつ上記競合条件の同時成立が必要。

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

**結論（time_event.c 全体）**: 4 未到達分岐はすべて WB テスト追加不要。  
なお `_kernel_tmevt_down` L221/L231 および `_kernel_tmevtb_delete` L302 は WBテスト（§12）で到達済み（`all` モード）。

---

# WBテストで到達済み分岐（`bb` モードでは未到達）

> 以下の各節は、手書き WBテストで到達済みとなった分岐を未到達分岐（§1–7）と同様の形式で分析する。  
> **WBテストの妥当性**（テスト内容が分岐の意味を正しく検証しているか、手書きコストが妥当かなど）は、これをもとに人間が確認する。  
> `bb` モード単独では 8 分岐が未到達（1425/1459 = 97.7%）。

---

## 8. alarm.c — `_kernel_call_alarm` L241 br[1]

**ソース** (`asp3/kernel/alarm.c` L235–243):
```c
unlock_cpu();                                                         /* L235 */
(*(p_almcb->p_alminib->nfyhdr))(p_almcb->p_alminib->exinf);          /* L238: ハンドラ呼出し */
if (!sense_lock()) {                                                  /* L241 */
    lock_cpu();
}
```

| gcov 位置 | 条件 | BBテストで未到達の理由 | 分類 |
|---|---|---|---|
| L241 br[1]（`sense_lock() == true`） | ハンドラが CPU ロック（`iloc_cpu()`）を保持したまま戻る → `lock_cpu()` はスキップ | `call_alarm` はハンドラを `unlock_cpu()` 後に呼び出し、戻り後に `sense_lock()` で CPU ロック状態を確認する。BB テストのハンドラは CPU ロックを操作せず、戻り時は常にロック解除状態（`sense_lock() == false`）になる。`iloc_cpu()` を保持して戻るシナリオは自動生成テストでは生成されない。 | **到達困難（制約あり）** |

**WBテスト**: [`alarm_W-a`](../api_test/ASP/alarm/alarm_W-a/out.c) — アラーム通知ハンドラ内で `iloc_cpu()` を呼び出し、CPU ロックを保持したまま戻ることで L241 br[1] を到達させる。

**結論**: WBテスト `alarm_W-a` で到達済み（`all` モード）。

---

## 9. cyclic.c — `_kernel_call_cyclic` L259 br[1]

**ソース** (`asp3/kernel/cyclic.c` L253–261):
```c
unlock_cpu();                                                         /* L253 */
(*(p_cyccb->p_cycinib->nfyhdr))(p_cyccb->p_cycinib->exinf);          /* L256: ハンドラ呼出し */
if (!sense_lock()) {                                                  /* L259 */
    lock_cpu();
}
```

| gcov 位置 | 条件 | BBテストで未到達の理由 | 分類 |
|---|---|---|---|
| L259 br[1]（`sense_lock() == true`） | 周期ハンドラが CPU ロックを保持したまま戻る | §8（alarm.c L241）と同構造。`call_cyclic` も同一パターンで実装されており、BB テストでは非網羅。 | **到達困難（制約あり）** |

**WBテスト**: [`cyclic_W-a`](../api_test/ASP/cyclic/cyclic_W-a/out.c) — 周期通知ハンドラ内で `iloc_cpu()` を呼び出し、CPU ロックを保持したまま戻ることで L259 br[1] を到達させる。

**結論**: WBテスト `cyclic_W-a` で到達済み（`all` モード）。

---

## 10. mempfix.c — `rel_mpf` L309/L310 br[0]

**ソース** (`asp3/kernel/mempfix.c` L307–311):
```c
CHECK_PAR(p_mpfcb->p_mpfinib->mpf <= blk);                                    /* L307 */
blkoffset = ((char *) blk) - (char *)(p_mpfcb->p_mpfinib->mpf);               /* L308 */
CHECK_PAR(blkoffset % p_mpfcb->p_mpfinib->blksz == 0U);                       /* L309 */
CHECK_PAR(blkoffset / p_mpfcb->p_mpfinib->blksz < p_mpfcb->unused);           /* L310 */
blkidx = (uint_t)(blkoffset / p_mpfcb->p_mpfinib->blksz);                     /* L311 */
```

`CHECK_PAR(cond)` は `cond` が偽のとき `E_PAR` を返す（`goto error_exit`）。L309 br[0] / L310 br[0] は各 CHECK_PAR の「偽（エラー）」分岐。

### 10-a. L309 br[0]（ミスアライメントポインタ → E_PAR）

| gcov 位置 | 条件 | BBテストで未到達の理由 | 分類 |
|---|---|---|---|
| L309 br[0]（`blkoffset % blksz != 0U` → E_PAR） | `rel_mpf` に渡すポインタがブロックサイズに整合しない | BB テストは常に `get_mpf` で取得したポインタを `rel_mpf` に渡す。`get_mpf` はブロックサイズ境界に整合したポインタのみ返すため、ミスアライメントポインタは自動生成テストでは発生しない。 | **到達可能（BBテスト非網羅）** |

**WBテスト**: [`mempfix_W-a`](../api_test/ASP/mempfix/mempfix_W-a/out.c) — `get_mpf` で取得したブロックポインタに `+1` などのオフセットを加えたミスアライメントポインタを `rel_mpf` に渡し、`E_PAR` が返ることを確認。

**結論**: WBテスト `mempfix_W-a` で到達済み（`all` モード）。

### 10-b. L310 br[0]（ブロックオフセット範囲外 → E_PAR）

| gcov 位置 | 条件 | BBテストで未到達の理由 | 分類 |
|---|---|---|---|
| L310 br[0]（`blkidx >= p_mpfcb->unused` → E_PAR） | `blkoffset / blksz` で得られる index が割当て済みブロック数を超過 | BB テストは正規ポインタのみ使用。プール管理領域外（`unused` を超えた index に対応する）アドレスを渡すケースは自動生成テストでは発生しない。 | **到達可能（BBテスト非網羅）** |

**WBテスト**: [`mempfix_W-b`](../api_test/ASP/mempfix/mempfix_W-b/out.c) — プール末尾（`mpf + blksz * blkcnt`）を超えるアドレスを `rel_mpf` に渡し、`E_PAR` が返ることを確認。

**結論**: WBテスト `mempfix_W-b` で到達済み（`all` モード）。

---

## 11. task_manage.c — `act_tsk` L137 br[1]

**ソース** (`asp3/kernel/task_manage.c` L135–142):
```c
if (TSTAT_DORMANT(p_tcb->tstat)) {
    ...                                                               /* 起動処理 */
}
else if ((p_tcb->p_tinib->tskatr & TA_NOACTQUE) != 0U || p_tcb->actque) {  /* L137 */
    ercd = E_QOVR;                                                    /* ［NGKI3528］*/
}
else {
    p_tcb->actque = true;                                             /* ［NGKI3527］*/
    ercd = E_OK;
}
```

| gcov 位置 | 条件 | BBテストで未到達の理由 | 分類 |
|---|---|---|---|
| L137 br[1]（`TA_NOACTQUE` フラグあり → E_QOVR） | `TA_NOACTQUE` 属性タスクに `act_tsk` を呼ぶ（起動要求キューイング不可 → 即 E_QOVR）〔NGKI3528〕 | BB テストで生成されるタスクは `TA_NOACTQUE` 属性を持たない。`actque=true` ルート（既にキュー済み）は BB テストでカバーされているが、`TA_NOACTQUE` フラグによる短絡ルートは属性指定が必要であり、自動生成テストでは非網羅。 | **到達可能（BBテスト非網羅）** |

**WBテスト**: [`act_tsk_W-a`](../api_test/ASP/task_manage/act_tsk_W-a/out.c) — `TA_NOACTQUE` 属性で生成した実行中タスクに `act_tsk` を呼んで `E_QOVR` が返ることを確認。

**結論**: WBテスト `act_tsk_W-a` で到達済み（`all` モード）。

---

## 12. time_event.c — `tmevt_down` / `tmevtb_delete`

### 12-a. `tmevt_down` L221 br[1]（右子ノードなし）

**ソース** (`asp3/kernel/time_event.c` L215–228):
```c
while ((child = LCHILD(index)) <= LAST_INDEX()) {             /* L215: 左子あり */
    if (child + 1 <= LAST_INDEX()                             /* L221: 右子の有無 */
            && EVTTIM_LT(HEAP_NODE(child + 1)->evttim,
                                    HEAP_NODE(child)->evttim)) {
        child = child + 1;  /* 右子の方が早い → child を右子に変更 */
    }
    if (EVTTIM_LE(evttim, HEAP_NODE(child)->evttim)) {        /* L231: break 判定 */
        break;
    }
    HEAP_NODE(index) = HEAP_NODE(child);
    HEAP_NODE(index)->index = index;
    index = child;
}
```

| gcov 位置 | 条件 | BBテストで未到達の理由 | 分類 |
|---|---|---|---|
| L221 br[1]（`child + 1 > LAST_INDEX()`） | 現レベルに左の子しか存在しない（右子ノードがヒープ末尾を超える） | BB テストのタイムイベント登録・削除パターンでは、`tmevt_down` が呼ばれる時点でヒープが常に偶数個のノードを持つ（または当該レベルに右子が存在する）形になる。「左子のみ」状態は特定の登録順序・数でのみ発生し、自動生成テストでは生成されない。 | **到達困難（内部状態依存）** |

**WBテスト**: [`time_event_W-a`](../api_test/ASP/time_event/time_event_W-a/out.c) — 複数タイムイベントを特定の順序で登録・期限切れさせ、sift-down 時に右子が存在しないヒープ形状を手書きで構築して L221 br[1] を到達させる。

**結論**: WBテスト `time_event_W-a` で到達済み（`all` モード）。

---

### 12-b. `tmevt_down` L231 br[0]（早期 break）

（ソースは §12-a と同じ）

| gcov 位置 | 条件 | BBテストで未到達の理由 | 分類 |
|---|---|---|---|
| L231 br[0]（`EVTTIM_LE(evttim, child->evttim)` が真 → break） | 挿入ノードの発生時刻が選択した子ノード以前 → 現在の `index` が挿入位置 | BB テストのパターンでは sift-down が末尾まで進むか 1 段のみで終わるため、「中間で止まる」ケースが生じない。§12-a と同様、特定のヒープ配置が必要。 | **到達困難（内部状態依存）** |

**WBテスト**: [`time_event_W-a`](../api_test/ASP/time_event/time_event_W-a/out.c) — §12-a と同一テスト。右子なしの状況下で挿入ノードが左子より早い発生時刻になるよう配置し、L221 br[1] と L231 br[0] を同一テスト実行で同時にカバー。

**結論**: WBテスト `time_event_W-a` で到達済み（`all` モード）。

---

### 12-c. `tmevtb_delete` L302 br[0]（go-up パス）

**ソース** (`asp3/kernel/time_event.c` L298–320):
```c
event_evttim = HEAP_NODE(last_index)->evttim;
if (index > ROOT_INDEX                                         /* L300 */
        && EVTTIM_LT(event_evttim,                             /* L302 */
                    HEAP_NODE(parent = PARENT(index))->evttim)) {
    /* 最後尾ノードが削除位置の親より前 → 上方向に挿入位置を探す */
    HEAP_NODE(index) = HEAP_NODE(parent);
    HEAP_NODE(index)->index = index;
    index = tmevt_up(parent, event_evttim);
}
else {
    index = tmevt_down(index, event_evttim);  /* go-down */
}
```

| gcov 位置 | 条件 | BBテストで未到達の理由 | 分類 |
|---|---|---|---|
| L302 br[0]（go-up 条件が真） | 削除ノードを最後尾ノードで置き換えた際、最後尾ノードの発生時刻が削除位置の親ノードより前 → ヒープ性質を回復するため上方向に移動 | BB テストの削除パターンでは、最後尾ノードが削除位置の親より後の時刻になるため常に go-down パスを通る。go-up が発生するには削除対象が「大きい値を持つノード（ヒープ下部）」かつ最後尾が「比較的早い時刻」という特定の配置が必要。 | **到達困難（内部状態依存）** |

**WBテスト**: [`time_event_W-b`](../api_test/ASP/time_event/time_event_W-b/out.c) — ヒープ中間ノードの削除時に最後尾ノードの発生時刻が削除位置の親ノードより早くなるよう、複数タイムイベントの発生時刻と削除順序を手書きで設計。

**結論**: WBテスト `time_event_W-b` で到達済み（`all` モード）。

---

## サマリ

### 未到達分岐（残存 25 件、`all` モード）

| ファイル | 未到達数 | 分類 | 対応方針 |
|---|---|---|---|
| wait.h | 15 | 計測アーティファクト（O2 インライン展開増加） | 不要 |
| time_event.c | 4 | 実用的到達不能 ×3 + タイミング依存 ×1 | 不要 |
| exception.c | 2〜3 | 構造的到達不能 ×2 + 到達困難 ×1 | 不要 |
| interrupt.c | 1 | 到達困難（競合タイミング依存） | 低優先度・未対応で可 |
| mutex.c | 1 | 構造的到達不能（L227 NULL exit） | 不要 |
| task_refer.c | 1 | 構造的到達不能（JT 境界チェック） | 不要 |
| time_manage.c | 1 | 実用的到達不能（64 bit 折返し） | 不要 |
| **合計** | **25** | — | 全て WB テスト追加不要と判断 |

### WBテストで到達済み分岐（8 分岐、`bb` モードでは未到達）

| § | ファイル / 分岐 | 分類 | WBテスト |
|---|---|---|---|
| 8 | alarm.c L241 br[1] | 到達困難（制約あり） | [`alarm_W-a`](../api_test/ASP/alarm/alarm_W-a/out.c) |
| 9 | cyclic.c L259 br[1] | 到達困難（制約あり） | [`cyclic_W-a`](../api_test/ASP/cyclic/cyclic_W-a/out.c) |
| 10-a | mempfix.c L309 br[0] | 到達可能（BBテスト非網羅） | [`mempfix_W-a`](../api_test/ASP/mempfix/mempfix_W-a/out.c) |
| 10-b | mempfix.c L310 br[0] | 到達可能（BBテスト非網羅） | [`mempfix_W-b`](../api_test/ASP/mempfix/mempfix_W-b/out.c) |
| 11 | task_manage.c L137 br[1] | 到達可能（BBテスト非網羅） | [`act_tsk_W-a`](../api_test/ASP/task_manage/act_tsk_W-a/out.c) |
| 12-a | time_event.c L221 br[1] | 到達困難（内部状態依存） | [`time_event_W-a`](../api_test/ASP/time_event/time_event_W-a/out.c) |
| 12-b | time_event.c L231 br[0] | 到達困難（内部状態依存） | [`time_event_W-a`](../api_test/ASP/time_event/time_event_W-a/out.c) |
| 12-c | time_event.c L302 br[0] | 到達困難（内部状態依存） | [`time_event_W-b`](../api_test/ASP/time_event/time_event_W-b/out.c) |

**現状の 98.3%（1434/1459）はテスト充足率として十分**（`all` モード）。  
wait.h の 15 箇所はインライン展開アーティファクトであり論理的カバレッジは確認済み。  
残存 10 箇所（wait.h 除く）は、カーネルの不変条件・物理的制約・タイミング依存性により到達不能または到達困難であり、テストを追加しても仕様適合性の確認にはならない。
