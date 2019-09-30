#!/bin/bash

GSED="sed"
if [ $(uname) == "Darwin" ];then
    GSED="gsed"
fi


#帮助文件
show_help(){
    echo "Usage: makefile [options...][name]"
    echo "Options:"
    echo -e "-o <name>\tspecify the output file name as <name>"
    echo -e "-c <name>\tspecify the make config file, default: Makefile"
    echo -e "-v <value>\tSpecify software version <value>"
    echo -e "-t <value>\tSpecify the build type, whether c or cpp  project, default: c"
    echo -e "-l <library>\tlibraries to pass to the linker, e.g. -l<library>"
    echo -e "-I <dirname>\tC preprocessor flags: include dir, e.g. -I<dirname>"
    echo -e "-C <value>\tCompile flags, e.g. -C -DDEBUG=true -C -std=gnu99"
    echo -e "-F <value>\tLinker flags, e.g. -export-dynamic -lmemcached"
    echo -e "-f <file>\tLocate the entry file if make a executable file"
    echo -e "-i <dirnames>\tIgnore dirnames separated by Spaces, default: test"
    echo -e "          \te.g. -i \"demo test/show\""
    echo -e "-s \tMake a share library file, make a executable file instead if ignore"
    echo -e "-h \tShow help information"
    echo -e "name: Specify the output file name, instead of -o <name>"
}

#去除首位空格，并将中间多个空格替换为1个空格
trim_space(){
    echo $@ | $GSED -e 's/^[ \t]*//g' -e 's/[ \t]*$//g' | $GSED -e 's/[ \t]+/ /g'
}


#初始化变量
proj_name=""
proj_version="1.0.0"
proj_type="bin"
proj_file=""
build_type="c"
ignore_dirs="test"

external_incs=""
external_libs=""
external_ldflags=""
external_cppflags=""

makefile_name="Makefile"
author_email="spring.wind2006@163.com"
#自动获取参数
main_params="${*} "
while getopts ":o:t:c:l:L:shv:C:F:I:f:i:" temp_opt
do
    case $temp_opt in
        o )
            proj_name=$OPTARG
            main_params=${main_params/-o*$OPTARG / }
        ;;
        t )
            if [ "$OPTARG" == "cpp" ];then
                build_type="cpp"
            fi
            main_params=${main_params/-t*$OPTARG / }
        ;;
        c )
            makefile_name=$OPTARG
            main_params=${main_params/-c*$OPTARG / }
        ;;
        s )
            proj_type="lib"
            main_params=${main_params/-s / }
        ;;
        l )
            external_libs="${external_libs} -l${OPTARG}"
            main_params=${main_params/-l*$OPTARG / }
        ;;
        L )
            external_libs="${external_libs} -L${OPTARG}"
            main_params=${main_params/-L*$OPTARG / }
        ;;
        v )
            proj_version=$OPTARG
            main_params=${main_params/-v*$OPTARG / }
        ;;
        C )
            external_cppflags="${external_cppflags} ${OPTARG}"
            main_params=${main_params/-D*$OPTARG / }
        ;;
        F )
            external_ldflags="${external_ldflags} ${OPTARG}"
            main_params=${main_params/-F*$OPTARG / }
        ;;
        f )
            proj_file=${OPTARG#./}
            main_params=${main_params/-f*$OPTARG / }
        ;;
        i )
            ignore_dirs=$OPTARG
            main_params=${main_params/-i*$OPTARG / }
        ;;
        I )
            external_incs="${external_incs} -I${OPTARG}"
            main_params=${main_params/-I*$OPTARG / }
        ;;
        h )
            show_help
            exit
        ;;
    esac
done

main_params="${main_params// /}"
#直接生成文件支持，例如：makeconfig spring
if [[ -n "$main_params" ]];then
    proj_name=${main_params/-*/}
fi

#处理主程序
srcfiles=""
targetfiles=""
in_targetfiles=0
ignore_paths=""

#设置需要忽略的文件
if [ -n "$ignore_dirs" ];then
    for cdiarname in $ignore_dirs;do
        ignore_paths="${ignore_paths} -o -path ./${cdiarname#./}"
    done
fi

