# TTSP3 (TOPPERS Test Suite Package 3) — git管理 / 標準ASP3対応

TOPPERS第3世代カーネル（ASP3/FMP3/HRP3/HRMP3）のAPI/SIL適合性テストスイート TTSP3 を
**GitHub(git)のみで管理**し（従来のSVNから移行・以後SVN不使用）、**標準ASP3 最新版（3.7.2）+ zybo_z7_gcc** で動作させるためのリポジトリ。

## まず読む
- `AGENTS.md` — 規約・手順の正本（AIツール共通）
- `docs/RUNBOOK.md` — **AI実行ランブック（やりたいこと→正確なコマンド・落とし穴集）**。計測/テスト追加/simt
- `START.md` — 開発の始め方と人間/AI分担
- `docs/WORKSPACE.md` — **カーネル(asp3/fmp3/hrp3/hrmp3)は兄弟ディレクトリのSVN**。配置と取得手順
- `docs/MIGRATION.md` — **SVN→GitHub(git) 移行（一度だけ）**。以後TTSP3はgit-only
- `DIVERGENCE_MAP.md` — 仕様差分(3.4→3.7)と改変台帳
- `UPSTREAM_KERNEL.md` — 被テストカーネルの版固定

## 配置（重要）
```
<workspace>/
├── ttsp3/   ← 本リポジトリ（**git-only**。configure.sh は OS_PATH="../asp3/"）
├── asp3/    ← 標準ASP3（SVN, 3.7.2）
├── fmp3/    ← 標準FMP3（SVN）
├── hrp3/    ← 標準HRP3（SVN）
└── hrmp3/   ← 標準HRMP3（SVN）
```

## 実行（zybo_z7_gcc / QEMU）
```bash
# configure.sh: OS_PATH="../asp3/" PROFILE_NAME="ASP" TARGET_NAME="zybo_z7_gcc"
# zybo の ttsp_target.sh: USE_QEMU=true
./ttb.sh    # API / SIL / ターゲット依存チェック / Kernel Library
```

## ライセンス
本リポジトリは TTSP3（TOPPERS Test Suite Package 3）を基にする。各ソースの著作権・利用条件表示を保持し、
改変ファイルには改変した旨を明記すること（TTSP3ライセンス条件)。GitHub公開＝ソース再配布。
