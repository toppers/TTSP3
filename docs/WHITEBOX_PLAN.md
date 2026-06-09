# WHITEBOX_PLAN.md — ASP APIテストのホワイトボックステスト開発プラン

> 現状のAPIテストは仕様ベースのブラックボックス（TESRY）。カバレッジ（特に分岐）を
> 上げるため、カーネル内部構造に基づくホワイトボックステストを開発する。まず **ASP3** が対象。
> 2026-06-08 検討。基準ターゲット zybo_z7_gcc（QEMU）。
>
> **方針決定（2026-06-08）**：計測は **gcov（C1分岐）ベース**（drcov近似は不採用）／
> テスト形式は **方式1（既存TESRY拡張 `<api>_W-*`）**／**C1の固定目標値は設けない**
> （未到達分岐を可視化して潰す・到達不能は正当化文書化）／**ASPから着手**
> （FMPはタイミング依存パスが多く決定的駆動が難しいため後段）。詳細は §11。
>
> **進捗（2026-06-08）**：**P0 完了＝ASP に gcov(C1) 計測基盤導入済み**（FMP方式を移植）。
> 分岐C1ベースライン取得可能。最初の題材として ena_ter を精査した結果は §12（worked example）。
> **FMP gcov(C1) ベースライン取得済み（2026-06-09）**：93.9%（1575/1677）。-DNDEBUG 適用，
> coverage_gcov_fmp.sh を bb|all モード対応に整備。分析は docs/FMP/WB_COVERAGE.md・WB_UNREACHABLE.md。
> **HRMP3/HRP3 アクセス許可仕様移行後（2026-06-09）**：HRMP 91.3%/82.1%、HRP 89.4%/81.7%。
> TTG CPUState.rb sysstat2 追加 + ter_tsk TESRY（HRP 44件／HRMP 80件）access2↔access3 入替、
> さらに spinlock TESRY（HRMP 5ファイル×5ケース CPU_STATE1 access 追加）で E_OACV を解消。
> （移行前: HRMP 75.4%/63.7%、HRP 79.6%/69.8%）。
> 詳細 docs/HRMP/COVERAGE_STATUS.md・docs/HRP/WB_COVERAGE.md・docs/HRP/TESRY_MIGRATION.md。
> → **4プロファイル最新値：ASP 98.3% / FMP 93.9% / HRMP 91.3% / HRP 89.4%**（line）。

---

## 0. 目的・スコープ
- 対象：ASP3 `kernel/`（カーネル非依存部）の API テスト。
- 目標：行(C0)に加え **分岐(C1)カバレッジ**を引き上げる（到達不能コードは正当化して文書化）。
- 非対象：ターゲット依存部（target/）、SIL/Kernel Library（TTSP3未サポート）。

## 1. 現状ベースライン（2026-06-06 計測）
- ASP3 `kernel/`：**行 C0 = 97.5%（1510/1549）**。計測は drcov（QEMU TCGプラグイン）＝
  カーネル無改変・非侵襲（docs/COVERAGE.md）。
  ~~分岐 C1 は未計測~~ → **P0完了（2026-06-08）：ASPに gcov(C1) 導入済み**。分岐C1の計測が可能になった
  （drcovはC0トレンド把握に併用）。最初の精査例 ena_ter は §12。
- 低カバレッジ順（行）：interrupt.c 86.4% ＜ time_event.c 93.9% ＜ task_term.c/mutex.c 94.4%
  ＜ dataqueue.c 96.6% ＜ …（残り未カバーは約39行）。
- 参考：FMP は gcov で **行96.9%／分岐93.9%**（-DNDEBUG 適用，2026-06-09 計測）。
  旧参照値（NDEBUG無し）は 行96.4%/分岐81.5%。詳細は docs/FMP/WB_COVERAGE.md。
  **ホワイトボックスの主戦場は「行は通るが片アームしか通らない分岐」**
  （FMP残存102分岐のうち約35分岐がマルチコア遅延ディスパッチ等FMP固有）。

