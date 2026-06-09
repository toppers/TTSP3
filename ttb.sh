#!/bin/bash
#
#  TTSP3
#      TOPPERS Test Suite Package 3
# 
#  Copyright (C) 2009-2012 by Center for Embedded Computing Systems
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
#  $Id: ttb.sh 55 2019-11-01 09:01:33Z fujisft-shigihara $
# 

# カレント実行チェック
chk=`dirname $0`
if [ $chk != "." ]
then
	echo "Need to execute at a directory of existing \"ttb.sh\""
	exit 1
fi

# ttspフォルダの絶対パス
TTSP_DIR=`pwd`

# TTB実行に必要なフォルダ
NECESSARY_DIR="\
api_test \
library \
scripts \
sil_test \
tools"

# TTB実行に必要なフォルダの有無をチェック
for dir in ${NECESSARY_DIR[@]}
do
	if [ ! -d $dir ]
	then
		echo "$dir is necessary directory"
		exit 1
	fi
done

# 設定ファイルの読込み
source ./scripts/common.sh
source ./configure.sh

#
# 引数による相対パス，プロファイル，ワークフォルダ指定
#
if [ $1 ]
then
	OS_PATH=$1
fi
if [ $2 ]
then
	PROFILE_NAME=$2
fi
if [ $3 ]
then
	OBJECT_DIR=$3
fi

#
# OSからTTSP3のソースディレクトリへの相対パス取得
#
TTSP_PATH=`realpath --relative-to=$OS_PATH ./`

# TTBターゲット依存設定ファイルのインクルード
source ./library/$PROFILE_NAME/target/$TARGET_NAME/ttsp_target.sh

#
# プロファイル毎の設定
#
if [ $PROFILE_NAME = "ASP" ]
then
	API_TEST_DIR="api_test/ASP"
	SIL_TEST_DIR="sil_test/ASP"
	KERNEL_COBJS_COMMON="objs/startup.o objs/task.o objs/wait.o objs/time_event.o objs/task_manage.o objs/task_refer.o objs/task_sync.o objs/task_term.o objs/taskhook.o objs/semaphore.o objs/eventflag.o objs/dataqueue.o objs/pridataq.o objs/mutex.o objs/mempfix.o objs/time_manage.o objs/cyclic.o objs/alarm.o objs/sys_manage.o objs/interrupt.o objs/exception.o"
	APPL_COBJS_COMMON="objs/out.o objs/ttsp_test_lib.o objs/log_output.o objs/vasyslog.o objs/t_perror.o objs/strerror.o"
elif [ $PROFILE_NAME = "FMP" ]
then
	API_TEST_DIR="api_test/ASP api_test/FMP"
	SIL_TEST_DIR="sil_test/FMP"
	KERNEL_COBJS_COMMON="objs/startup.o objs/task.o objs/wait.o objs/time_event.o objs/task_manage.o objs/task_refer.o objs/task_sync.o objs/task_term.o objs/taskhook.o objs/semaphore.o objs/eventflag.o objs/dataqueue.o objs/pridataq.o objs/mutex.o objs/mempfix.o objs/time_manage.o objs/cyclic.o objs/alarm.o objs/sys_manage.o objs/interrupt.o objs/exception.o objs/spin_lock.o"
	APPL_COBJS_COMMON="objs/out.o objs/ttsp_test_lib.o objs/log_output.o objs/vasyslog.o objs/t_perror.o objs/strerror.o"
elif [ $PROFILE_NAME = "HRP" ]
then
	API_TEST_DIR="api_test/ASP api_test/HRP"
	SIL_TEST_DIR="sil_test/HRP"
	KERNEL_COBJS_COMMON="objs/startup.o objs/task.o objs/wait.o objs/time_event.o objs/task_manage.o objs/task_refer.o objs/task_sync.o objs/task_term.o objs/taskhook.o objs/semaphore.o objs/eventflag.o objs/dataqueue.o objs/pridataq.o objs/mutex.o objs/mempfix.o objs/time_manage.o objs/cyclic.o objs/alarm.o objs/sys_manage.o objs/interrupt.o objs/exception.o objs/messagebuf.o objs/svc_table.o objs/domain.o objs/mem_manage.o objs/memory.o"
	APPL_COBJS_COMMON="objs/out.o objs/ttsp_test_lib.o objs/log_output.o objs/vasyslog.o objs/t_perror.o objs/strerror.o \
						objs/ttsp_mem_obj_kernel1.o objs/ttsp_mem_obj_kernel2.o objs/ttsp_mem_obj_user1.o objs/ttsp_mem_obj_user2.o \
						objs/tSerialAdapter_tecsgen.o objs/tSysLogAdapter_tecsgen.o objs/tHRPSVCPlugin_sSysLogSVCCaller_SysLog_eSysLog_tecsgen.o objs/tHRPSVCPlugin_sSerialPortSVCCaller_SerialPort1_eSerialPort_tecsgen.o objs/tHRPSVCPlugin_sSysLogSVCCaller_SysLog_eSysLog.o objs/tHRPSVCPlugin_sSerialPortSVCCaller_SerialPort1_eSerialPort.o objs/tSerialAdapter.o objs/tSysLogAdapter.o"
