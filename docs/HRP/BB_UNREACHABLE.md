# HRP 未到達分析（BBテスト）

> BBテスト（API auto-code 20分割 + check_library）の計測で未到達となったコードの分析。
> カバレッジ結果は [BB_COVERAGE.md](BB_COVERAGE.md) を参照（line 79.6% / branch 69.8%）。
>
> HRP の未到達は，個別の到達困難分岐よりも **テストシーケンスの早期終了（E_OACV）** という
> 系統的要因が支配的である。本ファイルはまずその系統要因を述べ，次に派生する
> ファイル別ギャップを整理する（FMP の `BB_UNREACHABLE.md` のような行単位網羅分析は，
> 系統要因の解消が先決のため後段とする）。

---

## ビルド条件

| フラグ | 効果 |
|---|---|
| `ENABLE_GCOV=true` | gcov計装（`--coverage -fprofile-info-section`）を有効化 |
| `-DNDEBUG` | `assert()` 無効化。`t_stddef.h` の `#ifndef NDEBUG` で制御される assert 分岐がコードから除去される |
| `-O2` | `static inline` 関数が呼び出し元へ展開。同一ソース行が複数コールサイトで計測される（計測アーティファクト） |

---

## §1. 支配的要因：E_OACV によるテストシーケンス早期終了（test-design）

### 観測事実（実測・2026-06-09）

API auto-code 各グループは数千チェックポイント（3670〜5230）を通過した後に，
**16/19 グループで `## Unexpected error E_OACV detected` を出力して終了**している。

| 終了態様 | グループ数 | 例（最終チェックポイント） |
|---|---|---|
| `E_OACV detected`（保護違反で異常終了） | 16 | auto_code_7: 5130, auto_code_10: 5230 |
| `Unexpected check point 0`（末尾で停止） | 3 | auto_code_1: 4247, auto_code_14: 3816 |
| ビルド不成立（§4） | 1 | auto_code_17 |

なお `## Unexpected check point 0` の 3 グループも**同一根本原因**である。`check_point(0)` は
シーケンス番兵（`check_count` は 0 始まり＋増加のみで決して一致しない＝「到達したらエラー」。
`library/HRP/test/ttsp_test_lib.c`）で，**本来 ter_tsk/sus_tsk で停止すべきタスクが
（その操作が失敗して）走り続けた**ことを示す。E_OACV を test_lib が捕捉すれば前者，
捕捉せず対象タスクが終端まで走れば後者、というだけの違いである。

### 真因（カーネルソース＋実測で特定・2026-06-09）

直接の原因は **システム状態に関するアクセス許可ベクタ `sysstat2_acvct` がユーザドメインに
付与されていない**ことである。HRP3 カーネルでは，状態を変える強制操作が
**対象オブジェクトの `acptn2` に加えて `sysstat2_acvct` を要求**する：

| API | 要求する許可 | カーネル該当行 |
|---|---|---|
| `sus_tsk` | `sysstat2_acvct.acptn2` | `kernel/task_sync.c:357` |
| `rsm_tsk` / `frsm_tsk` | `sysstat2_acvct.acptn1` | `kernel/task_term.c:220,246` |
| `ter_tsk` | `sysstat2_acvct.acptn3` | `kernel/task_term.c:306` |

- これらシステム状態チェック行には **NGKI 番号が無い**（隣接の対象タスク `acptn2` チェックには
  `[NGKI1304]`/`[NGKI3508]` が付く）。第3世代の保護強化として実装側で課されている検査である。
- システム状態許可は静的 API **`SAC_SYS({sysstat1}, {sysstat2})`** で設定し，`SAC_SYS` 省略時，
  および第 2 引数（sysstat2）省略時は **既定で `{TACP_KERNEL, TACP_KERNEL, TACP_KERNEL, TACP_KERNEL}`**
  ＝カーネルドメインのみ（`kernel/kernel.trb` `[NGKI0426]`）。
- TTG は SAC_SYS を生成するが **第 2 引数（sysstat2）を省略**している：
  `SAC_SYS({TACP_KERNEL, TACP(DOM_SYS_ACP2)|TACP_KERNEL, TACP_KERNEL, TACP_KERNEL|TACP(DOM_SYS_ACP4)});`
  → 専用の保護テスト用ドメイン（DOM_SYS_ACP2/4）の sysstat1 は許可するが，**通常のタスクテストが
  使う DOM1 等のユーザドメインに sysstat2 を一切許可しない**。
