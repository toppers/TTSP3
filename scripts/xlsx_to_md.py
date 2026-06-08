#!/usr/bin/env python3
#
#  xlsx_to_md.py — テストシートのExcel(.xlsx)をMarkdown(.md)へ変換する
#
#  TTSP3 では複雑なテストパターン（組合せマトリクス）を *.xlsx で管理している。
#  Excelはgitで diff/grep/レビューできないため、コミット時に同名 *.xlsx.md を
#  自動生成して「セットで」コミットする（pre-commitフック。scripts/git_hooks/）。
#  PRレビューはまず .md の差分を見て、必要箇所を .xlsx で確認する運用。
#
#  使い方:
#    python3 scripts/xlsx_to_md.py [<file.xlsx> ...]
#      引数なし: api_test 配下の全 *.xlsx を変換
#      引数あり: 指定した *.xlsx のみ変換（pre-commitフックが使用）
#  出力: <同ディレクトリ>/<name>.xlsx.md（UTF-8。Excelの誤Shift-JIS解釈と無縁）
#
#  変換は MarkItDown（markitdown[xlsx]／内部はpandas+openpyxl）を用い、
#  空列・セル内改行・NaN を決定的に正規化する。再現性のためツール版を固定すること
#  （scripts/requirements-sheets.txt 参照）。
#
import sys, glob, os
import pandas as pd

def xlsx_to_md(path: str) -> str:
    xls = pd.ExcelFile(path)
    out = []
    for sheet in xls.sheet_names:
        df = xls.parse(sheet, header=None, dtype=str).fillna('')
        # セル内改行・前後空白を正規化
        df = df.map(lambda x: ' '.join(str(x).split()) if isinstance(x, str) else x)
        # 全空の列・行を削除（マージセル由来のスペーサ）
        df = df.loc[:, (df != '').any(axis=0)]
        df = df.loc[(df != '').any(axis=1)]
        out.append(f"## {sheet}\n")
        if df.empty:
            out.append("(空シート)\n")
            continue
        w = df.shape[1]
        out.append('| ' + ' | '.join(f'C{i+1}' for i in range(w)) + ' |')
        out.append('|' + '|'.join(['---'] * w) + '|')
        for row in df.values.tolist():
            out.append('| ' + ' | '.join(c.replace('|', '\\|') for c in row) + ' |')
        out.append('')
    return '\n'.join(out) + '\n'

def convert(path: str) -> str:
    md_path = path + '.md'   # foo.xlsx -> foo.xlsx.md（派生が自明・衝突なし）
    header = (f"<!-- 自動生成: {os.path.basename(path)} を scripts/xlsx_to_md.py で変換。"
              f"直接編集しない（.xlsx を編集しコミット時に再生成される）。 -->\n\n")
    body = header + xlsx_to_md(path)
    with open(md_path, 'w', encoding='utf-8') as f:
        f.write(body)
    return md_path

def main(argv):
    targets = argv[1:]
    if not targets:
        base = os.path.join(os.path.dirname(__file__), '..', 'api_test')
        targets = glob.glob(os.path.join(base, '**', '*.xlsx'), recursive=True)
    for t in targets:
        if not t.endswith('.xlsx'):
            continue
        md = convert(t)
        print(f"generated: {md}")

if __name__ == '__main__':
    main(sys.argv)
