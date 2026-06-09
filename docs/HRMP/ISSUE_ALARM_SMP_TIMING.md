# 既知問題：alarm sta_alm_d_1_H3 の SMP タイミング競合（auto_code_18）

> ステータス：**未解決・後回し**（2026-06-09 記録）
> 関連：`docs/HRMP/COVERAGE_STATUS.md` §残課題

---

## 問題の要約

HRMP auto_code_18 で `ASP_alarm_sta_alm_d_1_H3` が  
チェックポイント 5（post_condition_0_0 完了）より前に  
チェックポイント 7（アラームハンドラ起動）が到着し「Unexpected Check Point : 7」で失敗。

```
ASP_alarm_sta_alm_d_1_H3: Start
PE 1 : Check point : 3 passed.    ← main: mact_tsk 後
PE 1 : Check point : 4 passed.    ← TASK1: pre-condition 完了
## PE 1 : Unexpected Check Point : 7   ← アラームハンドラが早期発火
```

## テスト設計とフロー

テストは `sta_alm_d-1.yaml`（ASP base） ＋ `sta_alm_d-1_H_ex.yaml`（HRP 拡張）の  
`ASP_alarm_sta_alm_d_1_H3` ケース（TASK1: DOM1 ドメイン、ALM1: KERNEL ドメイン）。

```
【main タスク (PE1)】
  msta_alm(ALM1, 1000, 1); stp_alm(ALM1);  ← 前テスト残留クリア
  CP 3
  mact_tsk(TASK1, 1);   ← PE1 で TASK1 起動
  slp_tsk();            ← main 休眠

【TASK1 (PE1, DOM1)】
  pre_condition チェック (ref_tsk/ref_alm)
  CP 4
  sta_alm(ALM1, RELATIVE_TIME_A=3);   ← アラームを 3 tick 後に設定
  ── post_condition_0_0: ref_alm/ref_tsk で lefttim=3 などを確認 ──
  CP 5
  gain_tick() × 3  →  lefttim: 3→2→1→0
  post_condition_0_3: ref_alm lefttim=0 確認
  CP 6
  gain_tick() × 1  →  アラーム発火を誘発
  MP_WAIT_CHECK_POINT(1, 7)  ← ハンドラ CP7 を待機
  wup_tsk(MAIN_TASK); chg_pri(MAIN_TASK, 1);

【アラームハンドラ (ALM1 発火時)】
  CP 7
  post_condition_0_4: ref_alm/ref_tsk チェック
  CP 8
```

## 根本原因

`RELATIVE_TIME_A = 3`（TTG デフォルト値。configure.yaml が存在しないときの既定）。

HRMP SMP QEMU 環境では、`sta_alm(ALM1, 3)` の直後に行う  
`ref_alm`・`ref_tsk` SVC 呼び出し群（post_condition_0_0）の実行中に  
**すでに 3 tick 以上が経過**し、アラームがハンドラを起動してしまう。

- シングルコア（ASP / HRP）や実機ではポスト条件チェックが 3 tick 以内に完了するため再現しない
- QEMU SMP では 2 つの PE が並走するためタイマ精度や割込み処理のオーバヘッドが大きく、
  3 tick で発火するアラームが `ref_alm` SVC 処理中に割り込む

### configure.yaml の不在が直接原因

FMP linux_gcc ターゲットでは `configure.yaml` が存在し  
`RELATIVE_TIME_A: 3000` が設定されている。  
HRMP zybo_z7_gcc には `configure.yaml` が無いため、TTG が既定値 **3** を使用する。

```yaml
# library/FMP/target/linux_gcc/configure.yaml（参考）
RELATIVE_TIME_A   : 3000   # HRMP zybo_z7_gcc には configure.yaml が無い
RELATIVE_TIME_B   : 6000
RELATIVE_TIME_C   : 9000
```

## 影響範囲

- 失敗テスト：`ASP_alarm_sta_alm_d_1_H3` のみ（auto_code_18）
- RELATIVE_TIME_A に依存するアラーム・サイクリック系テスト全般が同様にタイミング  
  依存を持つ可能性がある（他グループは偶然通過している可能性）
- spinlock 移行や TESRY 移行とは無関係の既存問題

## 修正方針

### 対処A（推奨）：configure.yaml の追加
`library/HRMP/target/zybo_z7_gcc/configure.yaml` を作成し、  
`RELATIVE_TIME_A` を QEMU SMP のオーバヘッドに十分な値（例：1000 以上）に設定する。  
FMP linux_gcc（3000）や実機ターゲットの値を参考に調整する。

副作用：同バイナリ内の全アラーム/サイクリックテストの時間定数が変わるため、  
`gain_tick` の呼び出し回数と整合性をとる必要がある（TTG が自動生成するため通常は問題なし）。

### 対処B（局所対処）：HRMP 専用の sta_alm_d-1 変種を作成
`api_test/HRMP/alarm/sta_alm/sta_alm_d-1_HM_ex.yaml` で  
RELATIVE_TIME_A を大きい値にハードコードした HRMP 専用バリアントを追加。  
ただし configure.yaml による統一管理に比べて保守性が低い。

## 参照ファイル

- `api_test/HRP/alarm/sta_alm/sta_alm_d-1_H_ex.yaml`（失敗テストの YAML）
- `obj_hrmp_gcov/api_test/auto_code_18/out.c`（TTG 生成コード。RELATIVE_TIME_A=3 のリテラルを確認可）
- `obj_hrmp_gcov/api_test/auto_code_18/execute.log`（失敗ログ）
- `library/FMP/target/linux_gcc/configure.yaml`（RELATIVE_TIME_A: 3000 の設定参考）
- `docs/HRMP/COVERAGE_STATUS.md` §残課題
