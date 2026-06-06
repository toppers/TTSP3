# MIGRATION.md — SVN → GitHub(git) 移行（一度だけ）

> TTSP3本体の管理を **SVNからGitHub(git)へ移行**する手順。移行は一度だけ。以後SVNは使わない。
> （被テストカーネル asp3/fmp3/hrp3/hrmp3 はSVNのまま＝兄弟ディレクトリ。本移行の対象外。）

---

## 方針

- TTSP3本体は **git-only**。移行後はSVNにコミットしない／戻さない
- **外部追従先（upstream）を持たない**ため、`upstream` ブランチは作らない。gitの履歴が記録の正本
- provenance（出自）として「TTSP3 R3.1.0（TOPPERS SVN由来）」を初期コミット／タグ／`DIVERGENCE_MAP.md` に明記（ライセンス条件(2)）

---

## 手順

### 方法A：履歴を引き継ぐ（git svn）
SVNの履歴を残したい場合：

```bash
# SVN履歴をgitへ取り込む（作者対応表 authors.txt を用意すると綺麗）
git svn clone <TTSP3 SVN URL> --authors-file=authors.txt --no-metadata ttsp3
cd ttsp3
git remote add origin <GitHub URL>
git push -u origin main
```

### 方法B：現状を初期コミットにする（シンプル）
履歴を引き継がず、現行ワーキングコピー（R3.1.0＋開発途中分）を初期コミットにする：

```bash
cd ttsp3                      # 現行SVNワーキングコピー
rm -rf $(find . -type d -name .svn)   # .svn メタデータを除去
git init
# 本scaffold（AGENTS.md / START.md / docs/ / .gitignore 等）を配置
git add -A
git commit -m "chore: import TTSP3 R3.1.0 (from TOPPERS SVN); start git-only management"
git branch -M main
git tag v3.1.0
git remote add origin <GitHub URL>
git push -u origin main --tags
```

> どちらでも、初期コミットメッセージ／タグ／`DIVERGENCE_MAP.md` に「R3.1.0・SVN由来」を残すこと。

---

## SVNキーワード（`$Id$` 等）の扱い

TTSP3の各ソースには `$Id: ... $`（SVNキーワード）が含まれる。gitでは自動更新されない。

- 原則：**移行時点の値で凍結**（そのまま残す）。履歴上の出自を示す情報として有用
- 新規/改変ファイルで新たに `$Id$` を増やさない
- 表示が必要な版情報は git のタグ／`UPSTREAM_KERNEL.md`／Releases で管理する

---

## 移行後の運用（再掲）

- ブランチ：`main`（基準）＋ `feat/*`。`upstream` は作らない
- リリース：タグ / GitHub Releases（3.7対応版 `v3.2.0` 等）
- カーネル（asp3/fmp3/hrp3/hrmp3）はSVNのまま兄弟配置（`docs/WORKSPACE.md`・`UPSTREAM_KERNEL.md`）
- ライセンス：改変ファイルに改変明記、再配布形態のTOPPERS報告（条件(2)(3)）