- ASP 由来のテスト（`sus_tsk_j` 等）は **ユーザドメイン（DOM1）のタスク**から `sus_tsk`/`ter_tsk` を
  呼び `E_OK` を期待する。システム状態許可が無いため **E_OACV**（HRP 保護として正しい挙動）。

### 実測による裏付け

auto_code_16 の生成 cfg の SAC_SYS に `sysstat2 = {TACP_SHARED ×4}` を付与して再ビルド・実行：

| | E_OACV | 最終到達チェックポイント |
|---|---|---|
| 修正前 | 1 件で中断 | 3670 |
| sysstat2 付与後 | **0 件** | **3901**（中断点を突破） |

→ E_OACV が消滅し中断点を越える＝**主因は sysstat2 未付与で確定**。

全 19 グループに同付与を適用して再計測した結果（`GCOV_GRANT_SYSSTAT2=1`）：

| 指標 | 付与前 | 付与後 |
|---|---|---|
| TOTAL line | 79.6% (2653/3334) | 79.7% (2658/3334) |
| TOTAL branch | 69.8% (1769/2533) | **70.8% (1793/2533)** |
| task_term.c | 94.8% / 68.8% | **100% / 93.8%**（+20 branch） |
| task_sync.c branch | 89.3% | 91.4% |
| task.c branch | 95.8% | 97.2% |

→ **同一ドメインの sus_tsk/ter_tsk/rsm_tsk 経路は回復**（task_term が 100%line・93.8%branch）。
ただし全体増分は小さい（line +0.1pt / branch +1.0pt）。理由は次の第 2 層：

### 第 2 層：対象オブジェクトの acptn2（クロスドメイン管理操作）

sysstat2 を許可しても **全 19 グループが依然中断**する。中断点は小幅前進（多くは +12〜16，
一部 +200 超）するだけで，次は別の `ter_tsk` 等が **対象タスクの acptn2** チェックで E_OACV になる
（`ter_tsk` は task_term.c:305 で対象 acptn2，:306 で sysstat2 の二段検査）。実測例（auto_code_2）：

- caller `ter_tsk_e_1_H4_TASK1` = **DOM1**、対象 `ter_tsk_e_1_H4_TASK2` = **DOM2**（クロスドメイン）。
- 対象の `SAC_TSK(..., {TACP_KERNEL, TACP_KERNEL, TACP(DOM1), TACP_KERNEL})`：
  acptn3（参照）= DOM1（だから ref_tsk は成功），しかし **acptn2（管理）= KERNEL のみ**で DOM1 不許可。
- それでもテストは `ter_tsk` の期待値を `E_OK` としている。

すなわち TTG は「クロスドメインの caller には参照(acptn3)だけ許可し管理(acptn2)は不許可」という
acvct を生成しながら，**管理操作の期待値を E_OK にしている**＝**生成内容が自己矛盾**。これは
cfg の一括設定では解消できず，TTG の期待値生成（保護下での ercd 算定）の問題に帰着する。

### 真因の確定：HRP3 3.3.0→3.4.0 の仕様変更に TESRY が未追従（spec divergence）

第 2 層の正体は **HRP3 Release 3.3.0→3.4.0 のアクセス許可仕様変更**である
（`hrp3/doc/version.txt`「Release 3.3.0 から 3.4.0 への主な変更点」§「システム状態のアクセス
許可ベクタの仕様変更に対応」）。同変更で：

1. システム状態の許可ベクタが **2 つ（sysstat1/sysstat2）** になり，
   **sus_tsk/ter_tsk が `sysstat2_acvct` でも禁止可能**になった（＝第 1 層）。
2. **サービスコールを制御するアクセス許可パターン（acptn）の割当が変更**された。HRP3 3.4.2 では
   `ter_tsk`/`sus_tsk`/`rsm_tsk`/`chg_pri` は **acptn2（通常操作2）** でチェックされる
   （`task_term.c:305`/`task_sync.c:356,407`/`task_manage.c:265`）。acptn3（管理操作）はタスクでは
   未使用で，標準テスト `hrp3/test/test_tprot1.cfg` も `SAC_TSK(.,{SHARED,SHARED,KERNEL,SHARED})`
   と acptn1/2/4 に許可を置き acptn3 を KERNEL のままにする。
