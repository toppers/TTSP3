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
#  $Id: configure.sh 54 2019-10-31 02:56:09Z fujisft-shigihara $
# 

##### 必須設定 #####

#
# OSのソースディレクトリへの相対パス
#
OS_PATH="../asp3/"
#OS_PATH="../fmp3/"
#OS_PATH="../hrp3/"
#OS_PATH="../hrmp3/"

#
# ターゲット略称の定義
#
# [改変] 2026-06-07: 環境変数 TTSP_TARGET_NAME で上書き可能にした．
# 例) TTSP_TARGET_NAME=linux_gcc bash ttb.sh ../fmp3/ FMP obj_fmp_posix
#
TARGET_NAME="${TTSP_TARGET_NAME:-zybo_z7_gcc}"

#
# プロファイル設定
# [ASP : ASP3カーネル，FMP : FMP3カーネル，HRP : HRP3カーネル，HRMP : HRMP3カーネル]
#
PROFILE_NAME="ASP"
#PROFILE_NAME="FMP"
#PROFILE_NAME="HRP"
#PROFILE_NAME="HRMP"

##### オプション設定 #####

#
# カーネルライブラリを使用するか
# [true : 使用する，false : 使用しない]
#
USE_KERNEL_LIB="false"

#
# TTGの実行モジュール(ttg.rb)へのパス
#
TTG_BIN="./tools/ttg/bin/ttg.rb"

#
# マニフェストファイルを分割する際に，平準化するか
# [true : 平準化する，false : 平準化しない]
#
AVERAGE_MANIFEST="true"

#
# マニフェストファイルの分割数
# (指定しなければ，マニフェストファイル作成時に入力可能)
# 例) DIV_NUM=2の場合，2つに分けたマニフェストファイルが作成される
#
DIV_NUM=

#
# 特定のTESRYデータを対象にAPIテストする場合のフォルダパス/ファイルパス(絶対パス)
# (指定しなければ，TTG実行時に入力可能)
#
SPEC_YAML=
