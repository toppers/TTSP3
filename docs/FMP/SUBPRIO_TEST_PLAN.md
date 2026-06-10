# SUBPRIO_TEST_PLAN.md — FMP3 サブ優先度テスト設計

> FMP3 のサブ優先度（sub-priority）機能に対する **BBテスト（仕様ベース＝api_test/TESRY）主体**の
> テスト設計。2026-06-10 策定。基準ターゲット zybo_z7_gcc（QEMU・dual Cortex-A9）。
> 上位計画は [`../SPEC37_PLAN.md`](../SPEC37_PLAN.md) P2-1、未到達分岐は
> [`BB_UNREACHABLE.md`](BB_UNREACHABLE.md) §4、改変台帳は [`../../DIVERGENCE_MAP.md`](../../DIVERGENCE_MAP.md)。

---

## 0. 背景と問題（なぜ今これをやるか）

サブ優先度は **FMP3/HRMP3 が標準搭載**（ASP3/HRP3 は拡張パッケージ＝対象外）。対象は実質 **FMP3**。
TTSP3 R3.1.0 は既に `chg_spr` **65本**＋`ENA_SPR` 4ケースを保有し、zybo FMP autocode で全緑。

精査の結果（2026-06-10）、既存BBテストは **`ENA_SPR` は有効化しているが、サブ優先度の「並び替え効果」を
一切「観測」していない**ことが判明した：

| テスト | 実態 | 検証している仕様 |
|---|---|---|
| `chg_spr` 65本 | **57本が `subpri:` パラメータを使用**＝専用優先度 `TSK_PRI_SUBPRI`(=13) に対し `ENA_SPR` を自動生成（TTG が `subpri` 指定時に付与）。**ただし `porder`（レディキュー内順位）を検証するケースは 0本** | 戻り値（E_CTX/E_NOSPT/E_ID/E_NOEXS/E_OACV）と **NGKI3672**（subpri 値が `ref_tsk` で格納確認）のみ。**NGKI3673 の並び替え結果は未観測** |
| `ENA_SPR` 4ケース | 静的APIの**コンフィグエラー**（E_RSATR domain/class・E_PAR 範囲）＋正常ビルド | 静的APIのエラーチェックのみ。スケジューリング効果は不問 |

> ⚠️ 当初「`ENA_SPR` 使用 0本」と見立てたが、これは yaml に文字列 `ENA_SPR` が出ない（TTG が `subpri`
> パラメータから自動生成する）ための grep 誤り。正しくは **57/65 本が ENA_SPR を有効化**している。
> 真の空白は **「並び替え効果（`porder`）の検証が 0本」** という点にある。

→ **未検証（BBの真の空白）**：
- **NGKI3673**：対象タスクが実行可能かつ現在優先度がサブ優先度使用設定のとき、`chg_spr` で
  優先度・サブ優先度が同じタスクの中で**優先順位が最も低くなる**（同 pri+subpri 群の末尾へ）。
  ＝ **並び替えの結果（`porder`）を誰も assert していない**。kernel が誤った位置に挿入してもテストは緑になる。
- **NGKI5219**：タスクが優先度上昇状態（boosted）の間は、サブ優先度の現在値を**最高値（＝0）**として扱う。
- `chg_spr` 自タスク降格時のディスパッチ誘発（`task_manage.c` L603-608）。
- `chg_pri` をサブ優先度有効優先度に対して行う `change_priority` のサブ優先度経路（`task.c` L382-387）。

この BB の観測欠落が、カーネル `task.c`/`task_manage.c` のサブ優先度経路の C1 分岐
（特に `queue_insert_subprio_tail` のループ両方向・`change_priority` subprio 分岐・自タスクdispatch分岐）を
**未到達**のまま残している（[`BB_UNREACHABLE.md`](BB_UNREACHABLE.md) §4）。
**並び替え効果を観測するBBを足せば、WB未到達分岐も同時に縮小する。**

---

## 1. 対象仕様とカーネル実装の対応

統合仕様書 3.7 のサブ優先度関連要求と、被テストカーネル `fmp3/kernel/` の対応：