3. 変更履歴は「**これらの変更に対応してテストプログラムを修正**」と明記。

ところが TTSP3 R3.1.0 の HRP TESRY（`api_test/HRP/**/*_H_ex.yaml`）は **旧 3.3.0 系**のまま：
ter_tsk のクロスドメイン許可を **acptn3** に置き（`access3: TACP(DOM1)`），`acptn2 = TACP_KERNEL`
を assert し，`ercd: E_OK` を期待している（例：`ter_tsk_e-1_H_ex.yaml` の H4）。3.4.x カーネルでは
acptn2 でチェックされるため `E_OACV`。**実測検証**：対象の acptn2 に DOM1 を付与すると ter_tsk は
通るが，今度はテストが持つ `check_value(rtsk.acvct.acptn2, TACP_KERNEL)` のアサーションが破綻する
（＝SAC だけ直しても不可。テストが旧カテゴリ前提で acvct 値そのものを検証している）。

**結論**：これは **TTG のコード不具合ではなく，HRP TESRY データが HRP3 3.4 のアクセス許可
カテゴリ変更に未追従**であること（spec divergence）に帰着する。sysstat2 付与（第 1 層）は
直接ブロックされた経路を回復させる（task_term 100%line/93.8%branch）が，第 2 層は ASP 由来テスト
全体に遍在するため全体天井（line 79.6%/branch 69.8%）は大きく変わらない。本質的な向上には
**`*_H_ex.yaml` の access1–4 割当・acvct assert・ercd を 3.4 のアクセスカテゴリへ移行**する
データ修正が必要（`DIVERGENCE_MAP.md` A 表に登録済み）。**具体的な移行手順は
[`TESRY_MIGRATION.md`](TESRY_MIGRATION.md)**（影響範囲：層2=ter_tsk 44ファイルの access2↔access3
入替、層1=TTG `CPUState.rb` の SAC_SYS に sysstat2 を出力）。

### 影響

- 各グループは数千チェックポイント通過後に最初の該当操作で中断し，**後半のテストケースが
  未実行**となる。§2 のファイル別ギャップの多くはこの早期終了の下流にある。
- カーネルの欠陥ではなく **HRP 保護仕様どおり**の挙動。HRMP3（`docs/HRMP/`）でも同種の
  E_OACV 早期終了が観測される。

**分類**: テスト生成のギャップ（TTG がユーザドメインに sysstat2 を許可しない）。解消の方向：
- (A) 生成 out.cfg の SAC_SYS に sysstat2 許可を付与（`scripts/ttsp_parallel_api.sh` の
  `GCOV_GRANT_SYSSTAT2=1` フックで実験可能）。上流の E_OACV を一掃するが，下流の `check_point(0)`
  系は個別対応が必要。
- (B) 個別テストの期待値・ドメイン設計を保護対応に見直す（本質的だが大規模）。

---

## §2. ファイル別ギャップ（§1 の下流＋HRP固有機能）

| ファイル | line | branch | 主因の分類 |
|---|---|---|---|
| messagebuf.c | 4.9% | 0.9% | §1 早期終了で snd/rcv_mbf 正常系の大半が未到達（メッセージバッファ自体は CRE_MBF で生成される） |
| domain.c | 19.4% | 8.3% | HRP固有・保護ドメイン管理。BBテストがドメイン遷移/属性を十分駆動しない＋§1 |
| time_manage.c | 23.3% | 10.0% | `get_tim`/`set_tim`/`adj_tim` 等の一部のみ。長期タイムアウト・境界条件が未駆動 |
| memory.c | 55.3% | 35.0% | HRP固有・メモリアクセス権チェック（`probe_mem_*`）の一部経路のみ |
| mem_manage.c | 55.4% | 25.8% | HRP固有・`sac_*`/`prb_*`（アクセス許可・メモリ領域操作）の一部のみ |
| sys_manage.c | 61.8% | 46.1% | `rot_rdq`/`get_did`/`ref_dom` 等の一部。ドメイン関連 system management が部分的 |
| time_event.c | 79.4% | 58.8% | ヒープ多段操作・長期イベント等の内部状態依存パス（ASP/FMP と同傾向） |
| task_term.c | 94.8% | 68.8% | 終了要求＋即時ディスパッチの複合状態パスが未到達（ASP/FMP と同傾向） |
| svc_table.c | 0.0% | - | 拡張SVC ディスパッチ表。`no_support` スタブ群（§3）。実質コード行が無く計測対象が僅少 |