## 2. 本プロジェクトでのホワイトボックスの定義（重要な制約）
- **禁則②：カーネルは読取専用**。よって「内部関数を直接呼ぶ／内部にテストフックを挿す」古典的
  ユニット型ホワイトボックスは不可。
- 採る形：**カバレッジ誘導テスト（グレーボックス）**。ホワイトボックス知識（未到達の分岐・パス）で
  「どの内部状態に入れば通るか」を特定し、**外部から API列・静的cfg・割込み/例外注入・
  ターゲット依存フック**でその内部状態を作って駆動する。
- 実行機構は既存ハーネス（TTG生成＋QEMU）のまま。判定は execute.log のチェックポイント。

## 3. カバレッジ基準
1. **C0（行）**：現状97.5%。到達可能行を着実に詰める（到達不能は正当化）。
2. **C1（分岐）**：本プランの主目標。各 if/while/for/switch・短絡(&&/||)の両アームを網羅。
   **固定の達成率目標(%)は設けない**（Q3）。未到達分岐を可視化して着実に潰し、
   到達不能は正当化文書化する、という運用。
3. （任意・将来）**MC/DC**：複合条件（例 mutex.c の優先度判定、time_event.c のヒープ条件）で
   条件独立性まで。コスト大のため重要関数に限定。

## 4. 前提：分岐(C1)計測基盤の整備＝gcov（案A・確定）
ホワイトボックスは「未到達分岐の可視化」が出発点。現状 drcov は C0 のみ → **gcov で分岐C1を計測する**。
- **ASP に gcov を導入（FMPで実績の方式）**：`-fprofile-arcs -ftest-coverage`（`-b`相当）で
  kernel/ を計装、ベアメタル gcov ランタイム（`__gcov_info_to_gcda`＋セミホスティングダンプ）、
  リンカに `.gcov_info` セクション追加。FMP は実装済
  （scripts/coverage_gcov_fmp.sh / scripts/ttsp_gcov_report.py が雛形）。
- **計測専用ビルドとして分離**：テスト緑判定は無計装ビルド、カバレッジは計装ビルドで別途
  （禁則②と整合）。
- **ASP特有の課題（P0で具体化）**：ASPは標準パッケージ（メンテナ＝外部）。リンカへの
  `.gcov_info` 追加等は、ASP3に ENABLE_GCOV 相当の仕組みがあるか確認し、無ければ
  **TTSP3側の計測専用ビルド構成（最小オーバーレイ／ビルドフラグ）**で実現する。
  FMPのgcov資産（coverage_gcov_fmp.sh等）を参照して移植。
- drcov（案B近似）は**不採用**（真のC1が要るため）。既存のdrcov(C0)はトレンド把握に併用可。

## 5. 開発フロー（反復・1関数/1ファイル単位）

> **ツール**: `scripts/wb_branch_report.py` — gcov集計＋未到達分岐レポートを1コマンドで出力。
> 計測データは事前に `bash scripts/coverage_gcov_asp.sh full` で取得しておくこと。

**手順:**

1. **未到達分岐の確認**（1コマンド）：
   ```bash
   # ソース全体の未到達一覧
   python3 scripts/wb_branch_report.py <source>
   # 例: task_sync.c の未到達分岐一覧
   python3 scripts/wb_branch_report.py task_sync

   # 関数単位の全分岐カウント（行範囲指定）
   python3 scripts/wb_branch_report.py task_sync --lines 203-248
   ```
   出力：`L<行>  br[N]  <ソース行>`（未到達）、`【0】` マーク付き（全分岐）、`◀` 印。

2. **未到達分岐の分類**：
   - (i) API到達可：既存APIの引数/前提条件の組合せで通る → テストケース追加で対応。
   - (ii) 特殊内部状態要：待ち行列の特定順序・優先度境界・キューイング上限・割込み多重等 →
     API列＋cfg＋割込み注入で状態を構築。
   - (iii) 到達不能/防御コード：assert・「起こり得ない」分岐・ターゲット依存で固定の枝 →
     **正当化して文書化**（無理に通さない）。

