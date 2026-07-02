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

## 実ワークスペースの地図（付加ディレクトリの見分け方）

開発機では上記 canonical 名（`fmp3` 等）の他に**比較・追従用の別版**が並ぶことが多い。
**どれが正本かは「symlink がどこを指すか」で判断する**（`configure.sh` が見るのは symlink 名）。

| 規則 | 意味 | 例 | 触ってよいか |
|---|---|---|---|
| `<kernel>`（版なし名） | canonical への **symlink**。configure.sh はこれを参照 | `fmp3 -> fmp3_3.4` | 実体（下記）を編集 |
| `<kernel>_<版>`（symlink先の実体） | **正本**（被テストカーネル本体・SVN） | `fmp3_3.4` | ユーザ指示時のみ（禁則②）。SVN別管理 |
| `<kernel>_old` | 古いスナップショット（baseline 参照） | `fmp3_3.4_old`（r384） | 読み取り専用・比較用 |
| `<kernel>_git` | git 版スナップショット（比較・退行前 baseline） | `fmp3_git`（r479＝暫定修正版） | 読み取り専用・比較用 |
| `<kernel>_trunk` | 上流 trunk の最新（追従元） | `hrmp3_trunk`（r1249＝POSIX修正入り） | 読み取り専用・追従元 |
| `<kernel>_stepN` / 外部symlink | 別作業ツリーへのリンク | `hrp3_step5 -> …/HRP3/work/…` | 読み取り専用 |

> 現状スナップショット（2026-06-13・開発機）：`asp3->asp3_3.7`(SVN) / `fmp3->fmp3_3.4`(SVN・正本)
> ＋`fmp3_3.4_old`(r384)・`fmp3_git`(r479) / `hrmp3->hrmp3_3.4`(SVN)＋`hrmp3_trunk`(r1249最新) /
> `hrp3->hrp3_3.4`(SVN)＋`hrp3_step5`(外部) / `ttsp3`(git・正本)。構成は変わり得るので
> **着手前に `ls -l ../` で symlink 先を必ず確認**する。

### TTSP3 リポジトリ外の関連物（兄弟階層／別管理）
- `posix/posix_<N>/` … POSIX依存部の不具合の**自己完結 再現＋修正案パッケージ**
  （`fmp3_orig`/`fmp3_fixed` 全ソース＋スタンドアロン再現テスト＋`run_all.sh`）。
  番号は HRMP3 trac チケット由来（例 `posix_50`=#50）。**TTSP3 git には含めない**。

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

---

## 第2ワークスペース（M-profile 系・`~/TOPPERS/ttsp3`）

本リポジトリの git clone は**2つ**存在し、役割を分担している。

| ワークスペース | パス | 担当 |
|---|---|---|
| 本ワークスペース（A-profile 系） | `~/TOPPERS/TTSP3/work/ttsp3` | zybo_z7_gcc（Cortex-A9 / QEMU）を正とする A-profile 系計測。兄弟に SVN カーネル（asp3/fmp3/hrp3/hrmp3） |
| 第2ワークスペース（M-profile 系） | `~/TOPPERS/ttsp3` | mps2_an505_gcc（Cortex-M33 / QEMU）・ek_ra8m2_gcc（Cortex-M85 / 実機）の M-profile 系計測 |

両者は同一 origin を共有する（`git remote -v` で確認可）。ブランチ・コミット履歴は共通であり、ターゲット依存部（`library/*/target/*`）の変更は一方でコミットすれば他方に反映される。

### 第2ワークスペースのディレクトリ構成

```
~/TOPPERS/
├── ttsp3/                          ← 第2ワークスペース（git clone。本リポジトリ）
└── ASP3_TZ/
    └── asp3_tz_work/               ← M-profile 系カーネル群（本ワークスペースの兄弟 SVN とは別管理）
        ├── asp3_3.7/               ← ASP3 3.7 系（mps2_an505 per-case 測定では無改変で使用）
        └── hrp3_3.4.2/             ← HRP3 3.4.2 系（EK-RA8M2 向け M-profile 修正を含む）
            └── (overlay: cw_hrp3_ra8m2)  ← rundom 設定・拡張SVC rundom 退避/復元・within_ustack 等
```

`configure.sh` の `OS_PATH` は第2ワークスペースでは兄弟ではなく `../ASP3_TZ/asp3_tz_work/<kernel>/` を指す。
ビルドコマンドの例（第2ワークスペースで実行）：

```bash
cd ~/TOPPERS/ttsp3
export TTSP_TARGET_NAME=mps2_an505_gcc
bash ttb.sh ../ASP3_TZ/asp3_tz_work/asp3_3.7 ASP obj_mps2_an505
```

### 各カーネルの状態とターゲット

| カーネル | 改変状態 | 使用ターゲット | 結果台帳 |
|---|---|---|---|
| `asp3_3.7` | **無改変**（本ワークスペースの ASP3 3.7.2 と同系） | mps2_an505_gcc（ASP / QEMU）、ek_ra8m2_gcc（ASP / 実機・SIL） | `library/ASP/target/mps2_an505_gcc/MPS2_API_STATUS.md` |
| `hrp3_3.4.2`（+overlay `cw_hrp3_ra8m2`） | **M-profile 向け修正あり**（rundom 設定・拡張SVC rundom 退避/復元・within_ustack 実装・svc nPRIV 分岐等） | mps2_an505_gcc（HRP / QEMU）、ek_ra8m2_gcc（HRP / 実機） | `library/HRP/target/mps2_an505_gcc/MPS2_API_STATUS.md`、`docs/HRP/EK_RA8M2_TTSP3_STATUS.md` |

### 計測環境

- `mps2_an505_gcc`：QEMU `qemu-system-arm -M mps2-an505 -semihosting-config enable=on`（a9gtimer パッチ不要）
- `ek_ra8m2_gcc`：実機（J-Link OB・VCOM /dev/ttyACM0・115200 bps）。**本ワークスペース単独では測定不可**（第2ワークスペース＋実機接続が必要）

M-profile 系の測定結果概要は `docs/STATUS.md` §1b を参照。
