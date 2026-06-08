# SPEC37_PLAN.md — 仕様差分(3.4→3.7.2)の棚卸しと実装計画

> 対象方針：**ASP3 / FMP3 を zybo_z7_gcc（QEMU）基準で**進める（DIVERGENCE_MAP 開発方針）。
> POSIX(linux_gcc)は副次、HRMP3/HRP3 は後回し。
> 差分の根拠は `asp3/doc/version.txt`（Release 3.4.0→3.7.2 の5区間）。
> 本書は棚卸し（インベントリ）と残実装作業の計画。確定済みの差分台帳は DIVERGENCE_MAP.md。

最終更新：2026-06-08

---

## 0. 現状サマリ

TTSP3 R3.1.0（仕様3.4.0）↔ 被テスト ASP3 3.7.2 / FMP3 3.4.0。
**zybo 基準では主要な 3.4→3.7 差分は吸収済みで全緑**（ASP オートコード2202・cfg-error 113、
FMP オートコード20・cfg-error 159、CI matrix 緑）。本書の残作業は主に
(a) 一部の期待値・新仕様の確認、(b) 3.7新機能の正系テスト追加（任意）。

---

## 1. 棚卸し（3.4.0 → 3.7.2 の全差分 × TTSP3影響 × 状態）

凡例：✅=対応済/影響なし確認、🔧=本セッションで対応、🔶=要確認（残作業）、➖=対象外、⏸=後回し

### 3.4.0 → 3.5.0
| 差分 | TTSP3影響 | 状態 |
|---|---|---|
| 高分解能タイマ64bit化（HRTCNT型変更） | 時刻/タイマテスト・target | ✅ 影響なし確認（timerチェック緑・要a9gtimerパッチ） |
| 静的API末尾 `;` 必須化 | 生成cfg・TESRY | ✅ 影響なし確認（全ビルド成功） |
| モノトニックタイマ機能拡張パッケージ | time_manage（任意pkg） | ➖ R3.1.0スイートにテストなし |
| フェイタルデータアボートをCPU例外化・例外ハンドラ番号割付 | 例外テスト・EXCNO/DEF_EXC | ✅ 影響なし確認（P1-3, 2026-06-08。exceptionチェックは TTSP_EXCNO_A=EXCNO_UNDEF を使用し zybo緑。新EXCNOはtarget追加能力で既存テスト不変。専用テストは任意=P2候補） |
| `VALID_TMOUT`定義変更／`check_adjtim`の型・条件式変更 | adj_tim・タイムアウト系テスト | ✅ 影響なし確認（P1-2, 2026-06-08。adj_tim_b は adj_tim(TMIN_ADJTIM-1/TMAX_ADJTIM+1)→E_PAR の境界テストで zybo autocode緑。POSIX g7/g9 は実時間systim値の別問題） |

### 3.5.0 → 3.6.0
| 差分 | TTSP3影響 | 状態 |
|---|---|---|
| **拡張情報の型を EXINF に変更** | TTG生成コード・test（exinf） | ✅ 影響なし確認（EXINF=intptr_t のためTTG生成の`intptr_t exinf`と一致。将来EXINFが別型のtargetでは要TTG修正） |
| 静的APIテーブルエラー時にファイル名・行番号出力 | cfg-error（エラーメッセージ書式） | ✅ 影響なし（合否はエラーコードgrepで判定・行番号非依存） |
| 周期/アラーム通知ハンドラ名変更・自己診断等 | カーネル内部 | ➖ TTSP3非依存 |

### 3.6.0 → 3.7.0
| 差分 | TTSP3影響 | 状態 |
|---|---|---|
| macOS/Linux POSIXシミュ追加 | host/POSIXターゲット | 🔧 FMP POSIX(linux_gcc)対応済（副次・実装不安定） |
| サブ優先度仕様変更：上限がサブ優先度使用のエラーチェック削除（NGKI3682廃止） | CRE_MTX_F-c（負テスト） | 🔧 CRE_MTX_F-c を削除（obsolete・本セッション） |
| 優先度継承機能拡張パッケージ | mutex系（任意pkg） | ➖ 任意pkg・既存mutex系は緑 |
| CRE_XXX のID衝突をエラー化 | 静的APIテスト | ✅ 影響なし確認（cfg-error緑・TTG生成IDは一意） |
| 不正クラスIDのチェック方式変更（クラスの囲みに対して） | cfg-error（`*_F-b`不正クラス） | 🔧 期待値 E_RSATR→E_ID に更新17件（本セッション） |
| objdumpダンプ形式対応 | cfg/ビルド | ✅ 影響なし確認 |
| arm.c廃止（arm.hに統合） | target KERNEL_COBJS | ✅ 全ターゲットで arm.o 削除済 |
| ARM GIC EOI仕様変更 | target（zybo割込み） | ✅ zybo割込みチェック緑 |

