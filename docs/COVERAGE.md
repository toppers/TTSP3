# COVERAGE.md — カーネル非依存部のカバレッジ計測

> Phase 1「カバレッジ計測（非依存部100%目標）」の方法論と現状記録。

## 方式：QEMU TCGプラグイン（drcov）＋ objdump 行マッピング

ターゲット側の計装（gcov等）を**一切使わない**方式を採用した。

```
テストバイナリ(asp, -gビルド済み)
   │  qemu-system-arm -plugin libdrcov.so,filename=coverage.drcov
   ▼
coverage.drcov（実行された基本ブロック [start,size] の表）
   │  scripts/ttsp_coverage.py
   │    ├ arm-none-eabi-objdump -dl asp → 命令アドレス→ソース行
   │    └ drcovの区間と突き合わせ → 行カバレッジ
   ▼
asp3/kernel/ の行カバレッジ（複数バイナリは(ファイル,行)で和集合統合）
```

採用理由：
- **カーネル無改変・ビルドフラグ無変更**（禁則②と整合。テストを緑にした
  バイナリそのままで計測でき、計測が挙動を変えない）
- gcov方式はベアメタルでのランタイム実装（`__gcov_info_to_gcda`＋セミホスティング
  ダンプ）と、読取専用のasp3リンカスクリプトへの `.gcov_info` セクション追加が
  必要になり、本構成では侵襲が大きい

制約：
- **行カバレッジ（C0相当）**。分岐カバレッジ（C1）は取れない
- 分母は「コード生成された行」（objdumpの行情報基準）
- drcovは「翻訳されたTB」を記録するが、TCGではTBは初回実行直前に翻訳される
  ため実行済みとみなせる

## 使い方

```bash
# 1) 全テストをビルド（済みなら不要）
./scripts/ci_run.sh           # または ttb.sh で個別ビルド

# 2) 計測（全ビルド済みバイナリをdrcov付きで再実行→統合レポート）
./scripts/coverage_run.sh                 # サマリ
./scripts/coverage_run.sh --uncovered     # 未カバー行一覧つき

# プラグインの場所が異なる場合
DRCOV_PLUGIN=/path/to/libdrcov.so ./scripts/coverage_run.sh
```

`libdrcov.so` はQEMUソースの `contrib/plugins/` でビルドされる
（`ninja contrib/plugins/all` 等。a9gtimerパッチ済みQEMUと同じツリーでよい）。

## 計測結果スナップショット（2026-06-06, v3.2.0-rc1 相当＋CI修正後）

対象：ASP3 3.7.2 `kernel/`、全28テストバイナリ
（check_library 3 / api auto_code 20 / api scratch 5）統合。

```
TOTAL  1510/1549  97.5%
```

| ファイル | カバレッジ | 未カバー行 |
|---|---|---|
| alarm.c / cyclic.c / exception.c / mempfix.c / semaphore.c / startup.c / task_manage.c / task_refer.c / task_sync.c / time_manage.c / task.h | 100% | — |
| pridataq.c | 99.4% | 213 |
| task.c | 97.4% | 298, 395 |
| eventflag.c | 97.1% | 151, 160, 161 |
| sys_manage.c | 97.1% | 401, 402 |
| wait.c | 97.1% | 56 |
| dataqueue.c | 96.6% | 170,177,188,200,218,256 |
| wait.h | 95.0% | 111 |
| mutex.c | 94.4% | 201,203,204,207,209,232,282,283 |
| task_term.c | 94.4% | 243, 251, 252 |
| time_event.c | 93.9% | 172,197,238,239,308,309 |
| interrupt.c | 86.4% | 197,235,273,311,372,373 |

未カバー行の主な性格（100%化はテストケース追加で対応する将来課題）：
- mutex.c 201-209: 複数の天井ミューテックス保持時の優先度再計算ループ
- time_event.c: タイムイベントヒープ操作の特定形状パス
- interrupt.c: dis_int/ena_int 等の特定終端パス（等間隔4行）
- 一部はインライン展開により行情報が呼び出し元へ帰属したもの