| 仕様 | 内容 | カーネル実装（fmp3/kernel） |
|---|---|---|
| NGKI3665 | `chg_spr` | `task_manage.c` `chg_spr`（L573-621） |
| NGKI3666/3667 | E_CTX（非タスク／CPUロック） | `CHECK_TSKCTX_UNL_MYSTATE`（既存BBで検証済） |
| NGKI3668 | E_NOSPT（制約タスク） | （既存BBで検証済） |
| NGKI3669/3670/3671 | E_ID／E_NOEXS／E_OACV | （既存BBで検証済） |
| NGKI3672 | subpri 格納 | `chg_spr` L598 `p_tcb->subpri = subpri`（既存BBで検証済） |
| **NGKI3673** | **同 pri+subpri 群の末尾へ並び替え** | `chg_spr` L600-602（`subprio_primap` ビット＆`!boosted`）→ `change_subprio`（`task.c` L437）→ `queue_insert_subprio_tail`（L208） |
| **NGKI5219** | **boosted 中は subpri=0 扱い** | `current_subpri`（`task.c` L195）`p_tcb->boosted ? 0U : p_tcb->subpri`／`chg_spr` L601 `!(p_tcb->boosted)` ガード |
| NGKI3674 | TSK_SELF | `chg_spr` L585（既存BBで検証済）。ただし自タスクのディスパッチ誘発（L603-608）は未検証 |
| NGKI3675-3678 | `ENA_SPR`（静的API・E_RSATR/E_PAR） | `task.trb` L142-170（`subprio_primap` 生成） |

**`subprio_primap` の正体**：`ENA_SPR(pri)` で `PRIMAP_BIT(pri)` が立つビットマップ。
サブ優先度の並び替えは「その優先度のビットが立っている」場合のみ発動する（`task.c` L261/L382/L443）。
**＝ サブ優先度効果を踏むには `ENA_SPR` 済み優先度に複数の実行可能タスクが必要。**

### 未到達カーネル分岐（BB で踏める見込みのもの）

| file:line | 分岐 | 踏ませ方 |
|---|---|---|
| `task.c` L261-262 | `make_runnable` subprio tail 挿入 | ENA_SPR 済み優先度に `act_tsk`／ready 設定 |
| `task.c` L195 boosted=false | `current_subpri` 通常側 | サブ優先度有効優先度のキュー挿入時 |
| `task.c` L208-220 | `queue_insert_subprio_tail`（ループ・break 両方向） | 同優先度に subpri 昇順/同値の複数タスク |
| `task.c` L382-383, L387 | `change_priority` subprio tail（非 mtx） | サブ優先度有効優先度での `chg_pri` |
| `task.c` L437-447 | `change_subprio` | `chg_spr` 正常系（有効優先度・runnable） |
| `task_manage.c` L600-608 | subprio_primap＆!boosted→dispatch | `chg_spr` 正常系・自タスク降格でのディスパッチ |
| `task.c` L384 | `change_priority` subprio **head**（mtxmode） | ミューテックス ceiling/継承解除（**WB寄り**・Phase B） |

---

## 2. ハーネス適合性（追い風）

- **TTG は `subpri` パラメータ対応済み**（`tools/ttg/doc/param.txt:175`：
  「subpri が指定された場合、そのタスクの現在優先度に対して `ENA_SPR` を定義する」）。
  → **TESRY だけでサブ優先度有効タスクを表現でき、新規ハーネス・カーネル変種は不要。**
  pre_condition のタスクに `subpri: N` を付けるだけで `ENA_SPR(そのタスクの優先度)` が自動生成される。
- **順序の宣言的検証は `porder`（レディキュー内順位）**が既に dataqueue 待ち行列テスト
  （`snd_dtq_F-e-*` 等）で実績あり。同手法をレディキューに適用し、並び替え結果を pre/post で表現する。
- post_condition での `subpri` 検証は `ref_tsk`（T_RTSK.subpri）経由。

