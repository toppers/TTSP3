# HRP TESRY 移行手順マニュアル（3.3.0→3.4.0 アクセス許可仕様変更への追従）

> **目的**：HRP の API オートコードテストが保護カーネル上で E_OACV により早期終了する問題
> （カバレッジ天井 line 79.6% / branch 69.8% の主因）を、TESRY/TTG を 3.4 のアクセス許可
> 仕様へ追従させて解消する。
>
> **対象読者**：本作業を別セッションで実施する担当（人/エージェント）。本書だけで完結するよう
> 根拠・コマンド・検証まで記載する。
>
> **前提知識**：根本原因の詳細分析は [`BB_UNREACHABLE.md` §1](BB_UNREACHABLE.md)、差分台帳は
> `../../DIVERGENCE_MAP.md` A表（「HRP/HRMP：システム状態アクセス許可ベクタの2分割＋強制操作の
> 許可カテゴリ変更」行）。作業規約は `../../AGENTS.md`（カーネルは編集禁止＝禁則②、改変明記＝禁則③）。

---

## 1. 背景（根本原因の要約）

HRP3 **Release 3.3.0→3.4.0** でアクセス許可仕様が2点変わった（`hrp3/doc/version.txt` 「Release
3.3.0 から 3.4.0 への主な変更点」§「システム状態のアクセス許可ベクタの仕様変更に対応」166-176行）。
TTSP3 R3.1.0 の HRP TESRY/TTG は**旧3.3.0モデルのまま**で、HRP3 3.4.x カーネルと不整合。

| 層 | 3.4.0 の変更 | 現状(TTSP3) | 症状 |
|---|---|---|---|
| **層1** | システム状態許可ベクタが**2つ**に（sysstat1/sysstat2）。`sus_tsk`/`ter_tsk`/`ena_ter`/`dis_ter` 等が `sysstat2_acvct` でも禁止される | TTG が `SAC_SYS` を**1ベクタのみ**出力 → sysstat2 既定 `{TACP_KERNEL×4}` | ユーザドメインからの強制操作が一律 E_OACV |
| **層2** | サービスコールの許可カテゴリ変更。`ter_tsk` は **acptn2（通常操作2）** でチェック | TESRY は `ter_tsk` 許可を **access3（管理操作）** に付与し acptn2=KERNEL を期待 | クロスドメイン `ter_tsk` が E_OACV |

**両層は同時に直す必要がある**（実験で確認：層1だけ直しても ter_tsk(層2)で即中断、層2だけでも ter_tsk が sysstat2(層1)を要求して中断）。

### カーネル側の根拠（読み取り専用・編集禁止）

- `hrp3/kernel/task_term.c:305-306`：`ter_tsk` は `acvct.acptn2` ＋ `sysstat2_acvct.acptn3` をチェック。
- `hrp3/kernel/task_sync.c:356-357`：`sus_tsk` は `acvct.acptn2` ＋ `sysstat2_acvct.acptn2`。
- `hrp3/kernel/task_term.c:220,246`：`dis_ter`/`ena_ter` は `sysstat2_acvct.acptn1`。
- `hrp3/kernel/kernel.trb:454-460`：`SAC_SYS` 省略時／第2引数省略時、sysstat2 は `{TACP_KERNEL×4}`（[NGKI0426]）。
- 全サービスコールの acptn 対応は本書末尾「付録A」。

---

## 2. 影響範囲（確定済み）

### 層2：per-object acptn カテゴリ不一致 ＝ **`ter_tsk` のみ（HRP/HRMP両方）**

- HRP 対象：`api_test/HRP/task_term/ter_tsk/*_H_ex.yaml` の **44ファイル**。
- HRMP 対象：`api_test/HRMP/task_term/ter_tsk/*_HM_ex.yaml` の **80ファイル**。
- 確認済み事実（2026-06-09 実測）：
  - HRP: access3 へ非KERNEL付与 **86件、すべて `type: TASK`**。access2 は全て KERNEL。
  - HRMP: access3 へ非KERNEL付与 **154件、すべて `type: TASK`**。access2 は全て KERNEL。
  - ∴ 対象タスクの **access2↔access3 を入れ替える**だけで安全に移行できる。