3. **テスト設計・追加**：
   - `(i)(ii)` → §6.1 の YAML（`<api>_W-<letter>.yaml`）を作成、§6.2 の形式で `.txt` に追記。
   - `(iii)` → §8 到達不能リストに `file:line` ＋正当化を記録。

4. **再計測→反復**：`coverage_gcov_asp.sh full` → `wb_branch_report.py` で残存確認。

**利用可能ソース一覧:**
```bash
python3 scripts/wb_branch_report.py --list
```

## 6. テストの形式・置き場所（決定）
- **方式1：既存TESRYの拡張**。各APIシートにホワイトボックスケースを追加し TTG で生成。
  既存ハーネスにそのまま乗る。命名は下記 §6.1。
- **方式2：ホワイトボックス専用テスト群**（`api_test/ASP/whitebox/<area>/...`）。仕様トレースから独立に
  「この分岐を通す」目的のテストを集約。可読性高いが TTG/集約スクリプトの対応要。
- 推奨：**方式1を基本**（既存資産・CI流用）。複数APIにまたがる内部状態系、および
  **戻らないsyscall経路**（自タスク終了・割込み移行。§12参照）は方式2寄り。
- 各ホワイトボックスケースは「狙う分岐（file:line/方向）」を §6.1 のメタに明記（トレーサビリティ）。

> **当面の方式（2026-06-08 決定）**：シートの **md化（TESTSHEET_PLAN.md）を待たず、現状の `.txt` シートを
> 更新してホワイトボックスを進める**。すなわち各 API の既存 `<api>.txt` に節「2. 構造ベースのホワイトボックス
> テスト」を追記し（§6.2）、対応する `<api>_W-<letter>.yaml`（§6.1）を作成する。`.txt` には front-matter が
> 無いため、変更履歴は **git（正本）** に依る（後日 md 移行時に §6.2 の節ごと移行し changelog ノード化）。

### 6.1 ホワイトボックスyamlの命名規則（2026-06-08 確定）

既存TESRYの文法を壊さず、**case クラスとして大文字 `W` を予約**する。
**`W` は各プロファイルの既存 case 文法に差し込む**（プロファイル固有の family プレフィックスは尊重する）。

実地調査で判明した4プロファイルの既存case文法（2026-06-08 全数確認）：

| プロファイル | 既存case文法 | 普遍プレフィックス | literal `W` |
|---|---|---|---|
| ASP | 小文字連番 `a,b,c…`（`ena_ter_a-2.yaml`） | なし | 未使用 |
| HRP | 小文字 a–l ＋ `H-`（HRP固有・保護ドメイン）。接尾辞 `_H_ex`(1277/1487=86%) | **なし**（混在） | 未使用 |
| FMP | **全 case に `F-`**（2722件・例外なし。`act_tsk_F-c-1-1.yaml`） | `F-` | 未使用 |
| HRMP | `F-`(2182/2218) ＋ `R-`(34)。接尾辞 `_HM_ex`(98%) | `F-` | 未使用 |

**統一規則：マーカ `W`（大文字）を「クラスプレフィックス」として、プロファイルの普遍プレフィックスの直後に差し込む。
`W-` の後ろは既存と同じ `<観点レター a,b,c…>[-<変種番号>]` を続ける（観点レターは `a` から開始）。**

合成文法： **`[F-][W-]<観点レター>[-<変種番号…>]`**
- 観点レター（a,b,c…）＝**狙う未到達分岐**（1分岐＝1観点）。既存の「レター＝観点」意味論を踏襲。
- 変種番号（-1,-2…）＝同じ分岐を通す別セットアップ。
- `W` は `F-` と同列のクラスプレフィックス（テスト種別）。ゆえにFMP/HRMPでは `F-W-` と重畳。