→ 配置は **方式1（既存 `chg_spr` シート拡張）**。`api_test/FMP/task_manage/chg_spr/` に
`chg_spr_F-e-*` を追加し、CI・集約スクリプトをそのまま流用する
（`F-a`〜`F-d` は既存ケースが使用済みのため `F-e` から採番）。

**優先度マクロ（`tools/ttg/bin/configure.yaml`）**：TOP=8 < HIGH=9 < MID=10 < LOW=11 < BOTTOM=12、
**サブ優先度専用 `TSK_PRI_SUBPRI`=13**（他と一致しない値・ここに置くと `ENA_SPR(13)` が立つ）。
ドライバは SUBPRI(13) より高優先（数値が小）の HIGH/MID に置く。

---

## 3. テストケース設計（Phase A：BB）

すべて単一PE（`PRC_SELF`）に固定し、マルチコアのタイミング非決定性を排除する。
ドライバ（`chg_spr` を呼ぶ running タスク）は対象群より**高い優先度**に置き、対象群が ready のまま留まるようにする。

| ケース | 狙う仕様／分岐 | 構成（要旨） | 期待 |
|---|---|---|---|
| **F-e-1**（PoC・✅緑） | NGKI3673・`change_subprio`・`queue_insert_subprio_tail` のループ両方向 | SUBPRI(13) に ready 2本（subpri 1,2）。`chg_spr` で subpri 小→大に変更し末尾化 | **porder が入替**・subpri 反映 |
| ~~F-e-2~~ → **Phase B へ移管** | NGKI3673（自タスク降格でのディスパッチ・`chg_spr` L603-608 local dispatch） | 自タスク含む同優先度群で `chg_spr(TSK_SELF,大)` | （下記 §3.1 参照：**BB不可**と判明） |
| **F-e-3**（✅緑 2026-06-10） | `queue_insert_subprio_tail` の **break成立**（中間挿入・task.c L215）＝F-e-1（末尾＝break非成立）の補完 | SUBPRI(13) に subpri {1,5,9} の ready 3本。`chg_spr(末尾,3)` で**中間へ挿入** | porder=TASK2(1),TASK4(3),TASK3(5)・subpri反映 |
| **F-e-4**（✅緑 2026-06-10） | NGKI5219（boosted は subpri=0 扱い／`chg_spr` `!boosted` ガード false側） | ENA_SPR=MID(10)。ceiling=MID のミューテックス保持で boosted な MID タスクに `chg_spr(_,5)` | boosted 中は並び替わらず **porder=1 のまま**・subpri=5 は格納 |
| ~~F-e-5~~ → **撤去（BB到達不能）** | 非 ENA 優先度の不変性＝`chg_spr` L600 ガード **false側**（陰性確認） | （§3.2 参照） | （`chg_spr` 対象は TTG が必ず ENA_SPR 化＝意図不成立） |

| **F-e-6**（✅緑 2026-06-10） | NGKI3673 クロスPE並び替え＝`change_subprio` の他PE `update_schedtsk_dsp`(IPI)・cross-PE 効果の明示検証 | TASK1(PRC_SELF) が TASK2(running,subpri1,PRC_OTHER)・TASK3(ready,subpri2,PRC_OTHER) に `chg_spr(TASK2,3)` | 他PEで TASK3 が running 化・TASK2 は ready/subpri3/porder2（バリア同期で検証） |

> 注：F-e-3 は当初案（{0,1,1,2} 昇順初期整列）から、**未到達だった break成立（中間挿入）枝**を狙う構成へ変更（F-e-1 が末尾＝break非成立を既にカバー済のため、補完価値が高い方を採用）。
> 注：F-e-6 は cross-PE の `update_schedtsk_dsp` 自体は既存 F-c 系で到達済のため**カバレッジ増分なし**だが、cross-PE の subprio 並び替え効果（porder）を明示検証する（§7.1）。

### 3.2 F-e-5 の所見：L600 ガード「非ENA優先度」false側は **BB到達不能**（2026-06-10）

