# GLOSSARY.md — TTSP3 用語集（AI向け）

> TTSP3 で頻出する用語を1ページに集約。再学習コストを下げるための索引。
> 詳細は各文書（`AGENTS.md`／`STATUS.md`／`TARGETS.md`／`DIVERGENCE_MAP.md`）へ。

## 全体・構成

| 用語 | 意味 |
|---|---|
| **TTSP3** | TOPPERS Test Suite Package 3。第3世代カーネルの API/SIL 適合性検証スイート（本リポジトリ） |
| **TTG** | TOPPERS Test Generator。テストデータ（TESRY）からテストプログラム（`out.c`/`out.cfg`）を生成 |
| **TESRY** | テストデータ（テスト仕様の元データ。YAML 等）。TTG の入力 |
| **profile** | カーネル種別＝ **ASP / FMP / HRP / HRMP**（ASP=単一,FMP=マルチ,HRP=保護,HRMP=保護+マルチ） |
| **target（ターゲット依存部）** | `library/<PROFILE>/target/<tgt>/` の4ファイル。能力は `TARGETS.md` |
| **被テストカーネル** | `asp3/fmp3/hrp3/hrmp3`（兄弟SVN・別管理。`WORKSPACE.md`） |

## テストの種類・段階

| 用語 | 意味 |
|---|---|
| **check_library（ターゲット依存チェック）** | `exception`/`interrupt`/`timer` の3種。ターゲット依存部の動作確認（ttb.sh の `c` メニュー） |
| **API テスト（オートコード）** | TESRY→TTG 自動生成の API 適合テスト。`auto_code` 群で実行 |
| **auto_code N分割（DIV）** | API テスト群を N（既定20）に分割して並列ビルド・実行する単位。`auto_code_1..20` |
| **per-case（1ケース=1 ELF）** | DIV=総ケース数で API テストを**1ケースごとに個別ビルド・実行**する方式。バンドル（20分割）起因のスケジューリング/CP アーティファクトを排除して真の合否を測る。M-profile（mps2_an505）の全件測定で使用（`docs/STATUS.md` §1b・各 `MPS2_API_STATUS.md`） |
| **scratch code** | 手書きの少数テスト（ASP の CI 4段目）。`scratch_code/<name>` |
| **cfg-error（コンフィグエラーテスト）** | 静的API/設定の異常系。期待エラーが出るかを検査（`ttsp_parallel_cfgerr.sh`） |
| **SIL テスト / Kernel Library** | TTSP3 R3.1.0 では**未サポート**（`AGENTS.md` §4） |

## カバレッジ・テスト方式

| 用語 | 意味 |
|---|---|
| **BB テスト（方式1）** | TESRY/YAML から自動生成するブラックボックステスト（`api_test/`） |
| **WB テスト（方式2）** | 手書きのホワイトボックステスト（`wb_test/`）。BB で到達できない分岐用 |
| **bb / all / smoke** | gcov 計測モード。bb=BBのみ／all=BB+WB／smoke=check_libraryのみ（`coverage_gcov_<prof>.sh`） |
| **C0 / C1** | gcov の 行カバレッジ(C0) / 分岐カバレッジ(C1) |
| **residual（既知残）** | 退行ではない既知の未達/失敗。判定時に除外してよい（正本は `STATUS.md` §3） |
| **simt** | シミュレーションタイマ（`arch/simtimer`）。64bit時刻等の分岐到達に使う（ASPで実績） |

## 実行・判定（スクリプト）

| 用語 | 意味 |
|---|---|
| **ttb.sh** | 公式の対話メニューランナー。**非対話の名前付きコマンド**も持つ（第4引数 `--check-all`/`--check-exc`/`--check-int`/`--check-timer`/`--scratch`）。自動化は下記スクリプト経由が推奨 |
| **`ci_run.sh <PROFILE>`** | 全プロファイル統一の非対話ランナー（check→API→scratch(ASP)→cfg-error→VERDICT） |
| **`ttsp_parallel_api.sh`** | API auto_code をグループ並列でビルド・実行 |
| **`verdict.sh`** | 実行結果を `STATUS.md` のベースラインと比較し正規化 `VERDICT:` 行を出す |
| **`run_one.sh`** | 1テスト（を含む群）だけ build→実行（反復デバッグ用） |
| **finish=（parallel_api 出力）** | 群が "All check points passed" に到達したか（1=到達/0=未到達）。緑数＝finish=1 の数 |
| **RESULT** | ランナーの**厳密合否**（既知の build失敗も FAIL に数える） |
| **VERDICT** | **退行判定**＝緑数が STATUS ベースライン以上か（HRMP は 14/20 でも `OK(baseline)`） |
| **合否の根拠** | `execute.log` の `All check points passed.`／チェックポイント（「通るはず」で報告しない＝`AGENTS.md` §4） |

## ターゲット能力（詳細は `TARGETS.md`）

| 用語 | 意味 |
|---|---|
| **USE_QEMU** | QEMU 実行か（zybo系=true）。`false`＝実機/別 |
| **native 実行** | linux_gcc は QEMU 不要で `./fmp` 直接実行（~30秒） |
| **FUNC_TIME** | 時刻制御関数の有無。`false`（linux_gcc）＝時刻停止不可・timer/adj_tim は対象外/実時間依存 |
| **IRC** | 割込みコントローラ方式：local / global / combination。linux_gcc=global（割込み番号異常系が一部不一致） |
| **a9gtimer パッチ** | zybo(Cortex-A9) QEMU で timer check を通すための QEMU パッチ（`docs/patches/`）。未適用だと timer 必失敗 |

## 管理・差分

| 用語 | 意味 |
|---|---|
| **DIVERGENCE_MAP** | 統合仕様 3.4→3.7 の差分・改変台帳（`DIVERGENCE_MAP.md`） |
| **改変明記** | TTSP3/カーネルのライセンス条件(2)。改変ファイルに改変の旨を記載（禁則③） |
| **禁則①②③** | ①カーネルを本gitにコミットしない ②カーネルをテスト都合で編集しない ③ライセンス表記を壊さない（`AGENTS.md` §2） |
