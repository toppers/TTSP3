#
#  TTSP3
#      TOPPERS Test Suite Package 3
# 
#  Copyright (C) 2009-2011 by Center for Embedded Computing Systems
#              Graduate School of Information Science, Nagoya Univ., JAPAN
#  Copyright (C) 2009-2011 by Digital Craft Inc.
#  Copyright (C) 2009-2011 by NEC Communication Systems, Ltd.
#  Copyright (C) 2009-2019 by FUJI SOFT INCORPORATED
# 
#  上記著作権者は，以下の(1)～(4)の条件を満たす場合に限り，本ソフトウェ
#  ア（本ソフトウェアを改変したものを含む．以下同じ）を使用・複製・改
#  変・再配布（以下，利用と呼ぶ）することを無償で許諾する．
#  (1) 本ソフトウェアをソースコードの形で利用する場合には，上記の著作
#      権表示，この利用条件および下記の無保証規定が，そのままの形でソー
#      スコード中に含まれていること．
#  (2) 本ソフトウェアを，ライブラリ形式など，他のソフトウェア開発に使
#      用できる形で再配布する場合には，再配布に伴うドキュメント（利用
#      者マニュアルなど）に，上記の著作権表示，この利用条件および下記
#      の無保証規定を掲載すること．
#  (3) 本ソフトウェアを，機器に組み込むなど，他のソフトウェア開発に使
#      用できない形で再配布する場合には，次のいずれかの条件を満たすこ
#      と．
#    (a) 再配布に伴うドキュメント（利用者マニュアルなど）に，上記の著
#        作権表示，この利用条件および下記の無保証規定を掲載すること．
#    (b) 再配布の形態を，別に定める方法によって，TOPPERSプロジェクトに
#        報告すること．
#  (4) 本ソフトウェアの利用により直接的または間接的に生じるいかなる損
#      害からも，上記著作権者およびTOPPERSプロジェクトを免責すること．
#      また，本ソフトウェアのユーザまたはエンドユーザからのいかなる理
#      由に基づく請求からも，上記著作権者およびTOPPERSプロジェクトを
#      免責すること．
# 
#  本ソフトウェアは，無保証で提供されているものである．上記著作権者お
#  よびTOPPERSプロジェクトは，本ソフトウェアに関して，特定の使用目的
#  に対する適合性も含めて，いかなる保証も行わない．また，本ソフトウェ
#  アの利用により直接的または間接的に生じたいかなる損害に関しても，そ
#  の責任を負わない．
# 
#  $Id: ttsp_target.sh 61 2019-12-20 01:17:45Z fujisft-shigihara $
# 

#
# 実機(ZYBOボード) or QEMU
#
USE_QEMU=true
#USE_QEMU=false

#
# アプリケーション名
#
APPLI_NAME="out"

#
# アーキテクチャフォルダ(ttsp/library/ASP(FMP)/arch配下の使用するフォルダ)の定義
# (必要な場合のみ)
# (複数指定可能，複数指定する場合はスペースで区切る)
#  例) "arm_gcc/mpcore arm_gcc/common"
#
ARCH_PATH=

#
# プロセッサ数(FMPカーネルのみ使用)
#
PROCESSOR_NUM=2

#
# ターゲット依存APIの有無
# [true: 有り，false: 無し]
#
FUNC_TIME="true"		# システム時刻制御関数
FUNC_INTERRUPT="true"	# 割込み発生関数
FUNC_EXCEPTION="true"	# CPU例外発生関数

#
# IRCアーキテクチャ(FMPカーネルのみ使用)
# [local: ローカルIRCのみサポート，global: グローバルIRCのみサポート，
#   combination: ローカルIRC，グローバルIRC両方サポート]
#
IRC_ARCH="combination"

#
# TTGへの追加オプション
# (-a，-f，-c，--prc_num，--timer_arch，--out_file_name，--func_time，
#  --func_interrupt，--func_exception, --irc_archは使用不可，詳細はttsp/user.txtを参照)
#
TTG_OPT=

