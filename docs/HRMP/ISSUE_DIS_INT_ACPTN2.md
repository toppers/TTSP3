# 既知問題：dis_int_H-a と spinlock の acptn2 競合（auto_code_16）

> ステータス：**未解決・後回し**（2026-06-09 記録）
> 関連：`docs/HRMP/COVERAGE_STATUS.md` §残課題

---

## 問題の要約

HRMP auto_code_16 で `HRP_interrupt_dis_int_H_a` が E_OACV 期待に対し E_OK を返す。

## 根本原因

HRP3 3.4.0 の設計として `dis_int` と `loc_spn`/`try_spn`/`unl_spn` が
**同一の** `sysstat1_acvct.acptn2` をアクセス許可チェックに使用している。

```c
// hrmp3/kernel/interrupt.c
CHECK_ACPTN(sysstat1_acvct.acptn2, get_selfdom());  // dis_int [NGKI3084]

// hrmp3/kernel/spin_lock.c
CHECK_ACPTN(sysstat1_acvct.acptn2, selfdom);        // loc_spn [NGKI2193]
CHECK_ACPTN(sysstat1_acvct.acptn2, selfdom);        // try_spn [NGKI2194]
CHECK_ACPTN(sysstat1_acvct.acptn2, selfdom);        // unl_spn [NGKI2202]
```

同一バイナリ内に次の2種のテストが混在すると矛盾が生じる：

| テスト | 要件 |
|---|---|
| `dis_int_H-a.yaml`（HRP）| DOM1 が acptn2 を**持たない**設定 → E_OACV 期待 |
| `try_spn_F-d_HM_ex.yaml` HM1/3/4/5/7（HRMP）| DOM1 が acptn2 を**持つ**設定 → E_OK 期待 |

TTG の `CPUState.rb` は `@@aAccess2` クラス変数でバイナリ内の全 CPU_STATE オブジェクトの
access2 を**union 累積**するため、どちらか一方を犠牲にせざるを得ない。

## 発生条件

- HRMP auto_code_16 に両ファイルが入ったとき
- `average_manifest.rb` がファイルリストをラウンドロビン（DIV_NUM=20）で分配した結果、
  両ファイルが同一グループに割り当てられた（現状では偶然 group 16 が衝突グループ）

```
MANIFEST_AUTO_CODE 内の位置（参考）：
  dis_int_H-a.yaml         … 行 6445（元順位 5016）≡ 16 mod 20
  try_spn_F-d_HM_ex.yaml   … 行 6556（元順位 7236）≡ 16 mod 20
```

## なぜ単純な修正が難しいか

### 案A：グループ分割でファイルを分離
`average_manifest.rb` のラウンドロビンは YAML ファイルの辞書順ソート位置で決まる。
`try_spn_F-d_HM_ex.yaml` を別グループに追い出すには：
- DIV_NUM を変更する（DIV_NUM が変わるとすべてのグループ構成が変わり他の衝突を誘発しうる）
- 直前にダミー YAML を追加してポジションをずらす（アドホック・ファイル数変化で再衝突）

どちらも**ファイル数や DIV_NUM が変わると再発**するアドホック対処。

### 案B：`dis_int_H-a.yaml` を HRMP から除外
HRMP の variation 機構で除外するには TTG の variation 定義変更が必要。
HRMP マニフェストが HRP ファイルを直接 include している構造上、
`_HM_ex.yaml` ファイルで上書きする手段もない（同名テストケース重複でエラー）。

### 案C：`dis_int_H-a.yaml` の expected を HRMP 用に変更
HRMP では spinlock 要件上 DOM1 が acptn2 を持つため、
dis_int_H-a で E_OK を返すのは**仕様上正しい動作**とも言える。
ただし「DOM1 が dis_int を呼べない」シナリオのカバレッジが HRMP では失われる
（HRP では通るので全体としてはカバー済み）。

## 正しい修正の方向性

次のいずれかが妥当：

1. **TTG の variation 機構拡張**（推奨）  
   `dis_int_H-a.yaml` に `hrmp_spinlock_acptn2_grant: false` のような variation を追加し、
   HRMP かつ spinlock テストが access2: TACP(DOM1) を要求する場合にテストを除外する。
   ただし TTG コアの変更が必要。

2. **`CPUState.rb` の累積方式変更**  
   per-test の SAC_SYS 設定（ランタイムパッチ）か、
   union ではなくカテゴリ別の独立 SAC_SYS ブロックを生成する方式。
   これも TTG コアの設計変更。

3. **HRMP spinlock × interrupt テスト専用の分割グループを設ける**  
   `average_manifest.rb` に「競合回避制約」（spinlock DOM1 アクセスを要求するファイルと
   `dis_int_H-a.yaml` を同グループに入れない）を実装する。

## 影響範囲

- 失敗テスト：`HRP_interrupt_dis_int_H_a`（auto_code_16 のみ）
- カバレッジへの影響：E_OACV パスが通らないため `interrupt.c` dis_int 行が未実行になる
  （ただし HRP の同グループでは正常通過済み）
- 他グループ：auto_code_10、12 にも spinlock DOM1 テストあり（同様 SAC_SYS 影響）、
  ただし dis_int_H-a は現在 auto_code_16 にのみ割り当てられている

## 参照ファイル

- `api_test/HRP/interrupt/dis_int/dis_int_H-a.yaml`
- `api_test/HRMP/spin_lock/try_spn/try_spn_F-d_HM_ex.yaml`（HM1/3/4/5/7 が TACP(DOM1) を設定）
- `tools/ttg/common/bin/sys_state/CPUState.rb`（累積ロジック）
- `scripts/average_manifest.rb`（ラウンドロビン分配）
- `docs/HRMP/COVERAGE_STATUS.md` §残課題