#扫描源代码文件
tmp_contents=""
for cur_file in `find . \( -path ./.\* $ignore_paths \) -prune -o -type f -name "*.${build_type}" -print`; do
    tmp_contents=$(grep "^\s*int\s\s*main\s*(.*)" $cur_file 2>/dev/null)
    if [[ -z "$tmp_contents" ]];then
        tmp_contents=$(grep "^\s*void\s\s*main\s*(.*)" $cur_file 2>/dev/null)
    fi
    if [[ -z "$tmp_contents" ]];then
        tmp_contents=$(grep "^\s*main\s*(.*)" $cur_file 2>/dev/null)
    fi
    if [[ -n "$tmp_contents" ]];then
        targetfiles="${targetfiles} ${cur_file#./}"
        if [ "${cur_file#./}" =  "$proj_file" ];then
            in_targetfiles=1
        fi
    else
        srcfiles="${srcfiles} ${cur_file#./}"
    fi
done
unset tmp_contents

#生成通配符表示的路径
tmpsrcs=""
for i in $srcfiles; do
    OLD_IFS="$IFS"
    IFS="/"
    arrs=($i)
    tmpsrc=${arrs[0]}
    unset arrs[0]
    for s in ${arrs[@]}; do
        tmpsrc="${tmpsrc}|*" 
    done
    IFS="$OLD_IFS"
    if [[ -z "$tmpsrcs" ]]; then
        tmpsrcs="${tmpsrc}.${build_type}"
    fi

    hastmpsrc="no"
    for m in $tmpsrcs; do
        if [[ $m = "${tmpsrc}.${build_type}" ]]; then
            hastmpsrc="yes"
        fi
    done
    if [[ $hastmpsrc = "no" ]]; then
        tmpsrcs="${tmpsrcs} ${tmpsrc}.${build_type}"
    fi
done
srcfiles="${tmpsrcs//|//}"


#如果编译为可执行文件
target_name=$proj_name
if [ $proj_type = "bin" ];then
    #找不到入口函数则退出
    if [ -z "$targetfiles" ];then
        echo "Error: No entry function main for ${build_type} project!"
        exit
    fi
    #将项目的主文件文件添加进目录中
    targetfiles=($targetfiles)
    if [ $in_targetfiles -eq 0 ];then
        proj_file=${targetfiles[0]}
    fi
    srcfiles="${srcfiles} ${proj_file}"

    if [ -z "$proj_name" ];then
        proj_name=$(basename ${proj_file%.cpp})
        proj_name=$(basename ${proj_name%.c})
    fi
    target_name=$proj_name
else
    #编译为库文件
    if [[ -z "$srcfiles" ]]; then
        srcfiles=$targetfiles
    fi
    if [ -n "$proj_name" ];then
        echo "Tips: you are making a shared library..."
    else
        echo "Error! you should specify a lib name!"
        exit
    fi
fi

############生成Makefile文件#########
echo "SOURCES=\$(wildcard $srcfiles)" > $makefile_name
echo "PROJECT_NAME=${target_name}" >> $makefile_name
echo "TARGET_DIR=release" >> $makefile_name
#编译工具
if [ $build_type == "cpp" ];then
    echo "CC=g++" >> $makefile_name
else
    echo "CC=gcc" >> $makefile_name
fi
#静态库打包工具
echo "ifeq (\$(shell uname),Darwin)" >> $makefile_name
echo "AR=libtool -static -o" >> $makefile_name
echo "else" >> $makefile_name
echo "AR=ar -rc" >> $makefile_name
echo "endif" >> $makefile_name
#动态连接库的扩展名
echo "ifdef win32" >> $makefile_name
echo "EXE_EXT=.exe" >> $makefile_name
echo "DLL_EXT=.dll" >> $makefile_name
echo "else" >> $makefile_name
echo "EXE_EXT=" >> $makefile_name
echo "DLL_EXT=.so" >> $makefile_name
echo "endif" >> $makefile_name

#编译和链接参数
echo "CFLAGS=$(trim_space "${external_cppflags}")" >> $makefile_name
echo "LDFLAGS=$(trim_space "${external_libs} ${external_ldflags}")" >> $makefile_name