当初 F-e-5 は「ENA_SPR していない優先度で `chg_spr` しても並び替わらない（L600 の `subprio_primap & PRIMAP_BIT(priority)` が false）」を狙ったが、**TTG は `chg_spr` の対象タスクの現在優先度に対して必ず `ENA_SPR` を生成する**（`tools/ttg/bin/product/IntermediateCode.rb:272-274` の `:subpri` 要素＝subpri パラメータ**または chg_spr 対象**の `tskpri` を `@aTskpriForSubpri` に push → `CBuilder.rb:236` で `ENA_SPR`）。
よって **TTG生成の `chg_spr` テストでは対象優先度が常に ENA_SPR 済み**＝L600 第1条件は常に true。「非ENA優先度での chg_spr」は **BB（TESRY）で表現不可**。

実測でも F-e-5 単体 cfg に `ENA_SPR(10)`（対象 TASK2@MID 由来）が生成され、default subpri が大きいため `chg_spr(_,5)` は**昇格（true側）**を踏んでいた（porder=1 は偶然一致）。
さらに共有優先度 MID(10) の `ENA_SPR` が autocode 同一グループの `rot_rdq(10)` を **E_ILUSE** 化（グループ cfg 共有のため）。

→ **対応**：F-e-5 を撤去。L600 ガード **false 側は F-e-4（boosted＝第2条件 `!boosted` が false）が既にカバー**。第1条件 false（非ENA優先度）は BB到達不能として記録（WB でも対象優先度を ENA_SPR せずに `chg_spr` する手書きが要るが、効果が無い経路＝優先度低）。
**重要な設計則**：サブ優先度BBケースは **chg_spr 対象を必ず専用 `TSK_PRI_SUBPRI(13)` に置く**（共有優先度を対象にすると ENA_SPR が同一グループの `rot_rdq` 等を壊す）。F-e-4 も MID→SUBPRI(13) に修正済。

> 本設計ドキュメントでは **F-e-1 を PoC として実装・QEMU 緑化**し、TESRY の `porder` による
> サブ優先度**並び替え効果**検証の実現可能性を証明する（`time_event_W-*` の立ち上げと同じ進め方）。
> F-e-2〜5 はレビュー後に順次追加。

### F-e-1 詳細（PoC）

```
pre_condition:
  TASK1: running, tskpri=TSK_PRI_HIGH(9), PRC_SELF                 … ドライバ（chg_spr 呼出し元）
  TASK2: ready,   tskpri=TSK_PRI_SUBPRI(13), subpri=1, PRC_SELF    … ENA_SPR(13) を誘発
  TASK3: ready,   tskpri=TSK_PRI_SUBPRI(13), subpri=2, PRC_SELF
  初期レディキュー(pri13): [TASK2(subpri1), TASK3(subpri2)]  → porder TASK2=1, TASK3=2

do:
  TASK1 が chg_spr(TASK2, 3) を発行
  → TASK2.subpri 1→3、pri13 は subprio_primap 立 ＆ TASK2 は !boosted
  → change_subprio → queue_insert_subprio_tail：TASK2 が TASK3 の後ろへ

post_condition:
  TASK3: porder=1
  TASK2: porder=2, subpri=3
  ercd : E_OK
```

踏む分岐：`ENA_SPR(13)` 静的生成 / `make_runnable` subprio tail（task.c L261）/ `current_subpri` 通常側（L195）/
`chg_spr` L600-602 / `change_subprio`（L437）/ `queue_insert_subprio_tail` のループ比較（L208-220）。
ドライバ TASK1 は pri9＝SUBPRI(13) より高優先で running を維持するため、対象群は ready のまま観測できる。

### 3.1 F-e-2 の所見：`chg_spr` L603-608（local dispatch）は **BB不可**（2026-06-10 実測）

当初設計（自タスク TASK1 を SUBPRI(13) に置き `chg_spr(TSK_SELF,3)` で兄弟 TASK2 の後ろへ降格）を
specified_tesry で生成・QEMU 実行したところ、**`FMP_..._TASK2 caused a timeout in ttsp_wait_finish_sync()`**
でデッドロック（CP1-4 通過後）。原因は構造的：