| プロファイル | ファイル名 | 内部キー（`-`→`_`） |
|---|---|---|
| ASP | `<api>_W-<letter>[-<n>].yaml` | `ASP_<category>_<api>_W_<letter>[_<n>]` |
| HRP | `<api>_W-<letter>[-<n>].yaml`（保護ドメイン分岐狙いは `<api>_H-W-<letter>` で `H-` 群に寄せ可） | `HRP_<category>_<api>_W_<letter>` |
| FMP | `<api>_F-W-<letter>[-<n>].yaml` | `FMP_<category>_<api>_F_W_<letter>` |
| HRMP | `<api>_F-W-<letter>[-<n>].yaml` | `HRMP_<category>_<api>_F_W_<letter>` |
| 方式2配置（共通） | `api_test/<PROFILE>/whitebox/<area>/<scenario>_W-<letter>.yaml` | — |

例：ASP `ena_ter_W-a.yaml`→`ASP_task_term_ena_ter_W_a`（観点a＝raster分岐）／同分岐の別セットアップは `W-a-1`/`W-a-2`／
FMP `act_tsk_F-W-a.yaml`→`FMP_task_manage_act_tsk_F_W_a`。

**`W`（大文字）採用の根拠**：①既存連番レターは小文字 a–z・FMP/HRMPは数値因子＝**全4プロファイルで衝突しない**（literal `W` 未使用を全数確認）／
②**1つのgrepで全プロファイル抽出可**＝`grep -rE '[-_]W-' api_test`（ASP/HRPの `_W-` とFMP/HRMPの `-W-` を両取り）。
CIの「ホワイトボックスN件」レポート用／③`-`→`_` 後 `W_a` は valid な C 識別子で **TTG無改変**で生成可／
④同一APIディレクトリに置けば方式1でそのまま生成・実行される。

**接尾辞 `_H_ex`/`_HM_ex` は普遍でない**（86%/98%）ため、ホワイトボックスでは**既定で付けない**。
保護/拡張コードの分岐を狙うケースのみ、整合のため同型接尾辞を付す。

**FMP/HRMP固有の留意**：PE割当（`prcid: PRC_SELF/PRC_OTHER`）・クラス（クラス囲み）・他PE状態を
pre_condition に明記する必要がある（分岐が**クロスPE状態依存**のため）。`_ntc`/`_ten` の末尾修飾も
必要なら継承可。**FMP/HRMP/HRP のホワイトボックスは後段**（§10/§11 Q4：タイミング依存・保護ドメインで
決定的な状態構築が難しい。HRP/HRMPは全体方針で後回し）＝**命名規則のみ先に確定**し、実装はASPで方法論確立後。
計測基盤(gcov)はFMP側が先行実装済（移植元）。

**トレーサビリティの格納**：新フィールドは TTG スキーマを壊す恐れがあるため、
**先頭 `#` コメント＋ `note:`**（TTGが確実に読む）に集約する。新規ケースゆえ `$Id` は付さない。
```yaml
#  white-box: kernel/task_term.c:251-252  branch "if(raster && dspflg)" TRUE-arm
#  category : (i) API到達可   route: dis_ter -> ras_ter(self) -> ena_ter
#  kernel   : ASP3 3.7.2 (asp3_zybo_z7_gcc-20260520)   # file:line はこの版に対するもの
version: "white-box ena_ter_W-a (TTSP3 wb)"
ASP_task_term_ena_ter_W_a:
  note: 【NGKI3478】【NGKI3491】 [WB] task_term.c:251 true-arm / 遅延終了 / kernel ASP3 3.7.2
  pre_condition: ...
  do: ...
```

**境界**：(iii)到達不能（防御コード）は yaml を作らず §8 到達不能リストに file:line＋正当化を記録
（例 `ena_ter:253 E_SYS`）。

#### 6.1.1 pre_condition 頻出パターン集（コピー用・ASP向け）

> WBテスト設計で繰り返し使う `pre_condition` キー群。実値はAPIと狙う分岐に合わせて調整する。

