# TESTSHEET_PLAN.md — APIテストシート改善の検討と ToDo

> APIテスト（TESRY）の「テストシート（*.txt）」を改善する検討の記録と作業ToDo。
> 2026-06-08 時点。別作業に切り替えるための一時保存（再開時の起点）。

---

## 0. 目的・ベース方針

API テストシートを以下へ改善する（ユーザ提示のベース案＋追加提案）：
- **フォーマットを md 化**（現行 *.txt → *.md）
- **準拠仕様バージョンを明確化＝3.7**（統合仕様書 3.7.0）
- **テストへのリンク**を張る

調査結果：`api_test/**/*.txt` シートは**どのツールにも消費されていない純ドキュメント**
（TTGの自己テスト用 .txt はヒットするが api_test のシートは別）。→ **md化は安全**。

## 1. 追加提案（採用方針）

1. **front-matter（メタ情報）**：API名／**対象プロファイル**（ASP/FMP/HRP/HRMP の◯×）／
   準拠仕様版（3.7.0）／元TESRY由来（`$Id`）／最終更新／組合せ正本／テスト実体dir／**変更履歴（`changelog`）**。
   ※プロファイル依存は実在（例：`chg_spr` は FMP/HRMP のみ。ASP/HRPはサブ優先度非搭載）。
   - **変更履歴の置き場所＝層別（確定）**：①詳細な who/when/what は **git log（正本。AGENTS.md §7）**＝
     シートに逐次コミットを写さない／②**シート単位の節目**（md化・3.7対応・WB観点追加・ケース廃止）は
     **front-matter の `changelog:` ブロック**に1イベント1行で／③仕様駆動差分(3.4→3.7)の理由は
     **DIVERGENCE_MAP** へ**リンク**（重複させない）／④ライセンス改変告知は**改変明記ヘッダ**（条件(2)）に分離
     （履歴ではない）／⑤**xlsx由来 `.xlsx.md` には書かない**（再生成で消える。意味は手書きシートの `changelog` に1行）。
   - 形式：`changelog: [ { date: YYYY-MM-DD, change: "...", ref: git | "DIVERGENCE_MAP.md" | "WHITEBOX_PLAN.md §x" } ]`。
     粒度は**節目**（コミット粒度にしない＝git二重管理回避）。`base_tesry`($Id) は由来の凍結として保持し、
     `changelog` は git 移行後から記録。`last_updated` は `changelog` 最新行の日付に一致させる。
2. **トレーサビリティ表**：各ケース → テスト実体（dir/yaml）へのリンク＋期待値（yamlの`ercd`）＋
   NGKI＋zybo現状。単なるリンクより価値大。yaml から自動生成可能。
3. **NGKIトレーサビリティ＋3.4→3.7差分注記**：エラーコード/機能のNGKIを明記し、追加/変更/削除を印示。
   DIVERGENCE_MAP へリンク（例：CRE_MTX の NGKI3682廃止→F-c削除、不正クラスID→E_ID）。
4. **削除済み/対象外ケースの明示**：廃止ケース（CRE_MTX_F-c）やプロファイル非対象（`ASP:-`）を
   消さず記録（理由＋根拠リンク）。
5. **プロファイル差異・ターゲット特性の注記**：期待値がプロファイル/ターゲットで変わるケース
   （不正クラスID E_RSATR↔E_ID、DEF_INH_c の相互作用、POSIX特性）。DIVERGENCE_MAP E へリンク。
6. **親インデックス＋整合性チェッカ**：API一覧（プロファイル×状態）＋「ケースID↔実体の欠落検出」。
7. **ライセンス・由来の保持**：元 *.txt の著作権/利用条件を継承し、md化の改変明記（条件(2)）＋`$Id`残置。

## 2. Excel管理ケースの扱い（複雑な組合せパターン）

実態：FMP の複雑パターンは **.xlsx をコミットして管理**（chg_spr/snd_dtq/rel_mpf/ext_tsk/
ref_tsk/msta_alm/wai_sem/twai_sem ＋ ASP object.xlsx）。`act_tsk.txt` のケース部は空＝設計は
Excel に委譲（因子：自PE状態×対象タスク状態×他PE状態×事後状態→期待。`F-c-X-Y-Z-W`命名）。

**方針（確定）**：Excel を「作成用」に残し、**コミット時に xlsx→md を自動生成**して md を
「セットで」コミットする（参考：https://blog.dominosoft.co.jp/entry/2024/12/20/200607）。
- 変換は **MarkItDown**（`markitdown[xlsx]`／内部pandas+openpyxl）。出力は **UTF-8 md**＝
  **文字化けしない**（CSVはExcelが既定Shift-JIS解釈で化けるため不採用）。