- `chg_spr(TSK_SELF, 大)` は内部で `p_selftsk != p_my_pcb->p_schedtsk` が真となり **`dispatch()`** を呼ぶ
  （＝**狙った L603-608 は実行された**）。これにより actor TASK1 が**CPUを失い** TASK2 へ切替わる。
- しかし TTG は **`do` の後に actor が走り続ける前提**で actor(TASK1) 内に post_condition 検証を生成する
  （生成 out.c で `check_value(TASK1.tskstat, TTS_RUN)` を確認）。actor が戻れず、切替先 TASK2 は
  `wait_finish_sync` で全タスク同期を待ち続け → デッドロック。
- 確認された構造則：**TTSP3 の BB はディスパッチ誘発を「対象を PRC_OTHER に置き、actor(PRC_SELF)は走行継続」**
  で表現する（`chg_pri_F-e-1-1-1-1` 等 NGKI1194 系がこのイディオム）。**actor自身がCPUを失う chg_spr L603-608
  （caller の同PE `p_schedtsk` が変わる local dispatch）は、この枠組みと両立しない**（先の「戻らない syscall」と同類）。

→ **対応**：`chg_spr` L603-608（同PE自降格 local dispatch）と `change_subprio` L447-449 same-PE
  `update_schedtsk_dsp` は **Phase B（WB手書き）へ移管**（§4）。切替先タスクが検証・解放を担う本体を手書きする。
  なお **他PE版**（対象を PRC_OTHER に置く chg_spr 降格）は `change_subprio` L447-449 の **cross-PE
  `update_schedtsk_dsp`（IPI）** を踏み **BB可**（chg_pri F-e と同型）。必要なら別ケースとして追加可
  （ただし L603-608 local dispatch は踏まない＝plan の F-e-2 本来の狙いとは別経路）。

---

## 4. Phase B（WB・残分岐）

BB で踏めない枝は `wb_test/FMP/task/`（`time_event_W-*` 方式の手書き）で補う：

- `task.c` L384 `queue_insert_subprio_head`（mtxmode 真）：ミューテックス ceiling/継承による
  優先度変更時の head 挿入。`change_priority(mtxmode=true)` 経路。
- `current_subpri` の boosted 側（L195 真）が並び替えに効く経路（boosted タスクが
  サブ優先度有効優先度に居るときのキュー位置）。
- **（✅ 完了 2026-06-10）`chg_spr` L603-608 local dispatch ＋ `change_subprio` L447-449 same-PE
  `update_schedtsk_dsp`**：自タスクが SUBPRI 群で `chg_spr(TSK_SELF,大)` 降格し、同PEで切替わる経路。
  WB手書き **`wb_test/FMP/task_manage/chg_spr_W-a`** で到達。MAIN(pri1) が TASK_A/B(pri13・ENA_SPR(13)) を
  用意→slp_tsk→TASK_A が自己降格→TASK_B へ dispatch（L603-605）→TASK_B が porder 検証後 slp_tsk→
  TASK_A 復帰で L606-607 到達→MAIN 起床・finish。**execute.log 緑（cp1-8）／gcov chg_spr line 33/33=100%・
  L603-608 全 covered**。切替先タスクが検証・解放を担うことで BB のデッドロック（§3.1）を回避。

---

## 5. 実行・検証手順

```bash
# 単体（PoC）：specified_tesry で1ケースだけ生成・ビルド・実行
SPEC_YAML="api_test/FMP/task_manage/chg_spr/chg_spr_F-e-1.yaml" \
  printf '1\n4\n1\ne\nr\nq\n' | bash ttb.sh ../fmp3/ FMP obj_fmp
#   1: API Tests → 4: Specified YAML → 1: TTG+make → e: 実行(QEMU) → r,q
# 合否：execute.log に "All check points passed." が出ること

# 回帰（全FMP）：CI ランナー
bash scripts/ci_run_fmp.sh          # full（stage 1 依存チェック→2 API→3 cfgerr）
```