**パターン① CPUロック状態**（CHECK_UNL / E_CTX 経路）
```yaml
pre_condition:
  TASK1:
    type   : TASK
    tskstat: running
  TASK2:
    type   : TASK
    tskstat: ready
  CPU_STATE:
    type   : CPU_STATE
    loc_cpu: true
do:
  id     : TASK1
  syscall: <api>(TASK2)   # または自タスク対象なら TSK_SELF
  ercd   : E_CTX
```

**パターン② 非タスクコンテキスト**（CHECK_TSKCTX / TSK_SELF in non-task / E_CTX or E_ID 経路）
```yaml
pre_condition:
  DUMMY_ALM:
    type     : ALARM
    nfytype  : TNFY_HANDLER
    nfy_info1: EXINF_A
    almstat  : TALM_STP
    hdlstat  : ACTIVATE   # アラームハンドラを起動状態にして API を呼ばせる
  TASK1:
    type   : TASK
    tskstat: running
do:
  id     : DUMMY_ALM
  syscall: <api>(TSK_SELF)   # または適切な引数
  ercd   : E_CTX             # または E_ID（TSK_SELF が有効範囲外の場合）
```

**パターン③ ディスパッチ保留状態**（CHECK_DISPATCH / !dspflg 経路）
```yaml
pre_condition:
  TASK1:
    type   : TASK
    tskstat: running
  CPU_STATE:
    type   : CPU_STATE
    dis_dsp: true      # dis_dsp()によるディスパッチ禁止
do:
  id     : TASK1
  syscall: <api>()
  ercd   : E_CTX
```

**パターン④ タスク終了要求フラグ（raster=T）+ タスク終了禁止**（ras_ter/ena_ter 関連分岐）
```yaml
pre_condition:
  TASK1:
    type   : TASK
    tskstat: running
    dister : true      # dis_ter() 済み（タスク終了要求を保留させる）
    raster : true      # ras_ter() 済み（終了要求フラグ）
```

**パターン⑤ 起床要求キューイング数（wupcnt=N）**（slp_tsk の NGKI1259/1260 切替・wup_tsk の E_QOVR 手前）
```yaml
pre_condition:
  TASK1:
    type   : TASK
    tskstat: running
    wupcnt : 1         # 0 または 1（TMAX_WUPCNT=1）
```

**パターン⑥ 待ち状態タスク各種**（sus_tsk・wup_tsk の状態分岐）
```yaml
pre_condition:
  TASK2:
    type   : TASK
    tskstat: wait-slp    # 起床待ち（slp_tsk 呼出し中）
    # または:
    # tskstat: wait-dly  # 時間経過待ち（dly_tsk）
    # tskstat: wait-sem  # セマフォ資源獲得待ち
    # tskstat: sus       # 強制待ち（sus_tsk）
    # tskstat: was       # 二重待ち（強制待ち + 起床待ち）
```

> **使い方**：`wb_branch_report.py task_sync --lines <行範囲>` で未到達分岐を確認し、
> 該当する CHECK_* の種類からパターンを選んでコピー。`CPU_STATE` / `DUMMY_ALM` は TTG が
> 認識する特殊タイプ（`type:` フィールドが必須）。

### 6.2 `.txt` シートへのホワイトボックス節の追記ルール（当面の方式・2026-06-08 確定）

既存 `<api>.txt` は「`0. API仕様` → `1. 仕様ベースのブラックボックステスト`（1.1 エラー/1.2 正常、
ケース `(a)(b)…`）→ `以上．`」の構成。区切りは `■`（節）/`━`（小節）。ここに **新節 `2.`** を追記する。

**ルール**：
1. `以上．` の**直前**に新節 `2. 構造ベースのホワイトボックステスト` を挿入（既存の `■`/`━` 罫線様式を踏襲）。
2. ケース記号は **`(W-a)(W-b)…`**（§6.1。観点レターは `a` から、変種は `(W-a-1)`）。
3. **各ケースに必須5項目**を書く：`対象カーネル版` ／ `狙う分岐(file:line/方向)` ／ `到達手順(API列)`
   ／ `分類(i/ii/iii)` ／ `関連NGKIとyamlファイル名`。
