#!/bin/bash
#configure文件自动生成器

if [ "$(uname)" = "Darwin" ];then
	SED_CMD="gsed"
else
	SED_CMD="sed"
fi

#帮助文件
proj_help(){
	echo "Usage: makeconfig [options...][operate]"
	echo "Options:"
	echo -e "-o <file>\tPlace the output into <file>"
	echo -e "-v <value>\tSpecify software version <value>"
	echo -e "-l <library>\tlibraries to pass to the linker, e.g. -l<library>"
	echo -e "-I <include dir>\t C preprocessor flags: include dir, e.g. -I<include dir>"
	echo -e "-D <value>\t Define a MACRO, e.g. -DDEBUG=true"
	echo -e "-F <value>\t linker flags, e.g. -export-dynamic -lmemcached"
	echo "operate:"
	echo -e "clean\tClean all generated files"
	echo -e "<file>\tSpecify a file name,replace -o <file>"
}

#执行清理
clean_all(){
	if [[ -n "$1" ]];then
		rm -rf stamp-h1 autoscan.log aclocal.m4 autom4te.cache >/dev/null
	else
		make clean >/dev/null 2>&1
		rm -rf stamp-h1 *.o *.Po .deps .DS_Store config.* autoscan.log Makefile* configure* aclocal.m4 autom4te.cache >/dev/null
		rm -f compile depcomp install-sh missing >/dev/null

		for curdir in `ls | tr "\n" " "`;do
			if [[ -d "$curdir" ]];then
				rm -rf $curdir/Makefile* $curdir/.deps $curdir/.DS_Store
			fi
		done
	fi
}

#获取程序名称
get_proj_name(){
	tmp_contents=""
	for cur_file in `ls *.c* 2>/dev/null` ;do
		tmp_contents=$(grep "^\s*int\s\s*main\s*(.*)" $cur_file 2>/dev/null)
		if [[ -z "$tmp_contents" ]];then
			tmp_contents=$(grep "^\s*void\s\s*main\s*(.*)" $cur_file 2>/dev/null)
		fi
		if [[ -z "$tmp_contents" ]];then
			tmp_contents=$(grep "^\s*main\s*(.*)" $cur_file 2>/dev/null)
		fi
		if [[ -n "$tmp_contents" ]];then
			echo ${cur_file%.c*}
			break
		fi
	done
	unset tmp_contents
}

#获取项目子目录
get_sub_dirs(){
	tmp_file_ext="*.c*"
	if [[ -n "$*" ]];then
		tmp_file_ext=$*
	fi
	for curdir in `ls | tr "\n" " "`;do
		if [[ -d "$curdir" ]];then
			filenames=$(ls $curdir/$tmp_file_ext 2>/dev/null | tr "\n" " ")
			if [[ -n "$filenames" ]];then
				echo $curdir
			fi
		fi
	done
	unset tmp_file_ext
}

#生成configure.ac文件
make_configure_ac(){
	sub_makefile=""
	for curdir in `get_sub_dirs`;do
		sub_makefile="${sub_makefile} ${curdir}\/Makefile"
	done
	$SED_CMD -i "s/\[FULL-PACKAGE-NAME\]/${proj_name%.*}/g" configure.scan
	$SED_CMD -i "s/\[VERSION\]/${proj_version}/g" configure.scan
	$SED_CMD -i "s/\[BUG-REPORT-ADDRESS\]/${author_email}/g" configure.scan
	$SED_CMD -i "s/AC_CONFIG_SRCDIR/AM_INIT_AUTOMAKE(${proj_name%.*}, ${proj_version})\nAC_PROG_RANLIB\nAC_CONFIG_SRCDIR/g" configure.scan
	if [[ $proj_type = "shared" ]];then
		$SED_CMD -i "s/AC_OUTPUT/AC_PROG_LIBTOOL\nAC_CONFIG_FILES([Makefile${sub_makefile}])\nAC_OUTPUT/g" configure.scan
	else
		$SED_CMD -i "s/AC_OUTPUT/AC_CONFIG_FILES([Makefile${sub_makefile}])\nAC_OUTPUT/g" configure.scan
	fi
	mv configure.scan configure.ac
}