#相关路径
echo "INC_DIR=${external_incs}" >> $makefile_name
echo "PREFIX=/usr/local" >> $makefile_name
echo "INSTALL_DIR=\$(PREFIX)/\$(PROJECT_NAME)" >> $makefile_name
echo "BUILD_DIR=.build" >> $makefile_name
echo "EXE_TARGET=\$(TARGET_DIR)/bin/\$(PROJECT_NAME)\$(EXE_EXT)" >> $makefile_name
echo "SHARE_TARGET=\$(TARGET_DIR)/lib/lib\$(PROJECT_NAME)\$(DLL_EXT)" >> $makefile_name
echo "STATIC_TARGET=\$(TARGET_DIR)/lib/lib\$(PROJECT_NAME).a" >> $makefile_name
echo "OBJECTS=\$(addprefix \$(BUILD_DIR)/,\$(strip \$(SOURCES:.${build_type}=.o)))" >> $makefile_name
echo "SRC_MKS=\$(addprefix \$(BUILD_DIR)/,\$(strip \$(SOURCES:.${build_type}=.d)))" >> $makefile_name

#目标文件
echo  >> $makefile_name

if [ $proj_type = "bin" ];then
    echo "all:\$(EXE_TARGET) lib" >> $makefile_name
    echo "\$(EXE_TARGET):\$(OBJECTS)" >> $makefile_name
    echo -e "\t@[ -d \"\$(dir \$@)\" ] || mkdir -p \"\$(dir \$@)\"" >> $makefile_name
    echo -e "\t@\$(CC) -o \$@ \$(LDFLAGS) \$^" >> $makefile_name
    echo  >> $makefile_name
    echo "lib:share static" >> $makefile_name
else
    echo "all:share static" >> $makefile_name
fi

echo "share:\$(OBJECTS)" >> $makefile_name
echo -e "\t@[ -d \"\$(dir \$(SHARE_TARGET))\" ] || mkdir -p \"\$(dir \$(SHARE_TARGET))\"" >> $makefile_name
echo -e "\t@\$(CC) -fPIC -shared -o \$(SHARE_TARGET) \$(LDFLAGS) \$^" >> $makefile_name
echo  >> $makefile_name

echo "static:\$(OBJECTS)" >> $makefile_name
echo -e "\t@[ -d \"\$(dir \$(STATIC_TARGET))\" ] || mkdir -p \"\$(dir \$(STATIC_TARGET))\"" >> $makefile_name
echo -e "\t@\$(AR) \$(STATIC_TARGET) \$^" >> $makefile_name
echo  >> $makefile_name

echo "\$(BUILD_DIR)/%.o:%.${build_type}" >> $makefile_name
echo -e "\t@[ -d \"\$(dir \$@)\" ] || mkdir -p \"\$(dir \$@)\"" >> $makefile_name
echo -e "\t@\$(CC) -c -o \$@ \$(CFLAGS) \$(INC_DIR) \$<" >> $makefile_name
echo  >> $makefile_name

echo "\$(BUILD_DIR)/%.d:%.${build_type}" >> $makefile_name
echo -e "\t@[ -d \"\$(dir \$@)\" ] || mkdir -p \"\$(dir \$@)\"" >> $makefile_name
echo -e "\t@set -e; \\" >> $makefile_name
echo -e "\t\$(CC) \$(CFLAGS) -MM \$(INC_DIR) \$< > \$@; \\" >> $makefile_name
echo -e "\tsed -ie 's,^\(.*\)\.o[ :]*,.build/\1.o \$@ : ,g' \$@" >> $makefile_name
echo >> $makefile_name

echo "sinclude \$(SRC_MKS)" >> $makefile_name
echo >> $makefile_name
echo ".PHONY: clean install run stop dev" >> $makefile_name

if [ $proj_type = "bin" ];then
    echo "run:./\$(EXE_TARGET)" >> $makefile_name
    echo -e "\t./\$(EXE_TARGET)" >> $makefile_name
    echo "stop:" >> $makefile_name
    echo -e "\t@ps -ef | grep \"\$(EXE_TARGET)\" | grep -v \"grep\" | awk '{system(\"kill \"\$2)}' 2>/dev/null >/dev/null" >> $makefile_name
    echo "dev:" >> $makefile_name
    echo -e "\t@watchman-make -p '**/*.${build_type}' '**/*.h' '**/*.hpp' 'Makefile' --run \"make stop && make run\"" >> $makefile_name