各 ASP 共通APIファイル（task / semaphore / eventflag / dataqueue / pridataq / mutex /
mempfix / alarm / cyclic / wait）は **line 90〜100%** に達しており，§1 の早期終了が
無ければさらに上振れする余地がある（後半未実行分の回収）。

> ⚠ **上表は着手当初の bb ベースライン値**（早期終了下流を含む）。その後 M1〜M6＋simt で
> domain.c 8.3%→67.8%・time_event.c 58.8%→86.2%・sys_manage.c 46.1%→76.7%・messagebuf.c 0.9%→88.5%
> 等に底上げ済み（現状値は [`ALL_COVERAGE.md`](ALL_COVERAGE.md)）。**時間系・SOM の simt 計測後の
> 残未到達は §5 を参照**。

---

## §3. 構造的・既知の未到達（WBテスト不要）

| 区分 | 内容 |
|---|---|
| 単一コア | HRP は単一コア構成。マルチコア分岐（migrate 等）は HRP カーネルに存在しないか常に一方に確定 |
| `no_support` スタブ | `svc_table.c` の `fch_mnt`/`*_ovr`/`*_int` 等は未サポート時に `no_support` へ束ねられ，実コードを持たない |
| エラー戻り経路 | パラメータチェック失敗の一部（`E_PAR`/`E_ID` 等）は対応するテストケースが §1 で未実行 |
| `-O2` インライン展開 | `wait.h` 等の inline 関数が複数コールサイトへ展開され，過渡状態分岐が計測アーティファクトとして残る（FMP と同様） |

---

## §4. 計測カバレッジ上の欠落グループ（auto_code_17）

`auto_code_17` は gcov 計装時のみビルド不成立（`target_mem.cfg:36: E_SYS: memory objects overlap`，
保護パス4）。計装で増えたカウンタ領域＋`.gcov_info` メモリオブジェクトの追加が，当該グループの
密なメモリ配置で既存メモリオブジェクトと重なるため。**非計装では同グループは正常ビルド可**
（gcov 固有の現象）。当該グループのテストケースは他グループにも分散するため主要APIへの影響は軽微だが，
厳密には1グループ分の後半テストが欠落している。

**対策候補（後段）**：(a) `.gcov_info` 用に専用の固定マッピング領域を予約して配置衝突を回避，
(b) 分割数を増やして1グループあたりのメモリオブジェクト密度を下げる。

---

## §5. 時間系・SOM の残未到達（simt 計測後・2026-06-14）

§2 の表は**着手当初の bb ベースライン**（実機タイマ zybo・early-exit 下流）の値である。その後，
M1〜M6 の拡充と **simt ターゲット（`simtimer_zybo_z7_gcc`・`scripts/coverage_gcov_hrp_simt.sh`）**で
時間系・SOM を大幅に底上げした（time_event.c 58.8%→86.2%・domain.c 8.3%→67.8%・[`ALL_COVERAGE.md`](ALL_COVERAGE.md)）。
ここでは **simt でも到達できなかった残分岐**を関数単位で分類する（区分＝① bb 側で到達済・simt 非寄与／
② より深いシナリオ要・到達可能性あり／③ 構造的に到達不能と確定）。

### domain.c（simt 61/90・残 29 分岐）

| 関数 | simt 分岐 | 残 | 区分 | 残分岐の内容 |
|---|---|---|---|---|
| `_kernel_chg_som` | 18/24 | 6 | ② | 複数 SOM 切替・SOM 稼働状態の組合せ（単一 SOM 中心に駆動） |
| `_kernel_twd_start` | 7/10 | 3 | ② | 複数ウィンドウ／TA_INISOM 以外の起動経路 |
| `_kernel_twd_switch` | 3/6 | 3 | ② | 連続ウィンドウ境界・SOM 切替を跨ぐ窓遷移 |
| `_kernel_twdtimer_control` | 4/8 | 4 | ② | オーバラン／停止と再開の複合タイミング |
| `_kernel_scyc_start` | 3/4 | 1 | ② | 周期開始の別経路 |
| `_kernel_scyc_switch` | 1/2 | 1 | ② | 周期境界での SOM 切替同時刻 |
| `_kernel_set_dspflg` | 3/4 | 1 | **③** | elseif-T（`pending_twdswitch`）＝dspflg 偽での窓切替コインシデンス。**カーネル自身の `simt_twd1` も 0/4**＝upstream 未カバーの corner case（本群は 3/4 で上回る）。詳細 [`SIMT_HANDOFF.md`](SIMT_HANDOFF.md) |