- 他の acptn2 操作（`sus_tsk`/`rsm_tsk`/`ras_ter`/`chg_pri`/`rel_wai`/`rcv系`/`wai系`）は
  既に access2 で一致＝**修正不要**。`ini_*`(acptn3) は access3 で一致、`ref_*`/`get_*`(acptn4) は
  access4 で一致＝修正不要。

### 層1：システム状態許可ベクタの2分割 ＝ **TTG コード1箇所**

- 生成元：`tools/ttg/common/bin/sys_state/CPUState.rb` の `gc_config`（170行付近）が
  `SAC_SYS({a1,a2,a3,a4})` を1ベクタのみ出力。
- 既存 TESRY は sysstat2 用アクセスを持たない（仕様変更前データ）ため、**TTG が sysstat2 を
  `{TACP_SHARED×4}` で補って出力する**のが現実的（実験で E_OACV 消滅を確認）。
  - 専用システム状態テスト（`DOM_SYS_ACP*` ドメイン）は sysstat1 を明示使用するので影響なし。
  - 影響プロファイル：HRP と **HRMP 両方**（CPUState.rb は共通）。HRMP も同一原因のため整合的。

---

## 3. 前提環境

```bash
cd <workspace>/ttsp3            # 例: /home/honda/TOPPERS/TTSP3/work/ttsp3
# 兄弟に ../hrp3 (= hrp3_3.4) が必要。GCOV計装は導入済み（docs/HRP/COVERAGE_STATUS.md）。
test -d ../hrp3 && echo OK
```

ベースライン値：**line 79.6% (2653/3334) / branch 69.8% (1769/2533)**（`docs/HRP/BB_COVERAGE.md`）。

---

## 4. 段階1：TTG `CPUState.rb` に sysstat2 を出力させる（層1）

`tools/ttg/common/bin/sys_state/CPUState.rb` の `gc_config` の `SAC_SYS` 出力行を、第2引数
（sysstat2＝全ドメイン許可）付きに変更する。

**変更前**（170行付近）:
```ruby
if (@cConf.is_hrp?() && !@@aAccess1.empty?())
  cElement.set_config("#{API_SAC_SYS}({#{@@aAccess1.join('|')}, #{@@aAccess2.join('|')}, #{@@aAccess3.join('|')}, #{@@aAccess4.join('|')}});", IMC_NO_CLASS, TTG_MAIN_DOMAIN)
end
```

**変更後**（第2引数 sysstat2 = TACP_SHARED×4 を追加。HRP3 3.4 のシステム状態許可ベクタ2分割対応）:
```ruby
if (@cConf.is_hrp?() && !@@aAccess1.empty?())
  cElement.set_config("#{API_SAC_SYS}({#{@@aAccess1.join('|')}, #{@@aAccess2.join('|')}, #{@@aAccess3.join('|')}, #{@@aAccess4.join('|')}}, {TACP_SHARED, TACP_SHARED, TACP_SHARED, TACP_SHARED});", IMC_NO_CLASS, TTG_MAIN_DOMAIN)
end
```

> 注：`SAC_SYS` の第2引数省略時に sysstat2 が KERNEL 既定になるのが層1の原因。第2引数を明示する。
> TTG は TTSP3 git 管理下＝改変明記は git 履歴＋ `DIVERGENCE_MAP.md` B表で行う（ファイル冒頭への
> `[改変]` 行は付けない方針。`docs/WB_SPEC_TERMS.md`／既存方針に従う）。

**代替（TTGを変えずに測定だけしたい場合）**：`scripts/ttsp_parallel_api.sh` の
`GCOV_GRANT_SYSSTAT2=1`（既定オフの実験フック）で生成 out.cfg を後処理できる。恒久対応は上記 TTG 修正。

---

## 5. 段階2：`ter_tsk` の TESRY で access2↔access3 を入替（層2）