- PRレビューは md 差分を先に見て、必要箇所を xlsx で確認（レビュー漏れ防止）。
- 正本の位置づけ：**xlsx＝人手編集ソース／md＝自動生成の可読・diff用表現**。

## 3. 実施済み（この検討で作成・未コミット）

- **パイロット** `api_test/FMP/task_manage/act_tsk_new/`：
  - `act_tsk.md`：改善版シート（front-matter＋API仕様(3.7)＋因子凡例＋全77ケースのトレーサビリティ表
    （yamlリンク・期待値・NGKI自動生成）＋3.4→3.7差分メモ＋改変明記）。
  - `act_tsk_matrix.md`：手動整形版の組合せ表（参考。最終は自動生成へ一本化予定）。
- **自動生成ツール**（`scripts/`）：
  - `xlsx_to_md.py`：`*.xlsx`→同階層`*.xlsx.md`（空列/改行/NaN整形・UTF-8）。引数なしで api_test 全変換。
  - `git_hooks/pre-commit`：ステージ済 `api_test/**/*.xlsx` を検出→md再生成→`git add`。
  - `install_hooks.sh`：`git config core.hooksPath scripts/git_hooks`。
- **検証済**：`xlsx_to_md.py act_tsk.xlsx`→`act_tsk.xlsx.md` 生成、pre-commitフックが新規xlsxで
  md再生成＆stageすることを確認（touchのみ＝無変更ならスキップも確認）。
- **環境**：`markitdown[xlsx]` を `--user` 導入。`core.hooksPath` をこのクローンに設定済み（ローカル）。

## 4. ToDo（現在の状況）

### 決定済み（方針確定）
- [x] テストシートを md 化（純ドキュメント＝安全と確認）
- [x] 準拠仕様 3.7 明記・テストリンク・追加提案（§1）の方針確定
- [x] Excel複雑ケースは「コミット時 xlsx→md 自動生成（MarkItDown/pre-commit）」と決定
- [x] CSVは不採用（Excelで文字化け）。md に統一
- [x] パイロット act_tsk_new/ 作成、xlsx_to_md.py＋pre-commitフック作成・動作検証

### 未着手・保留（再開時のタスク）
- [ ] **方式の最終承認**：act_tsk_new の md 構成（front-matter項目・表の列・因子凡例の粒度）でよいか
- [ ] **テンプレ確定**：md シートの共通テンプレート（静的API系／FMP組合せ系の2型）
- [ ] **自動生成の仕上げ**：
  - [ ] `scripts/requirements-sheets.txt` でツール版固定（markitdown/pandas）＝出力の決定性確保
  - [ ] CI に**ドリフト検出**ステップ追加（`xlsx_to_md.py` 全変換→`git diff --exit-code`で未再生成検出）
  - [ ] act_tsk.md のマトリクス参照を自動生成 `act_tsk/act_tsk.xlsx.md` に一本化（手動 matrix.md 廃止）
  - [ ] 全 xlsx の初回一括生成（9ファイル）＋コミット
- [ ] **トレーサビリティ表の自動生成スクリプト**（yaml→ケース/期待/NGKI/リンク。act_tsk で実証済の汎用化）
- [ ] **整合性チェッカ**：シートのケースID ↔ 実体（dir/yaml）の欠落・余剰検出（CI組込）
- [ ] **親インデックス**：api_test 配下のシート一覧（プロファイル×状態）
- [ ] **段階移行**：単純API（staticAPI系）と複雑API（xlsx系）へテンプレ展開（484シート）
- [ ] **配置の決定**：パイロットの `act_tsk_new/` を最終的に `act_tsk/` 直下へ統合するか別管理か

### 留意点
- フック導入は任意（`install_hooks.sh`）＝確実性は CI ドリフト検出で担保（二段構え）
- 改変時は元 .txt の著作権・利用条件を継承し改変明記（ライセンス条件(2)）
- 484シート全手動md化は非現実的→テンプレ＋変換/生成スクリプト＋パイロット展開で進める

## 5. 再開の起点
- まず本書 §4 ToDo を確認 → パイロット `act_tsk_new/act_tsk.md` と `scripts/xlsx_to_md.py` を見る
- 方式承認後、テンプレ確定→自動生成仕上げ（requirements固定・CIドリフト検出）→段階移行