4. 仕様(NGKI)から導けない構造起点である旨を節冒頭に明記（ブラックボックスと区別）。
5. **(iii)到達不能**はシートに書かず §8 到達不能リストへ（理由＋正当化）。
6. 各ケースに対応する **`<api>_W-<letter>.yaml` を必ず作成**（.txtは文書、yamlが実行を駆動）。
7. 変更履歴は **git**（`.txt`にfront-matter無し）。コミットは `test(api): add white-box case <api>_W-a (...)`。

**対象カーネル版を必ず書く理由**：ホワイトボックスは `file:line`・分岐構造という**版依存**の情報を狙う。
版が上がると行番号・分岐がずれ、ケースが陳腐化し得る。版を記録すれば「現行カーネル版 ≠ ケースの対象版」を
検知し**再検証（行番号・分岐の確認）を促せる**。版の正本は **UPSTREAM_KERNEL.md の固定版**（現状
**ASP3 3.7.2 / `asp3_zybo_z7_gcc-20260520`**）＝gcovベースライン（docs/ASP/ALL_COVERAGE.md）と同一版を記す。
全ケース共通なら節ヘッダに既定版を1回書き、版違いのケースのみ `対象カーネル版` を上書きしてよい。

**追記テンプレ**（ena_ter の例。実値は対象に合わせる）：
```text
■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
2. 構造ベースのホワイトボックステスト
■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■

  本節は仕様(NGKI)からは導かれない，カーネル実装の未到達分岐(C1)を狙う
  ケースを記す（gcov計測ベース．docs/WHITEBOX_PLAN.md）．
  対象カーネル版（既定）: ASP3 Release 3.7.2（UPSTREAM_KERNEL.md 固定版
  asp3_zybo_z7_gcc-20260520）．file:line は本版に対するもの．

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
2.1. 未到達分岐のテストケース
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
(W-a) 終了禁止中に終了要求された自タスクが，ena_terで終了許可した瞬間に
      自タスク終了する経路を通すこと．
      ・対象ｶｰﾈﾙ : ASP3 3.7.2 (asp3_zybo_z7_gcc-20260520)  ※既定版と同じなら省略可
      ・狙う分岐 : kernel/task_term.c:250  if (p_runtsk->raster && dspflg) の TRUE側
      ・到達手順 : dis_ter() → 別タスクが ras_ter(自タスク) → raster=true → ena_ter()
      ・分類     : (i) API到達可
      ・関連NGKI : 【NGKI3478】【NGKI3491】
      ・yaml     : ena_ter_W-a.yaml （内部キー ASP_task_term_ena_ter_W_a）
```

## 7. 優先順位（低カバレッジ・効果順）
1. interrupt.c（86.4%・最低）— dis_int/ena_int/clr_int/ras_int/prb_int の状態分岐。
2. time_event.c（93.9%）— タイムイベントヒープの挿入/削除/再構成の条件分岐。
3. mutex.c（94.4%）— 優先度上限/継承の複合条件（MC/DC候補）。
4. task_term.c（94.4%）— 終了・raster・例外経路。
5. dataqueue.c / wait.c / eventflag.c / sys_manage.c / pridataq.c — 残分岐。
- まず **interrupt.c で 1ファイル・パイロット**（分岐C1計測→未到達分類→テスト追加→再計測）。

## 8. CIでのカバレッジ提示（閾値ゲートは設けない）
- **C1の固定閾値ゲートは設定しない**（Q3決定）。CIは分岐C1の**レポート/トレンドを提示**し、
  低下の気付きに使う（pass/failは閾値で判定しない）。
- 計装ビルドは「カバレッジjob」を別に（テスト緑判定の無計装ビルドと分離）。
- 到達不能（防御/assert/ターゲット固定枝）は正当化リストで管理し、レポートで除外表示。

## 9. リスク・留意
- **カーネル無改変原則**：計装は「計測専用ビルド」と明確化。テスト判定は無計装で実施。
  リンカスクリプト等のASP側対応はメンテナ調整（FMPで実績）。