`api_test/HRP/task_term/ter_tsk/*_H_ex.yaml`（HRP 44ファイル）および
`api_test/HRMP/task_term/ter_tsk/*_HM_ex.yaml`（HRMP 80ファイル）の
各オブジェクトの access2 と access3 の**値**を入替える。
post_condition の acvct アサーションは TTG が SAC 値から自動生成するため、TESRY 修正だけで追従する。

```bash
cd <workspace>/ttsp3

# HRP（44ファイル）
files_hrp=$(find api_test/HRP/task_term/ter_tsk -name '*_H_ex.yaml')
for f in $files_hrp; do
  perl -0pi -e 's/(access2: *)([^\n]+)(\n\s*access3: *)([^\n]+)/${1}${4}${3}${2}/g' "$f"
done
echo "HRP after: access3非KERNEL付与(0になるはず): $(grep -hE 'access3: *(TACP\((DOM|SHARED)|TACP_SHARED)' $files_hrp | wc -l)"
echo "HRP after: access2非KERNEL付与(86になるはず): $(grep -hE 'access2: *(TACP\((DOM|SHARED)|TACP_SHARED)' $files_hrp | wc -l)"

# HRMP（80ファイル）
files_hrmp=$(find api_test/HRMP/task_term/ter_tsk -name '*_HM_ex.yaml')
for f in $files_hrmp; do
  perl -0pi -e 's/(access2: *)([^\n]+)(\n\s*access3: *)([^\n]+)/${1}${4}${3}${2}/g' "$f"
done
echo "HRMP after: access3非KERNEL付与(0になるはず): $(grep -hE 'access3: *(TACP\((DOM|SHARED)|TACP_SHARED)' $files_hrmp | wc -l)"
echo "HRMP after: access2非KERNEL付与(154になるはず): $(grep -hE 'access2: *(TACP\((DOM|SHARED)|TACP_SHARED)' $files_hrmp | wc -l)"
```

> **安全性の根拠**（2026-06-09 確認済）：HRP/HRMP いずれも access3 付与は全て TASK 対象、access2 は
> 全て KERNEL。タスクの acptn3（管理操作）は 3.4.x で未使用のため、入替（access3→KERNEL）は無害。
> 非タスクオブジェクト（ini_* 用 access3 等）は ter_tsk テストに存在しないので巻き込まない。
>
> もし将来 ter_tsk 以外で同種不一致が見つかった場合のみ追加対象とする（現状は ter_tsk のみ）。

---

## 6. 段階3：再生成・再計測・検証

```bash
cd <workspace>/ttsp3
# bb モードで再計測（段階1のTTG修正が効くので GCOV_GRANT_SYSSTAT2 は不要）
rm -rf obj_hrp_mig
OBJ_DIR=obj_hrp_mig bash scripts/coverage_gcov_hrp.sh bb 2>&1 | tee /tmp/hrp_mig_bb.log

# 末尾の "=== kernel coverage by gcov ... TOTAL" を確認。
# 期待：line/branch がベースライン(79.6%/69.8%)から上昇。特に task_term.c が向上。
```

### 検証ポイント

1. **カバレッジ上昇**：`TOTAL` 行がベースラインを上回るか。
2. **E_OACV 早期終了の減少**：各グループの中断状況を確認。
   ```bash
   for i in $(seq 1 20); do
     f=obj_hrp_mig/api_test/auto_code_$i/execute.log
     [ -f "$f" ] || continue
     t=$(tr -d '\r' < "$f")
     echo "auto_code_$i: last=$(echo "$t" | grep -oE 'Check point [0-9]+ passed' | tail -1) E_OACV=$(echo "$t" | grep -c E_OACV) end=$(echo "$t" | tail -1 | grep -oE 'E_OACV|check point 0|All check points')"
   done
   ```
   ter_tsk 起因の E_OACV が消え、より深いチェックポイントまで到達するはず。
3. **新たな不整合の洗い出し**：依然 E_OACV/`Unexpected check point`/`Unexpected value`(アサーション失敗)
   が残るグループは、`out.c` の中断行から次の不一致操作を特定し、層1/層2 と同じ要領で原因分類する
   （§7 のループ）。

