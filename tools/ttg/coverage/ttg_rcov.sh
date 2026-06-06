#!/usr/bin/bash
BASE_DIR=`dirname $0`
ERR_CHECKER=`realpath "$BASE_DIR/../ttc/test/err_check/error_checker.rb"`

$ERR_CHECKER -c -t 0 -f
$ERR_CHECKER -c -t 2 -f
rcov $BASE_DIR/ttg_coverage.rb --charset EUC-JP -x kwalify.rb -x kwalify/ -x ttj/ -x ttc/test/ -x ttg_coverage.rb
sed '1,10s/charset=UTF-8/charset=EUC-JP/g' -i coverage/*.html
rm -f out.* ttg_exclusion_list.txt
$ERR_CHECKER -r