elif [ $PROFILE_NAME = "HRMP" ]
then
	API_TEST_DIR="api_test/ASP api_test/FMP api_test/HRP api_test/HRMP"
	SIL_TEST_DIR="sil_test/HRMP"
	KERNEL_COBJS_COMMON="objs/startup.o objs/task.o objs/wait.o objs/time_event.o objs/task_manage.o objs/task_refer.o objs/task_sync.o objs/task_term.o objs/taskhook.o objs/semaphore.o objs/eventflag.o objs/dataqueue.o objs/pridataq.o objs/mutex.o objs/mempfix.o objs/time_manage.o objs/cyclic.o objs/alarm.o objs/sys_manage.o objs/interrupt.o objs/exception.o objs/messagebuf.o objs/svc_table.o objs/domain.o objs/mem_manage.o objs/memory.o objs/spin_lock.o"
	APPL_COBJS_COMMON="objs/out.o objs/ttsp_test_lib.o objs/log_output.o objs/vasyslog.o objs/t_perror.o objs/strerror.o \
						objs/ttsp_mem_obj_kernel1.o objs/ttsp_mem_obj_kernel2.o objs/ttsp_mem_obj_user1.o objs/ttsp_mem_obj_user2.o \
						objs/ttsp_mem_obj_kernel_dummy1.o objs/ttsp_mem_obj_kernel_dummy2.o objs/ttsp_mem_obj_user_dummy1.o objs/ttsp_mem_obj_user_dummy2.o"
else
	echo "$ERR_PROFILE_INVALID ($PROFILE_NAME)"
	exit 1
fi

#
# [改変] 2026-06-09: HRP の TECSコンポーネント化 syssvc 対応（方式A）．
# HRP は syssvc が TECS化（tSysLogAdapter 等）されており，リンカスクリプトが参照する
# celltype/SVC オブジェクトは configure 生成 Makefile の
# 「APPL_COBJS := @(APPLOBJS) $(TECS_USER_COBJS) $(TECS_OUTOFDOMAIN_COBJS) ...」で自動的に
# 含まれる．そこで TTSP3 のテスト用追加オブジェクトを configure の -U（→APPLOBJS）で渡し，
# make 時に APPL_COBJS/KERNEL_COBJS を破壊的に上書きしない（common.sh で HRP を分岐）．
# これにより旧命名のハードコード（従来の APPL_COBJS_COMMON 内 TECS オブジェクト）に依存せず，
# tecsgen が生成する正しい命名の TECS オブジェクトでビルドできる．
# out.o は configure が applname.o として自動追加するため -U には含めない．
if [ $PROFILE_NAME = "HRP" ]
then
	TEST_LIB_FILE="ttsp_test_lib.o log_output.o vasyslog.o t_perror.o strerror.o ttsp_mem_obj_kernel1.o ttsp_mem_obj_kernel2.o ttsp_mem_obj_user1.o ttsp_mem_obj_user2.o ttsp_target_test.o"
fi

#
# INCLUDE対象のパス定義
#
TTSP_DIR_NAME=${TTSP_DIR##*/}
INCLUDE_DIR=`echo '\$(SRCDIR)/'$TTSP_PATH'/library/'$PROFILE_NAME'/test \$(SRCDIR)/'$TTSP_PATH'/library/'$PROFILE_NAME'/target/'$TARGET_NAME`
ARCH_DIR=`echo '\$(SRCDIR)/'$TTSP_PATH'/library/'$PROFILE_NAME'/arch'`
for dir in ${ARCH_PATH[@]}
do
	INCLUDE_DIR=`echo "$INCLUDE_DIR $ARCH_DIR/$dir"`
done

#
# configureオプション
#
CONFIG_KERNEL_LIB=`echo "-T $TARGET_NAME $CONFIG_OPT -a "`
if [ $USE_KERNEL_LIB = true ]
then
	CONFIG_TEST_PROGRAM=`echo '-T '$TARGET_NAME' -A '$APPLI_NAME' -L \$(SRCDIR)/'$TTSP_DIR_NAME'/'$KERNEL_LIB $CONFIG_OPT' -a'`
elif [ $USE_KERNEL_LIB = false ]
then
	CONFIG_TEST_PROGRAM=`echo '-T '$TARGET_NAME' -A '$APPLI_NAME $CONFIG_OPT' -a'`
else
	echo "$ERR_USE_KER_LIB_INVALID ($USE_KERNEL_LIB)"
	exit 1
fi

# TTSP3メインメニュー
ttsp_main_menu()
{
	go_main_flg=0
	go_api_test_flg=0

	check_makefile

	while true
	do
		cat<<EOS

$DOUBLE_LINE
 $MAIN_MENU
$DOUBLE_LINE
 1: $API_TEST_MENU
 2: $SIL_TEST_MENU
 c: $CHECK_LIBRARY_MENU
 k: $KERNEL_LIBRARY_MENU
 q: $EXIT_TOOL
$SINGLE_LINE
EOS
echo -n " $INPUT_NO "
		# キー読み込み
		read key
		echo ""
		# 読み込んだキーによって分岐
		case ${key} in
			1)
			 source ./scripts/api_test.sh
			 ;;
			2)
			 #source ./scripts/sil_test.sh
			 echo "Not support in TTSP3"
			 ;;
			c)
			 source ./scripts/check_library.sh
			 ;;
			k)
			 #source ./scripts/kernel_lib.sh
			 echo "Not support in TTSP3"
			 ;;
			q)
			 exit 0
			 ;;
			*)
			 echo " $key $ERR_INVALID_NO"
			 ;;
		esac
	done
	exit 0
}

# 処理開始
ttsp_main_menu