### 回帰確認（非GCOV・check_library・他プロファイル）

```bash
# HRP check_library が緑のままか（方式A）
printf 'c\n1\n1\nr\nr\nq\n' | bash ttb.sh ../hrp3/ HRP obj_hrp_reg >/tmp/reg.log 2>&1
for d in exception interrupt timer; do echo "$d: $(tr -d '\r' < obj_hrp_reg/check_library/$d/execute.log | tail -1)"; done
# TTG CPUState.rb 変更は HRMP にも波及。HRMP も再計測して回帰が無いか確認（docs/HRMP/）
```

---

## 7. 段階3：HRMP spinlock sysstat1 対応（HRMP 固有）

> HRP3 3.3.2→3.4.0 で `loc_spn`/`try_spn`/`unl_spn` に `CHECK_ACPTN(sysstat1_acvct.acptn2, selfdom)` が追加
> （`hrmp3/doc/version.txt` 「Release 3.3.2 から 3.4.0 への主な変更点」）。
> TESRY に CPU_STATE1 の access フィールドが無いため、TTG が sysstat1_acvct.acptn2 に DOM1 を含めず E_OACV。

### 影響ファイル（HRMP のみ・HRP は spinlock 非対象）

`api_test/HRMP/spin_lock/{loc_spn,try_spn,unl_spn}/*_HM_ex.yaml` の non-ntc 5ファイル：
- `loc_spn_F-c_HM_ex.yaml`, `loc_spn_F-d_HM_ex.yaml`
- `try_spn_F-d_HM_ex.yaml`
- `unl_spn_F-c-1_HM_ex.yaml`, `unl_spn_F-c-2_HM_ex.yaml`

各ファイルの HM1/HM3/HM4/HM5/HM7（DOM1 が呼び出し元）の `pre_condition` 内 `CPU_STATE1` に
以下 4フィールドを追加（HM2/HM6 は KERNEL 呼び出し元のため修正不要）：

```yaml
      access1: TACP_KERNEL
      access2: TACP(DOM1)
      access3: TACP_KERNEL
      access4: TACP_KERNEL
```

CPUState.rb が `access1` nil のとき `@@aAccess*` に追加しないため、**4フィールド全て要設定**。

### 修正スクリプト（Python）

```python
# api_test/HRMP/spin_lock/ 以下の5ファイルを対象
# pre_condition CPU_STATE1（type: CPU_STATE あり）かつ TASK1 domain=DOM1 のケースに追加
# 実際の適用は 2026-06-09 Python スクリプトで実施（git 履歴参照）
```

### 副作用（設計上の制約）

`dis_int`・`ena_int`・`ref_int`・`dis_dsp` 等も `sysstat1_acvct.acptn2` を参照
（`hrmp3/kernel/interrupt.c:184, 231, 278, 325, 419`）。
DOM1 を acptn2 に追加すると、同一バイナリで「DOM1 が dis_int を呼べないこと」を検証する
`HRP_interrupt_dis_int_H_a`（`api_test/HRP/interrupt/dis_int/dis_int_H-a.yaml` 期待 E_OACV）が
E_OK で失敗する（設計上の競合。詳細は `docs/HRMP/COVERAGE_STATUS.md` §「残課題」）。

### 計測結果（2026-06-09）

| プロファイル | 移行前 line/branch | 移行後 line/branch |
|---|---|---|
| HRMP | 91.0% / 81.3% | **91.3% / 82.1%** |

auto_code_10, 12: E_OACV 解消 → All check points passed。
auto_code_16: spinlock 解消後に dis_int_H-a 競合が露出（上記副作用）。
15/17 runnable グループで All check points passed（旧：13/17）。

---

## 8. 反復（次の不一致層の発見）

層1+層2 適用後も残る中断は、同じ手法で芋づる式に解析する：

1. 中断グループの `execute.log` 末尾から `out.c:<行>` を取得。
2. その行の API（`ercd = <syscall>(...)`）と、対象オブジェクトの `SAC_*`（cfg）を確認。
3. カーネルの `CHECK_ACPTN`（付録A）と TESRY の付与スロットを突合 → 不一致なら TESRY 修正、
   テスト期待値そのものが旧仕様なら期待値修正。