判定は `execute.log` のチェックポイント（FMP は `PE N : All check points passed.`）。
「通るはず」では報告しない（AGENTS.md §4 検証の鉄則）。

---

## 6. リスク・判断メモ

- **(R1) TTG が `subpri` と `porder` を pre/post で整合生成できるか**：✅ **解消（2026-06-10）**。
  F-e-1 を `specified_tesry` で生成→ビルド→QEMU 実行し、`execute.log` に
  `FMP_task_manage_chg_spr_F_e_1: OK` ／ `PE 1 : All check points passed.`（全10CP通過）。
  TESRY の `porder` でサブ優先度並び替えを宣言的に検証できることを実証。
  生成物：`obj_fmp/api_test/specified_tesry/`（out.c/out.cfg は TTG 生成）。
- **(R2) 単一PE固定**で十分か：サブ優先度の並び替え自体は PE 内レディキュー操作なので単一PEで完結。
  クロスPE移送（`mig_tsk`）との相互作用は対象外（後段）。
- **改変記録**：本作業は TTSP3 側（テスト追加）のみ。カーネル（fmp3）は読取専用（禁則②）。
  追加・改変は `DIVERGENCE_MAP.md` B表へ記録する。
- **(R3) autocode グループは cfg 共有**：20分割の各グループは1つの out.cfg を共有し、`ENA_SPR(P)` は
  そのグループ全テストに効く。サブ優先度ケースが**共有優先度**（MID(10) 等）を chg_spr 対象/ subpri 付与に
  使うと、同一グループに同居する `rot_rdq(P)` 等が **E_ILUSE**（subprio有効優先度の回転は不正）。
  **設計則：サブ優先度BBケースは対象・subpri付与を必ず専用 `TSK_PRI_SUBPRI(13)`（他テスト不使用）に閉じる**。
  F-e-4 を MID→SUBPRI(13) に修正し解消（2026-06-10 実測：修正前 PASS=180/FAIL=2 → 修正後 **PASS=182/FAIL=0**）。
- **(R4) chg_spr 対象は TTG が必ず ENA_SPR 化**：`chg_spr` の `do` 対象タスクの優先度は
  `@aTskpriForSubpri` に入り `ENA_SPR` が生成される（`IntermediateCode.rb:272`/`CBuilder.rb:236`）。
  ゆえに「非ENA優先度での chg_spr」（L600 第1条件 false）は **BB到達不能**＝旧 F-e-5 撤去（§3.2）。

---

## 7. Phase A 完了状況（2026-06-10）

| ケース | 狙い | 結果 |
|---|---|---|
| F-e-1 | change_subprio・queue_insert_subprio_tail 末尾挿入（break非成立） | ✅ 緑 |
| F-e-3 | queue_insert_subprio_tail **break成立**（中間挿入・task.c L215） | ✅ 緑 |
| F-e-4 | NGKI5219 boosted＝subpri 0扱い・`chg_spr !boosted` ガード false側 | ✅ 緑（SUBPRI(13)に固定） |
| F-e-2 | chg_spr L603-608 local dispatch（自タスク降格） | → **Phase B（BB不可・§3.1）** |
| F-e-5 | L600 非ENA優先度 false側 | → **撤去（BB到達不能・§3.2）** |

**全FMP回帰：`scripts/ci_run_fmp.sh` → PASS=182 / FAIL=0**（cfg-error OK=159・既知残 DEF_INH_c のみ）。
`ENA_SPR(10)` 総数=0（共有優先度汚染なし）。F-e-1/3/4 は autocode 統合でも緑。

**Phase B 進捗（WB手書き・`wb_test/FMP/`）**：
- ✅ ①`chg_spr` L603-608 local dispatch（自タスク降格）＝`wb_test/FMP/task_manage/chg_spr_W-a`（2026-06-10・§4）。
  gcov chg_spr line 100%・L603-608 全 covered。`coverage_gcov_fmp.sh all` で自動収集（`*_W-*` 探索対象）。