> ②は複数窓・SOM 切替・dispatch の同時刻シナリオで、simt の `target_custom_idle` が次イベントを
> 1 つずつ発火する（同時刻コインシデンスを作れない）制約と、TTG のマージ系列検査の制約が重なる。
> domain.c の現実的上限は概ね現状値。③は到達不能確定。

### time_event.c（simt 69/80・残 11 分岐）

| 関数 | simt 分岐 | 残 | 区分 | 残分岐の内容 |
|---|---|---|---|---|
| `_kernel_tmevt_proc_top` | 1/4 | 3 | ② | ヒープ先頭処理の多段（複数イベント同時満了・割込み中の再入） |
| `_kernel_initialize_tmevt` | 6/8 | 2 | ② | 初期化時の境界（イベント数 0／最大） |
| `_kernel_tmevtb_enqueue` | 4/6 | 2 | ② | 多段ヒープの深い挿入位置（sift-up 多段） |
| `_kernel_tmevt_down` / `tmevtb_delete` / `_enqueue_reltim` / `_dequeue` | 各 -1 | 4 | ② | ヒープ sift-down／削除の特定深さ・相対時刻境界 |

> いずれも内部ヒープ状態に依存する多段操作で、ASP/FMP でも同傾向（深いヒープ構成を作る専用シナリオ要）。

### time_manage.c（simt 26/40だが **bb で 36/40＝90.0%**）

| 関数 | simt 分岐 | bb での扱い | 区分 |
|---|---|---|---|
| `_kernel_get_tim` | 6/14 | 標準 `get_tim` API テストで到達 | **①** |
| `_kernel_set_tim` | 5/8 | 同上 | **①** |
| `_kernel_adj_tim` | 15/18 | 同上 | **①** |

> **time_manage.c は simt の寄与なし**＝bb（zybo 実機タイマの標準 time API テスト）が既に 90.0% に到達。
> simt 単独値（65.0%）は bb を下回るため [`ALL_COVERAGE.md`](ALL_COVERAGE.md) では bb 値を採る。残 4 分岐
> （bb 36/40）は長期タイムアウト・HRTCNT 境界等で、64bit/分解能変種（`simt_systim*_64hrt`）でも一部のみ。

---

## 総括と WBテスト方針

| 要因 | 区分 | 改善手段 |
|---|---|---|
| §1 E_OACV 早期終了（支配的） | test-design | 保護ドメイン対応テスト（ドメイン割当・acvct 設定，または E_OACV 期待値化）。**最優先・最大ROI** |
| §2 HRP固有機能（domain/memory/mem_manage/sys_manage） | test-design | ドメイン遷移・アクセス権・メモリ領域操作を網羅する HRP固有 WBテスト |
| §2 messagebuf 正常系 | §1下流 | §1 解消で大幅回復見込み |
| §3 構造的/no_support/インライン | 到達不能/アーティファクト | WBテスト不要 |
| §4 auto_code_17 欠落 | 計測基盤 | `.gcov_info` 配置の見直し（後段） |

→ **最優先は §1（E_OACV 早期終了）の解消**。これにより各グループ後半が実行され，§2 の多くが
連動して改善する見込み。次点が HRP 保護機能（domain/memory 系）の WBテスト拡充。

---

## 参考
- カバレッジ結果：[BB_COVERAGE.md](BB_COVERAGE.md)
- ASP3：`docs/ASP/`（98.3%）／FMP3：`docs/FMP/`（93.9%）／HRMP3：`docs/HRMP/`（75.4%，同種 E_OACV）
- gcov 計装手順（保護カーネル）：`docs/HRP3_GCOV.md`
- bring-up・真因記録：`docs/HRP/COVERAGE_STATUS.md`