### 3.7.0 → 3.7.1
| 差分 | TTSP3影響 | 状態 |
|---|---|---|
| sample/Makefile修正・doc | なし | ➖ |

### 3.7.1 → 3.7.2
| 差分 | TTSP3影響 | 状態 |
|---|---|---|
| istk不要対応（OMIT_ISTK） | DEF_ICS（POSIX）・target | 🔶 POSIX固有のDEF_ICS残10件（ターゲット特性・副次）。zyboは影響なし |
| **オブジェクトID重複チェックが厳し過ぎる不具合修正（緩和）** | ID衝突系cfg-error | ✅ 影響なし確認（P1-1, 2026-06-08。E_OBJ系（CRE_DTQ_c/CRE_SEM_d等）は「同種オブジェクトの同一ID二重定義→E_OBJ」の従来仕様でzybo全緑。3.7.2が緩和したのは異種ID衝突（3.7.0新規）側で、TTSP3 R3.1.0は異種衝突テストを持たないため不変） |
| ARM割込み番号/ハンドラ番号/CPU例外番号の暗黙制限解除（TMAX_INHNO/EXCNO） | DEF_INH/CFG_INT範囲テスト・target | ✅ FMP target対応済（TMAX_INHNO等）。zybo緑 |
| タイマドライバシミュレータ simtim_add 廃止 | target（simtimer） | ➖ zyboはMPCore GTC使用・simtimer非依存 |

---

## 2. 実装作業計画（残作業・優先度順）

### P1. 期待値・新仕様の確認（✅ 完了 2026-06-08・3項目とも影響なし）
zyboで緑の項目を「偶然通っている / 仕様変更が期待値に影響していないか」能動検証した。
**結論：修正不要**。台帳の「影響なし確認」を実証ベースに格上げ。

- **P1-1. ID重複チェック緩和（3.7.2）** … ✅ 影響なし。E_OBJ系cfg-errorは
  「同種オブジェクトの同一ID二重定義→E_OBJ」（CRE_DTQ_c/CRE_SEM_d等）の従来仕様で
  zybo全緑。3.7.2の緩和対象は異種ID衝突（3.7.0新規）側で、R3.1.0は異種衝突テスト
  を持たないため不変。
- **P1-2. check_adjtim 条件式変更（3.4→3.5）** … ✅ 影響なし。adj_tim_b は
  `adj_tim(TMIN_ADJTIM-1/TMAX_ADJTIM+1)`→E_PAR の境界テストで zybo autocode緑。
- **P1-3. フェイタルデータアボートEXCNO（3.4→3.5）** … ✅ 影響なし。exceptionチェックは
  `TTSP_EXCNO_A=EXCNO_UNDEF`（未定義命令）でzybo緑。新EXCNOはtarget追加能力で
  既存テスト不変。**任意の追加候補**：フェイタルデータアボートEXCNO専用の例外テスト
  （→ P2 の新機能テストに含めても良い）。

### P2. 3.7新機能の正系テスト追加（任意・コア価値）
TTSP3 R3.1.0 に無い 3.7 新機能の網羅テストを追加する（仕様適合性の本来目的）。
コストは中〜大。zybo基準・ASP/FMP優先で着手判断。

- **P2-1. サブ優先度（subprio）固有テスト** … 3.6→3.7の仕様変更（優先度上昇状態中の
  サブ優先度の扱い等）。chg_spr/サブ優先度付き優先度のTESRY追加＋TTG対応。
  → 詳細設計は下記「P2-1 設計サブプラン」。
- **P2-2. モノトニックタイマ拡張パッケージ** … get_utm系。任意パッケージのため
  カーネル側のpkg有効化が前提。
- **P2-3. 優先度継承拡張パッケージ** … 既存mutex系の拡張。任意pkg。

→ それぞれ TESRY（yaml）追加 → TTG生成 → zybo QEMU で緑化、の手順。
   着手前に「3.7対応済みの公式TTSP3が無いか」確認（重複作業回避・AGENTS.md）。

### P3. TTG の 3.7 生成対応（残）
- 現状 TA_EDGE/int_trigger_atr（POSIX用）は対応済。zybo生成は緑。
- P2 で新機能テストを足す場合に、対応する生成ロジック（サブ優先度の静的API等）を追加。