- **到達不能コードの扱い**：防御的/assert/ターゲット固定枝は正当化文書化。100%を強制しない。
- **タイミング依存・割込み**：内部状態の構築に割込み/例外注入やcfgが要る分岐は、
  ターゲット依存フック（ttsp_int_raise/cpuexc_raise）と組合せ。
- **公式TTSP3の有無**：3.7対応公式は無し（重複作業の心配なし）。ホワイトボックステストの追加は本リポジトリで。

## 10. 段階計画（ASP先行・gcovベース）
- P0：**ASP に gcov(C1) 計測基盤を導入**（FMP資産を移植）→ ASP分岐ベースライン取得。**【完了 2026-06-08】**
       **FMP gcov(C1) ベースライン取得・docs/FMP/ 作成。【完了 2026-06-09】**
       （coverage_gcov_fmp.sh を bb|all モード・NDEBUG 対応に整備，1575/1677=93.9%，
       docs/FMP/WB_COVERAGE.md・WB_UNREACHABLE.md 102分岐分析）
- P0'：**HRMP3/HRP3 gcov(C1) 計測も完了【2026-06-09】**。当初の前提ブロッカー
       （GCOV計装未移植・HRP3 が TTSP3 で未緑）を解消：HRP3 は方式A（APPL/KERNEL_COBJS
       非上書き・configure -U でテスト追加）で bring-up を解決し、保護カーネル向け GCOV計装
       （生成リンカスクリプトへ `.gcov_info` 追加、特権ダンプ、`target_ldscript.trb` 方式で
       `arch/gcc/ldscript.trb` は無変更）を HRMP3→HRP3（単一コア）へ移植。
       **HRMP3 75.4%／HRP3 79.6%**（line）。詳細 docs/HRMP/・docs/HRP/（COVERAGE_STATUS / WB_COVERAGE / WB_UNREACHABLE）。
       → **HRP3/HRMP3 アクセス許可仕様移行（2026-06-09）**：TTG CPUState.rb sysstat2 追加
       ＋ ter_tsk TESRY（HRP 44件／HRMP 80件）access2↔access3 入替で E_OACV 早期終了を解消。
       さらに spinlock TESRY（HRMP 5ファイル×5ケース CPU_STATE1 access 追加）で spinlock
       E_OACV も解消（15/17 runnable グループ All check points passed）。
       **HRMP3 91.3%/82.1%、HRP3 89.4%/81.7%**（残ギャップは domain/mem_manage と
       dis_int 競合・alarm SMP タイミング）。
- P1：interrupt.c パイロット（未到達分岐→誘導テスト追加→C1向上を実測で実証）。
- P2：time_event.c / mutex.c / task_term.c へ展開。
- P3：残ファイル＋CIへの**分岐C1レポート提示**（閾値ゲートなし）＋到達不能の正当化文書化。
- 各段階で zybo QEMU 緑を維持し、CI（ASP/FMP matrix）で確認。
- FMPはタイミング依存パスが多く決定的駆動が難しいため**後段**（ASPで方法論確立後に判断）。

## 11. 決定事項（2026-06-08 確定）
- **(Q1) 分岐計測＝gcov（案A）に確定**。drcov近似（案B）は採らない。
  ASP に gcov（分岐C1）を導入する（FMP実績の方式：`-fprofile-arcs -ftest-coverage` 計装＋
  ベアメタル gcov ランタイム＋リンカに `.gcov_info`）。**計測専用ビルド**として分離し、
  テスト緑判定は無計装ビルドで行う（禁則②と整合）。
  ※ASP は標準パッケージ（メンテナ＝外部）。リンカ等の対応は「TTSP3側の計測専用ビルド構成
    （overlay/ビルドフラグ）」で実現する方針を P0 で具体化（ASP3にENABLE_GCOV相当の
    仕組みがあるか確認→無ければ計測ビルド用の最小オーバーレイ）。
- **(Q2) テスト形式＝方式1（既存TESRY拡張）に確定**。ホワイトボックスケースは `<api>_W-*` 等で識別し
  既存ハーネス（TTG＋QEMU）で生成・実行。複数API横断の内部状態系のみ例外的に方式2。