4. `Unexpected value ... acvct.acptnN` のアサーション失敗は、acvct 値検証が旧スロット前提＝
   TESRY の access フィールド修正で SAC とアサーションを同時に追従させる。

---

## 8. 記録（完了時）

- `DIVERGENCE_MAP.md` A表の該当行を「**対応済**（段階1+2実装・実測 line ××%/branch ××%）」に更新。
- `DIVERGENCE_MAP.md` B表（変更履歴）に TTG `CPUState.rb` 改変と ter_tsk TESRY 44件の access 入替を追記。
- `docs/HRP/BB_COVERAGE.md` / `BB_UNREACHABLE.md` を新しい計測値・残課題で更新。
- TESRY/TTG は TTSP3 git 管理下なので、改変明記は git コミット＋上記台帳が正本（禁則③）。
- カーネル（`../hrp3`）は一切編集しない（禁則②）。本移行は TTSP3 側（TTG＋TESRY）のみで完結する。

---

## 9. リスク・ロールバック

- **意味変更**：本移行はテストデータの保護仕様前提を 3.4 に合わせる正当な追従。ただし sysstat2=SHARED は
  システム状態保護の負テストを弱める可能性 → §6 回帰で「期待 E_OACV が E_OK になった」テストが無いか確認。
- **ロールバック**：すべて git 管理下。`git checkout -- api_test/HRP/task_term/ter_tsk tools/ttg/common/bin/sys_state/CPUState.rb` で復元可能。
- **段階適用**：段階2(ter_tsk)→段階1(TTG)の順でも、まとめてでもよいが、**実測は両方適用後**に行う
  （片方だけでは前進しない）。

---

## 付録A：HRP3 3.4.x サービスコール→acptn 対応（カーネル `CHECK_ACPTN` から抽出）

| acptn | カテゴリ | サービスコール |
|---|---|---|
| acptn1 | 通常操作1 | act_tsk, can_act, can_wup, wup_tsk, set_flg, clr_flg, sig_sem, snd/psnd/tsnd/fsnd_dtq, snd/psnd/tsnd_pdq, snd/psnd/tsnd_mbf, get/pget/tget_mpf, loc/ploc/tloc_mtx, unl_mtx, sta_alm, sta_cyc |
| acptn2 | 通常操作2 | **ter_tsk**, sus_tsk, rsm_tsk, ras_ter, chg_pri, rel_wai, rot_rdq, mrot_rdq, rcv/prcv/trcv_dtq, rcv/prcv/trcv_pdq, rcv/prcv/trcv_mbf, wai/pol/twai_flg, wai/pol/twai_sem, rel_mpf, stp_alm, stp_cyc |
| acptn3 | 管理操作 | ini_dtq, ini_pdq, ini_mbf, ini_flg, ini_sem, ini_mtx, ini_mpf （初期化操作のみ。タスクでは未使用） |
| acptn4 | 参照操作 | ref_*, get_pri, get_tst, get_lod, get_nth, mget_lod, mget_nth, prb_mem |

システム状態（sysstat2）ゲート操作：sus_tsk(acptn2), ter_tsk(acptn3), rsm_tsk/frsm_tsk(acptn1),
dis_ter/ena_ter(acptn1) ほか（`hrp3/kernel/*.c` の `CHECK_ACPTN(sysstat2_acvct.*)` 参照）。

## 付録B：本マニュアル作成時点の調査成果物

- 実験フック：`scripts/ttsp_parallel_api.sh` の `GCOV_GRANT_SYSSTAT2=1`（層1の測定用・既定オフ）。
- 実測（sysstat2のみ付与）：line 79.6→79.7% / branch 69.8→70.8%（task_term.c が 100%line/93.8%branch へ。
  層2 ter_tsk 未修正のため全体増は小）。
- 根拠データの再現は `docs/HRP/BB_UNREACHABLE.md §1` の手順・コマンド参照。