### P2-1 設計サブプラン（サブ優先度テスト・2026-06-08調査）

**前提・調査結果**
- サブ優先度は ASP3 の**拡張パッケージ**（`asp3/extension/subprio/`）。標準 zybo 簡易
  パッケージ（CI基準カーネル）には**含まれない**。
- 有効化＝拡張オーバーレイ：asp3ソースツリー先頭で `cp -r extension/subprio/* .`
  （本体ファイルを上書き）。`TOPPERS_SUPPORT_SUBPRIO` が kernel.h で定義される。
- 追加API：`ER chg_spr(ID tskid, uint_t subpri)`（サブ優先度変更）。T_RTSK に
  `uint_t subpri` フィールド追加。サブ優先度は task の現在優先度内の順序付け。
- 拡張に参照テストあり：`extension/subprio/test/test_subprio{1,2,3}.{c,cfg}`＋
  `test_subprio.txt`（TESRY/期待値の設計モデルになる）。
- TTSP3 R3.1.0 には**サブ優先度専用テストは無い**（ref_tsk.txt が subpri フィールドに
  言及する程度）＝完全な新規カバレッジ。

**実装ステップ（提案）**
1. **カーネル変種の確立**：subprioオーバーレイ済み asp3 を別ツリー（例 `../asp3_subprio`、
   または exshonda 配下の git版に subprio 適用ブランチ）として用意し，zybo QEMU で
   ビルド可能にする。まず拡張同梱の `test_subprio1` を zybo QEMU で緑にして
   **実現可能性を証明**する（最重要・最初の関門）。
2. **TESRY 追加**：`test_subprio.txt` を参考に，TTSP3 形式の TESRY を作成。
   - chg_spr 異常系：E_ID（不正tskid）/ E_PAR（subpri範囲外）/ E_OBJ（休止状態）等
   - chg_spr 正常系：同一優先度内の順序変更が ref_tsk.subpri / スケジューリングに反映
   - サブ優先度付き優先度でのディスパッチ順（優先度上昇状態の扱い含む＝3.7変更点）
   - 配置：`api_test/ASP/task_manage/chg_spr/` 等（要 TTSP_SUPPORT_SUBPRIO ガード）
3. **TTG 対応**：サブ優先度を使う静的API生成／chg_spr 呼出し生成。サブ優先度有効時のみ
   生成するよう条件分岐（既存の int_trigger_atr 追加と同様の手法）。
4. **ハーネス**：subprio カーネル変種を指すビルド構成（configure or 専用 OBJ_DIR）。
   既存の `ttsp_parallel_api.sh` を subprio 変種でも回せるようにする。
5. **CI**：subprio カーネル変種の job を追加するか判断（標準パッケージと別カーネルのため）。

**判断ゲート（着手前に要確認）**
- (G1) **公式の3.7対応TTSP3が存在しないか**（AGENTS.md・重複作業回避）。存在すれば本作業は
  不要/差し替え。
- (G2) **subprioカーネル変種をどう供給・維持するか**：標準zyboパッケージに無いため，
  ①asp3に拡張適用したツリーをCI用にどこから取得するか（exshonda git版に subprio ブランチ？），
  ②CIに subprio job を増やすか。FMP3 を exshonda/fmp3 git版にしたのと同様の整備が要る。

**規模感**：中〜大。最初の関門（subprio拡張カーネルを zybo QEMU で緑）を超えれば，
あとは TESRY authoring が主。G1/G2 の確認・決定が前提。

### スコープ外・後回し
- **POSIX(linux_gcc)固有の残**：API残7（割込み異常系・adj_tim実時間・CRE_TSK stk）、
  cfg-error残10（DEF_ICS/CRE_TSK stk）。実装不安定のため深追いしない（副次）。
- **HRMP3/HRP3**：正系API立ち上げ・ttb.shのTECSオブジェクト自動導出化・
  HRMP3 zybo+QEMUブート問題。後回し（記録のみ）。
- 任意パッケージ（monotonic/優先度継承）はカーネルpkg有効化が前提。

---

## 3. 推奨着手順

1. ~~**P1（確認系）を先に潰す**~~ … ✅ 完了（2026-06-08、3項目とも影響なし＝修正不要）。
2. ~~P1で見つかった期待値ズレを最小修正~~ … ズレなし（修正不要）。
3. 価値の高い **P2-1（サブ優先度）** を着手判断（公式TTSP3の有無確認の後）。← 次の候補
4. CIは ASP/FMP zybo matrix で緑を維持。新規テスト追加のたびに CI で確認。