- **(Q3) C1目標値は設定しない**。固定の閾値ゲートは設けない。方針は「未到達分岐を可視化し、
  誘導テストで着実に潰す。到達不能（防御/assert/ターゲット固定枝）は正当化して文書化」。
  CIは閾値で落とすのではなく**分岐C1のトレンド/レポートを提示**（低下の気付き用）。
- **(Q4) ASP から着手（FMP先行はしない）**。理由：**FMPはタイミング依存のパスが多く**
  内部状態の決定的な構築が難しい（マルチコア遅延ディスパッチパス等，102残存分岐のうち約35分岐が
  FMP固有のマルチコアパス — docs/FMP/WB_UNREACHABLE.md §1-2 参照）。
  ASP（単一プロセッサ・タイミング依存が少ない）で方法論を確立し、必要に応じ後段でFMPへ展開。
  FMP gcov(C1) ベースラインは 2026-06-09 取得済み（docs/FMP/）。

---

## 12. Worked example：ena_ter（2026-06-08 精査）

P0完了後の最初の題材として `task_term.c` の `ena_ter` を分析。**drcov 0% 報告は誤りで、gcov では 90%**
（生成 auto_code_11/12/13、a-1/a-2/b が Start→OK、バイナリに `ena_ter` シンボル在）。

### 既存3ケースのカバー範囲
| ケース | 文脈 | 期待 | カバーするアーム |
|---|---|---|---|
| a-1 | アラームハンドラ（非タスク文脈） | E_CTX | `CHECK_TSKCTX`（NGKI3488） |
| a-2 | CPUロック状態 | E_CTX | `CHECK_…UNL`（NGKI3489） |
| b  | 通常 | E_OK | **else アーム**（`enater=true`, NGKI3491） |

### 未到達分岐（残り10%）＝ `if (p_runtsk->raster && dspflg)` の true アーム
| 行 | コード | 分類 | 対応 |
|---|---|---|---|
| 251-252 | `task_terminate(p_runtsk); exit_and_dispatch();` | **(i) API到達可** | 下記手順のホワイトボックステストで潰せる |
| 253 | `ercd = E_SYS;` | **(iii) 到達不能（防御）** | `exit_and_dispatch()` は戻らない→**正当化文書化**（無理に通さない） |

**251-252 を踏む手順（遅延終了経路）**：
1. TASK1 が `dis_ter()` → `enater=false`（NGKI3486）
2. 別タスクが `ras_ter(TASK1)`（標準API, kernel.h:226）→ enater偽なので即終了せず **`raster=true`** に保留（NGKI3478）
3. TASK1 が `ena_ter()` → `raster && dspflg` 真 → **自タスク終了**（task_terminate→exit_and_dispatch, 戻らない）

### 方法論上の知見（重要・ホワイトボックス全体に効く）
- **戻らない syscall 経路は方式1（TESRY `do: syscall→eruint`）で表現できない**。
  ena_ter のこの分岐は自タスク終了で**制御が呼出元へ戻らない**ため、戻り値（eruint）検査の枠組みに乗らない。
  同種：自タスク終了（ext_tsk/exd_tsk相当の遅延発火）、割込み/例外で制御が移る分岐。
  → これらは **方式2寄りの設計**（ena_ter後の行が実行されないこと＋main側で対象タスクがDORMANT化したことを
  別チェックポイントで検証）が必要。§6「複数API横断・内部状態系は方式2」の具体例として登録。
- **到達不能の防御コード（exit_and_dispatch直後の `ercd=E_SYS` 等）は (iii) として正当化文書化**する運用を
  ena_ter で初適用。今後 §8 の「到達不能リスト」に同型を蓄積する。

### ena_ter のステータス
- (i) 251-252：ホワイトボックステスト化候補（`ena_ter_W-a`、方式2寄り）。**本セッションでは未実装**（計画記録のみ）。
- (iii) 253：到達不能・正当化済み（本節）。
