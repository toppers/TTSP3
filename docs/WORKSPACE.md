# WORKSPACE.md — ワークスペース配置とカーネル取得

> TTSP3（git）と、被テストカーネル ASP3/FMP3（SVN）の配置・取得手順。
> **カーネルは本gitリポジトリに含めない。兄弟ディレクトリに置く。**
> 管理系が非対称：**TTSP3本体=git（GitHubのみ）／カーネル asp3,fmp3=SVN**。

---

## 配置

```
<workspace>/
├── ttsp3/      ← 本git リポジトリ（git clone したもの。git-only）
├── asp3/       ← 標準ASP3（SVNチェックアウト、Release 3.7.2）
├── fmp3/       ← 標準FMP3（SVNチェックアウト）
├── hrp3/       ← 標準HRP3（SVNチェックアウト）
└── hrmp3/      ← 標準HRMP3（SVNチェックアウト）
```

※ 試すプロファイルのカーネルのみ置けばよい（ASP3だけ等）。

TTSP3 の `configure.sh` は既定で次を参照する（**変更不要**）：

```sh
OS_PATH="../asp3/"      # ASP3
#OS_PATH="../fmp3/"     # FMP3
#OS_PATH="../hrp3/"
#OS_PATH="../hrmp3/"
```

`../` 相対参照のため、**asp3/fmp3/hrp3/hrmp3 は必ず ttsp3 と同じ階層**に置くこと。

---

## セットアップ手順

```bash
# 1) 作業ディレクトリ
mkdir toppers_ws && cd toppers_ws

# 2) TTSP3（git）
git clone <ttsp3 git URL> ttsp3

# 3) 被テストカーネル（SVN）を兄弟として取得
#    URL・リビジョンは下記「版固定」に従う。試すプロファイルのみでよい。
svn checkout <ASP3 SVN URL>@<REV> asp3
# svn checkout <FMP3 SVN URL>@<REV>  fmp3
# svn checkout <HRP3 SVN URL>@<REV>  hrp3
# svn checkout <HRMP3 SVN URL>@<REV> hrmp3

# 4) （configure.sh の PROFILE_NAME / OS_PATH を対象カーネルに設定）

# 5) 確認
ls            # ttsp3  asp3  (fmp3 hrp3 hrmp3)
cat ttsp3/UPSTREAM_KERNEL.md   # 想定バージョンと一致するか
```

---

## 版固定（被テストカーネルのバージョン管理）

カーネルはSVN・別管理なので、**TTSP3側は「どの版でテストを緑にしたか」を記録**する。
`UPSTREAM_KERNEL.md` に SVNのURL・リビジョン・対応バージョンを記載し、更新時に改訂する。

| カーネル | 対応バージョン | SVNリビジョン | 備考 |
|---|---|---|---|
| ASP3 | Release 3.7.2 | （記入） | 配布物 asp3_zybo_z7_gcc-20260520 系 |
| FMP3 | （記入） | （記入） | |
| HRP3 | （記入） | （記入） | |
| HRMP3 | （記入） | （記入） | |

> CIでも同じURL・リビジョンを `svn checkout ...@<REV>` で固定取得する（再現性のため）。

---

## カーネル更新時の手順

1. `svn update`（または新リビジョンを checkout）で asp3/fmp3/hrp3/hrmp3 を更新
2. `UPSTREAM_KERNEL.md` のバージョン/リビジョンを更新
3. ビルド・テストを再実行し、差分による破綻を `DIVERGENCE_MAP.md` に記録
4. テストを緑に戻す