else
    echo "dev:" >> $makefile_name
    echo -e "\t@watchman-make -p '**/*.${build_type}' '**/*.h' '**/*.hpp' 'Makefile' --run \"make\"" >> $makefile_name
fi

echo "clean:" >> $makefile_name
echo -e "\trm -rf \$(TARGET_DIR) \$(BUILD_DIR)" >> $makefile_name

#首次安装，如果系统中已经有同名的库，回进行提示阻止（但不可靠）
echo "install:all" >> $makefile_name
echo -e "\t@if [ ! -d \"\$(INSTALL_DIR)\" ]; then \\" >> $makefile_name
echo -e "\t\tmkdir -p \"\$(INSTALL_DIR)/lib\"; \\" >> $makefile_name
echo -e "\t\tmkdir -p \"\$(INSTALL_DIR)/include\"; \\" >> $makefile_name
if [ $proj_type = "bin" ];then
echo -e "\t\tmkdir -p \"\$(INSTALL_DIR)/bin\"; \\" >> $makefile_name
echo -e "\t\tcp \$(EXE_TARGET) \$(INSTALL_DIR)/bin/; \\" >> $makefile_name
fi
echo -e "\t\tcp \$(TARGET_DIR)/lib/lib\$(PROJECT_NAME).* \$(INSTALL_DIR)/lib/; \\" >> $makefile_name
echo -e "\t\tcp include/*.h* \$(INSTALL_DIR)/include/; \\" >> $makefile_name
echo -e "\t\tln -s \$(INSTALL_DIR)/bin/\$(PROJECT_NAME)\$(EXE_EXT) \$(PREFIX)/bin/\$(PROJECT_NAME)\$(EXE_EXT); \\" >> $makefile_name
echo -e "\t\tln -s \$(INSTALL_DIR)/include \$(PREFIX)/include/\$(PROJECT_NAME); \\" >> $makefile_name
echo -e "\t\tln -s \$(INSTALL_DIR)/lib/lib\$(PROJECT_NAME)\$(DLL_EXT) \$(PREFIX)/lib/lib\$(PROJECT_NAME)\$(DLL_EXT); \\" >> $makefile_name
echo -e "\t\tln -s \$(INSTALL_DIR)/lib/lib\$(PROJECT_NAME).a \$(PREFIX)/lib/lib\$(PROJECT_NAME).a; \\" >> $makefile_name
echo -e "\telse \\" >> $makefile_name
if [ $proj_type = "bin" ];then
echo -e "\t\tcp \$(EXE_TARGET) \$(INSTALL_DIR)/bin/; \\" >> $makefile_name
fi
echo -e "\t\tcp \$(TARGET_DIR)/lib/lib\$(PROJECT_NAME).* \$(INSTALL_DIR)/lib/; \\" >> $makefile_name
echo -e "\t\tcp include/*.h* \$(INSTALL_DIR)/include/; \\" >> $makefile_name
echo -e "\t\tln -sf \$(INSTALL_DIR)/bin/\$(PROJECT_NAME)\$(EXE_EXT) \$(PREFIX)/bin/\$(PROJECT_NAME)\$(EXE_EXT); \\" >> $makefile_name
echo -e "\t\tln -sf \$(INSTALL_DIR)/include \$(PREFIX)/include/\$(PROJECT_NAME); \\" >> $makefile_name
echo -e "\t\tln -sf \$(INSTALL_DIR)/lib/lib\$(PROJECT_NAME)\$(DLL_EXT) \$(PREFIX)/lib/lib\$(PROJECT_NAME)\$(DLL_EXT); \\" >> $makefile_name
echo -e "\t\tln -sf \$(INSTALL_DIR)/lib/lib\$(PROJECT_NAME).a \$(PREFIX)/lib/lib\$(PROJECT_NAME).a; \\" >> $makefile_name
echo -e "\tfi" >> $makefile_name
echo -e "\t@ldconfig" >> $makefile_name