#
# コンフィギュレータへの追加オプション(必要な場合のみ)
# (-T, -A, -U, -a, -LはTTSP3で使用するため使用不可)
# (コーテーションを含むオプションは指定不可(例:"-d \"dir1 dir2\""))
#
# [改変] 2026-06-08: HRMP3 3.4.0対応．serial.c から設定データが
#  syssvc/serial_cfg.c に分離されたため -S serial_cfg.o を追加（ASP/FMPと同根）．
CONFIG_OPT="-w -S syslog.o -S banner.o -S serial.o -S serial_cfg.o -S chip_serial.o -S logtask.o -S xuartps.o -o -Wno-unused-but-set-variable -o -DOMIT_CHECK_USTACK_OVERLAP"
if [ "$USE_QEMU" == "true" ]
then
	CONFIG_OPT="$CONFIG_OPT -o -DTOPPERS_USE_QEMU"
fi

#
# ターゲット依存部でKERNEL_COBJSへ追加するオブジェクトファイル
#
# [改変] 2026-06-08: HRMP3 3.4.0対応．3.7で廃止された arm.c 由来の objs/arm.o を削除
#  （ASP/FMPと同根．arm.c は arm.h に統合済み）．
KERNEL_COBJS_TARGET="objs/chip_kernel_impl.o objs/core_kernel_impl.o objs/gic_kernel_impl.o objs/pl310.o objs/target_kernel_impl.o objs/mpcore_kernel_impl.o objs/mpcore_timer.o"
APPL_COBJS_TARGET="objs/ttsp_target_test.o"

#
# make depend / make の追加オプション(必要な場合のみ)
# (コーテーションを含むオプションは指定不可(例:"-d \"dir1 dir2\""))
#
# [改変] 2026-06-09: 環境変数 TTSP_MAKE_OPT で上書き可能にした（ASP/FMP と同様）．
# 例) TTSP_MAKE_OPT="ENABLE_GCOV=true" でGCOV計装ビルド（hrmp3側の
# Makefile.target/target_kernel_impl.c/arch/gcc/ldscript.trb の対応版が必要）
MAKE_OPT="${TTSP_MAKE_OPT:-}"

#
# 実行モジュールの実行をシェルスクリプトで実装済みか
# [true : 実装済み，false : 実装していない]
# (trueの場合，ttb.shの"e: Run executable module (Target Dependent)"を
#  選択すると，以下の関数simulation()が実行される)
#
EXC_MODULE="true"

#
# 実行モジュールの実行(ターゲット依存)
# (EXC_MODULEがtrueの場合に実行される)
#
simulation()
{
	LOGFILE=`pwd`"/execute.log"

	if [ "$USE_QEMU" == "true" ]
	then
		qemu-system-arm -M xilinx-zynq-a9 -semihosting -m 512M -serial null -serial mon:stdio -nographic -smp 2 -kernel hrmp | tee $LOGFILE
	else
		TEMPFILE=`pwd`"/temp"

		cp -pf $TTSP_DIR/library/FMP/target/zybo_gcc/*.tcl .

		# 有効なCOMポートを探す
		cnt=1
		while [ $cnt -le 10 ]
		do
			stty -F /dev/ttyS$cnt 115200 start undef stop undef cs8 &> /dev/null
			if [ $? -eq 0 ]
			then
				break
			fi
			cnt=`expr $cnt + 1`
		done
		# COM10まで探してなければエラー終了
		if [ $cnt -eq 11 ]
		then
			echo "Not found a valid COM port from COM1 to COM10."
			echo "Check mode bit for /dev/ttyS*."
			echo "ex: 'sudo chmod 666 /dev/ttyS5' if you use COM5."
			exit
		fi

		SHELL_NAME=`pwd`"/com_port.sh"
		echo '#!/bin/bash' > $SHELL_NAME
		echo "cat /dev/ttyS$cnt | tee $TEMPFILE" >> $SHELL_NAME

		cmd.exe /C start wsl sh $SHELL_NAME

		cp -p hrmp hrmp.elf
		cmd.exe /C c:\\Xilinx\\SDK\\2017.2\\bin\\xsct.bat -interactive ./jtag.tcl ./ps7_init.tcl ./hrmp.elf 

		# 1秒おきにログファイルのサイズをチェックし変化がなければ終了する
		pre_size=`ls -l $TEMPFILE | awk -F ' ' '{print $5}'`
		cur_size=0
		while [ $pre_size -ne $cur_size ]
		do
			pre_size=$cur_size
			sleep 1
			cur_size=`ls -l $TEMPFILE | awk -F ' ' '{print $5}'`
		done

		proc=`ps ax|grep "com_port\.sh"|awk -F ' ' '{print $1}'`
		kill -9 $proc
		grep -v "^$" $TEMPFILE > $LOGFILE

		cat $LOGFILE
	fi
}