- ✅ ②`task.c` L384 `queue_insert_subprio_head`（mtxmode 真）／③`current_subpri` boosted 側（L195 真）：
  **F-e-4(BB) で到達済み**と判明（2026-06-10 gcov実測）。F-e-4 の `loc_mtx`（pri13・ceiling=13 同優先度）が
  `mutex_raise_priority` L250-251（同優先度・subprio・!boosted）→`change_priority(mtxmode=true)`→**L384**を踏み、
  boosted で **L195** を通る。＝Phase B 計画作成時には未到達だったが、本セッション追加の F-e-4 が同時にカバー。
- ✅ ②補完：`queue_insert_subprio_head` の**ループ走査**（continue/break）＝`wb_test/FMP/task_manage/subprio_head_W-a`
  （2026-06-10）。TASK_X(subpri2) が ceiling mtx で boosted→兄弟 P(1)/Q(3) 用意→`unl_mtx` で boosted 解除し
  `change_priority(mtxmode=true)`→queue_insert_subprio_head に**非boosted**(current_subpri=2) を渡し P(1) 走査(continue)→Q(3)で break。
  gcov：`queue_insert_subprio_head` **line 8/8=100%・branch 7/8=87.5%**（F-e-4 の boosted即break と合わせ走査両アーム）。
  execute.log 緑（cp1-7・porder P1/X2/Q3 検証）。**残1 branch**＝「全兄弟走査して break せず末尾挿入」（subpri が全兄弟超）の経路（追って必要なら別ケース）。
- Phase B 完了。サブ優先度の主要分岐（change_subprio／queue_insert_subprio_tail/head／local dispatch／boosted）を BB+WB で網羅。

### 7.1 全体カバレッジ実測（`coverage_gcov_fmp.sh all`・2026-06-10）

WB 全8件緑（chg_spr_W-a・subprio_head_W-a 含む）、autocode/check_library 全緑。集計（31 dirs）：

| 範囲 | line | branch |
|---|---|---|
| **kernel/ TOTAL** | **3535/3621 = 97.6%** | **1535/1597 = 96.1%** |
| task.c | 166/167 = 99.4% | 74/78 = 94.9% |
| task_manage.c | 267/271 = 98.5% | 149/152 = 98.0% |
| mutex.c | 252/256 = 98.4% | 129/132 = 97.7% |

サブ優先度関数（合算）：
- `current_subpri` **branch 2/2 = 100%**（boosted/非boosted 両アーム）
- `queue_insert_subprio_tail` **4/4 = 100%**（F-e-1 末尾＋F-e-3 中間）
- `queue_insert_subprio_head` **4/4 = 100%**（F-e-4 boosted即break＋subprio_head_W-a 走査）
- `change_subprio` branch **4/6 ＝到達可能分岐の上限**（下記）／`change_priority` branch 17/18

**寄与**：本セッションのサブ優先度テスト（BB F-e-1/3/4/6 ＋ WB chg_spr_W-a/subprio_head_W-a）で
全体分岐は旧 `all` **1520/1597(95.2%) → 1535/1597(96.1%)＝+15 分岐**。挿入3関数は全て branch 100%。

**`change_subprio` 4/6 の精査（2026-06-10）**：残2分岐は内部の `if(TSTAT_RUNNABLE)`(L442)・
`if(subprio_primap & PRIMAP_BIT(pri))`(L443) の **false アーム**。`change_subprio` は `chg_spr` L602 から
**L599(runnable)・L600(subprio)・!boosted のガード内でのみ**呼ばれるため、これら再チェックの false 側は
**到達不能（防御コード）**。＝4/6 が到達可能分岐の上限（残2は §8 到達不能扱い）。
クロスPE `update_schedtsk_dsp`(C-true) は **既存 F-c 系 cross-PE chg_spr が既に到達済**（F-e-6 追加前から 4/6）。
F-e-6 は coverage 増分なしだが、**subprio の cross-PE 並び替え効果（porder）を明示検証**する（既存 F-c は
cross-PE でも porder 未検証＝F-e-1 と同じ「効果未観測」を埋める）。