#生成Makefile.am文件
make_makefile_am(){
	tmp_proj_source=$(ls *.c* 2>/dev/null | tr "\n" " ")
	tmp_proj_head=$(ls *.h* include/*.h* 2>/dev/null | tr "\n" " ")

	subdirs=""
	sublibs=""
	tmp_sub_head=""
	ctmp_sub_head=""
	#在各个子目录下生成Makefile.am文件
	for cursrcdir in `get_sub_dirs`;do
		sourcefiles=$(ls $cursrcdir/*.c* 2>/dev/null | tr "\n" " ")
		subdirs="${subdirs} ${cursrcdir}"
		sublibs="${sublibs} ${cursrcdir}/lib${cursrcdir}.a"
		echo "noinst_LIBRARIES=lib${cursrcdir}.a" > $cursrcdir/Makefile.am
		echo "lib${cursrcdir}_a_SOURCES=${sourcefiles//$cursrcdir\/}" >> $cursrcdir/Makefile.am

		if [[ -n "$external_cppflags" ]];then
			echo "lib${cursrcdir}_a_CPPFLAGS=${external_cppflags}" >> $cursrcdir/Makefile.am
		fi

		tmp_sub_head=$(ls include/${cursrcdir}/*.h* 2>/dev/null | tr "\n" " ")
		ctmp_sub_head=$(ls ${cursrcdir}/*.h* 2>/dev/null | tr "\n" " ")
		if [[ -n "${tmp_sub_head}" ]];then
			tmp_sub_head=${tmp_sub_head//include\//../include/}
		fi
		if [[ -n "${ctmp_sub_head}" ]];then
			ctmp_sub_head=${ctmp_sub_head//${cursrcdir}\//}
		fi
		echo "${cursrcdir}includedir=\$(includedir)/${cursrcdir}" >> $cursrcdir/Makefile.am
		echo "${cursrcdir}include_HEADERS=${tmp_sub_head} ${ctmp_sub_head}" >> $cursrcdir/Makefile.am
	done
	unset tmp_sub_head
	unset ctmp_sub_head

	#在顶层目录生成Makefile.am文件
	echo "AUTOMAKE_OPTIONS=foreign" > Makefile.am
	if [[ -n "$subdirs" ]];then
		echo "SUBDIRS=${subdirs}" >> Makefile.am
	fi

	if [[ $proj_type = "shared" ]];then
		echo "lib_PROGRAMS=${1}" >> Makefile.am
	else
		echo "bin_PROGRAMS=${1}" >> Makefile.am
	fi

	echo "${1//./_}_SOURCES=${tmp_proj_source}" >> Makefile.am
	if [[ -n "$external_incs" ]];then
		echo "INCLUDES = ${external_incs}" >> Makefile.am
	fi
	if [[ -n "$sublibs" ]];then
		echo "${1//./_}_LDADD=${sublibs}" >> Makefile.am
	fi
	
	if [[ -n "$external_cppflags" ]];then
		echo "${1//./_}_CPPFLAGS=${external_cppflags}" >> Makefile.am
	fi
	if [[ -n "$external_ldflags" ]];then
		echo "${1//./_}_LDFLAGS=${external_ldflags}" >> Makefile.am
	fi

	if [[ -n "${tmp_proj_head}" ]];then
		echo "include_HEADERS=${tmp_proj_head}" >> Makefile.am
	fi
	if [[ -n "${external_libs}" ]];then
		echo "LIBS=${external_libs}" >> Makefile.am
	fi
	unset tmp_proj_source
	unset tmp_proj_head
}

#生成configure文件
make_configure(){
	#如果项目名称为空，则退出
	if [[ -z "${proj_name}" ]];then
		echo "Error: File name must be verified! "
		proj_help
		exit
	fi

	#生成configure.scan
	autoscan

	#生成configure.ac
	make_configure_ac

	#创建 Makefile.am
	make_makefile_am "$proj_name"

	#生成aclocal.m4
	aclocal

	#生成动态库
	if [[ $proj_type = "shared" ]];then
		libtoolize -f -c
	fi

	#生成 configure
	autoconf	

	#生成 config.h.in
	autoheader

	#生成Makefile.in
	automake --add-missing >/dev/null 2>&1
}

#初始化变量
proj_name=$(get_proj_name)
proj_version="1.0.0"
proj_type="bin"
author_email="spring.wind2006@163.com"
external_libs=""
external_incs=""
external_ldflags=""
external_cppflags=""

#自动获取参数
main_params=$*
while getopts ":o:l:shv:D:F:I:" temp_opt
do
    case $temp_opt in
	    o )
			proj_name=$OPTARG
			main_params=${main_params/-o*$OPTARG/}
	    ;;
	    s )
			proj_type="shared"
			main_params=${main_params/-s/}
		;;
	    l )
			external_libs="${external_libs} -l ${OPTARG}"
			main_params=${main_params/-l*$OPTARG/}
		;;
		v )
			proj_version=$OPTARG
			main_params=${main_params/-v*$OPTARG/}
		;;
		D )
			external_cppflags="${external_cppflags} -D${OPTARG}"
			main_params=${main_params/-D*$OPTARG/}
		;;
		F )
			external_ldflags="${external_ldflags} ${OPTARG}"
			main_params=${main_params/-F*$OPTARG/}
		;;
		I )
			external_incs="${external_incs} -I${OPTARG}"
			main_params=${main_params/-I*$OPTARG/}
		;;
		h )
			proj_help
			exit
		;;
	esac
done

main_params="${main_params// /}"
#直接生成文件支持，例如：makeconfig spring
if [[ -n "$main_params" ]];then
	proj_name=$main_params
fi
if [[ $proj_type = "shared" ]];then
	external_ldflags="${external_ldflags} –fPIC –shared"
	if [[ -n "${proj_name}" ]];then
		echo "Tips: you are making a shared library..."
		proj_name="lib${proj_name}.so"
	fi
fi

#处理主程序
case $main_params in
	clean )
		clean_all
	;;
	*)
		#清理文件
		echo "Clean up the generated file......finished!"
		clean_all
		echo "Generate \"configure\" file......please wait!"
		#生成configure文件
		make_configure
		if [[ "$?" = "-1" ]];then
			echo "failed! please check you code!"
		else
			echo "Success! you can run \"./configure && make\" to build!"
		fi
		#清理中间文件
		clean_all other
	;;
esac