## FMP3 の GCOV 方式（行＋分岐カバレッジ、2026-06-06 整備）

FMP3 はメンテナ管理下のため、**カーネル側にGCOV対応を実装**した
（zybo_z7_gcc ターゲット）。drcov方式と異なり**分岐カバレッジ(C1)**が取れる。

```
ENABLE_GCOV=true でビルド（--coverage -fprofile-update=atomic -fprofile-info-section）
   │  テスト終了時（マスタPEの software_term_hook）
   ▼
__gcov_info_to_gcda() が .gcov_info セクションを走査
   │  librdimon（セミホスティング）の fopen/fwrite
   ▼
ホスト側の各テストディレクトリ objs/*.gcda
   │  scripts/ttsp_gcov_report.py（arm-none-eabi-gcov --json-format で解析・統合）
   ▼
fmp3/kernel/ の行＋分岐カバレッジ
```

使い方：

```bash
./scripts/coverage_gcov_fmp.sh           # check_libraryのみ（数分）
./scripts/coverage_gcov_fmp.sh full      # APIオートコード含む（1時間超）
```

### 前提となる fmp3 側の変更（FMP3メンテナのリポジトリで管理）

現行 arm-none-eabi の libgcov はフリースタンディング構成で
`__gcov_exit`（旧ctor/dtor方式）を持たないため、方式を刷新した：

| fmp3側ファイル | 変更 |
|---|---|
| `target/zybo_z7_gcc/Makefile.target` | GCOVブランチ刷新：`GCC_TARGET=arm-eabi` 廃止、`-fprofile-update=atomic`（SMP対策）・`-fprofile-info-section` 追加、`-lrdimon` 明示、gcov用ldscript切替廃止 |
| `target/zybo_z7_gcc/zybo_z7.ld` | `.gcov_info` セクション収集（`__gcov_info_start/end`）追加 |
| `target/zybo_z7_gcc/target_kernel_impl.c` | ダンプ実装を `__gcov_info_to_gcda` 方式に書換え。weak版 `software_term_hook` をGCOV時無効化。**GCOV時はマスタPEのみQEMU終了**（他PEが先に終了させるとダンプが失われるレース対策） |
| `target/zybo_z7_gcc/zybo_z7_gcov.ld` | 廃止予定（GCOVセクションは zybo_z7.ld に統合済み） |

検証（2026-06-06）：check_library 3モジュール計装ビルドで全テスト緑、
gcda 33/31/32件出力、統合レポート出力まで確認。

### 並列実行（scripts/ttsp_parallel_api.sh）

APIオートコードの各 `auto_code_N` はマニフェスト断片・生成物とも独立のため、
TTG＋make（`-j`）とQEMU実行をグループ並列化できる（既定 P=10×make -j4）。
ttb.sh逐次実行比で**ビルド約160分→約2分**（32コア環境・GCOV計装20分割）。
`coverage_gcov_fmp.sh full` はこのドライバを使用する。

### FMP3 kernel/ カバレッジスナップショット（2026-06-06）

check_library 3 + APIオートコード20グループ統合
（auto_code_15のみ sta_alm_d レース（DIVERGENCE_MAP.md D表）で途中終了＝部分データ）：

```
行カバレッジ:   3489/3620 = 96.4%
分岐カバレッジ: 1329/1631 = 81.5% (C1)
```

100%/C1主要部の未カバーは exception.c の分岐(50%)・wait.c の分岐(58.3%)・
interrupt.c(行92.7%/分岐67.0%) などに残る。`--uncovered` で行単位の特定が可能。

## 更新手順

カーネル版数更新・テスト追加時は `./scripts/coverage_run.sh`（ASP/drcov）
または `./scripts/coverage_gcov_fmp.sh`（FMP/gcov）を再実行し、
本ファイルのスナップショットを更新する。
