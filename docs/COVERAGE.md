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

## 更新手順

カーネル版数更新・テスト追加時は `./scripts/coverage_run.sh` を再実行し、
本ファイルのスナップショットを更新する。
