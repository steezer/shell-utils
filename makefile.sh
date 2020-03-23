#!/bin/bash

GSED="sed"
if [ $(uname) == "Darwin" ];then
    GSED="gsed"
fi
makeFilename="Makefile"

#初始化变量
projectName=""
projectVersion="1.0.0"
projectType="executable"
projectFile=""
buildType=""
installPrefix="/usr/local"
ignores="test"
includes=""
libraries=""
linkFlags=""
compileFlags=""

#主程序文件（含main函数）
targetFiles=""
#其它源文件（不含main函数）
sourceFiles=""

#自动获取参数
__temp_params="${*} "
while getopts ":o:p:t:c:l:L:shv:C:F:I:f:i:" temp_opt
do
    case $temp_opt in
        # 指定类型
        t )
            if [ "$OPTARG" == "c" ];then
                buildType="c"
            fi
            __temp_params=${__temp_params/-t*$OPTARG / }
        ;;
        # 项目名称
        o )
            projectName=$OPTARG
            __temp_params=${__temp_params/-o*$OPTARG / }
        ;;
        # 项目版本
        v )
            projectVersion=$OPTARG
            __temp_params=${__temp_params/-v*$OPTARG / }
        ;;
        # 指定项目文件
        f )
            projectFile=${OPTARG#./}
            __temp_params=${__temp_params/-f*$OPTARG / }
        ;;
        # 安装前缀
        p )
            installPrefix=$OPTARG
            __temp_params=${__temp_params/-p*$OPTARG / }
        ;;
        # 指定Mafile文件名称
        c )
            makeFilename=$OPTARG
            __temp_params=${__temp_params/-c*$OPTARG / }
        ;;
        # 指定生成库文件
        s )
            projectType="library"
            __temp_params=${__temp_params/-s / }
        ;;
        # 连接库名称
        l )
            libraries="${libraries} -l${OPTARG}"
            __temp_params=${__temp_params/-l*$OPTARG / }
        ;;
        # 连接库目录
        L )
            libraries="${libraries} -L${OPTARG}"
            __temp_params=${__temp_params/-L*$OPTARG / }
        ;;
        # 指定编译参数
        C )
            compileFlags="${compileFlags} ${OPTARG}"
            __temp_params=${__temp_params/-D*$OPTARG / }
        ;;
        # 指定包含目录
        I )
            includes="${includes} -I${OPTARG}"
            __temp_params=${__temp_params/-I*$OPTARG / }
        ;;
        # 指定链接参数
        F )
            linkFlags="${linkFlags} ${OPTARG}"
            __temp_params=${__temp_params/-F*$OPTARG / }
        ;;
        # 指定忽略的目录（默认test）
        i )
            ignores=$OPTARG
            __temp_params=${__temp_params/-i*$OPTARG / }
        ;;
        # 帮助
        h )
            show_help
            exit
        ;;
    esac
done
__temp_params="${__temp_params// /}"
#直接生成文件支持，例如：makeconfig spring
if [ -n "$__temp_params" -a -z "${projectName}" ];then
    projectName=${__temp_params/-*/}
fi
unset __temp_params


#帮助文件
show_help(){
    echo "Usage: makefile [options...][name]"
    echo "Options:"
    echo -e "-o <name>\tspecify the output file name as <name>"
    echo -e "-c <name>\tspecify the make config file, default: Makefile"
    echo -e "-v <value>\tSpecify software version <value>"
    echo -e "-t <value>\tSpecify the build type, whether c or cpp project"
    echo -e "-l <library>\tlibraries to pass to the linker, e.g. -l<library>"
    echo -e "-I <dirname>\tC preprocessor flags: include dir, e.g. -I<dirname>"
    echo -e "-C <value>\tCompile flags, e.g. -C -DDEBUG=true -C -std=gnu99"
    echo -e "-F <value>\tLinker flags, e.g. -export-dynamic -lmemcached"
    echo -e "-f <file>\tLocate the entry file if make a executable file"
    echo -e "-i <dirnames>\tIgnore dirnames separated by Spaces, default: test"
    echo -e "-p <prefix>\tInstall path prefix, default: ${installPrefix}"
    echo -e "          \te.g. -i \"demo test/show\""
    echo -e "-s \tMake a share library file, make a executable file instead if ignore"
    echo -e "-h \tShow help information"
    echo -e "name: Specify the output file name, instead of -o <name>"
}
#去除首位空格，并将中间多个空格替换为1个空格
trim_space(){
    echo $@ | $GSED -e 's/^[ \t]*//g' -e 's/[ \t]*$//g' | $GSED -e 's/[ \t]+/ /g'
}

#扫描源代码文件，获取目标文件与其它源文件
scanSourceFiles(){
    __tmpContents=""
    __isSearched=0
    __ignorePaths=""
    if [ -n "$ignores" ];then
        for __tmpName in $ignores;do
            __ignorePaths="${__ignorePaths} -o -path ./${__tmpName#./}"
        done
    fi
    for __tmpFile in `find . \( -path ./.\* $__ignorePaths \) -prune -o -type f -name "*.c*" -print`; do
        __tmpContents=$(grep "^\s*int\s\s*main\s*(.*)" $__tmpFile 2>/dev/null)
        if [[ -z "$__tmpContents" ]];then
            __tmpContents=$(grep "^\s*void\s\s*main\s*(.*)" $__tmpFile 2>/dev/null)
        fi
        if [[ -z "$__tmpContents" ]];then
            __tmpContents=$(grep "^\s*main\s*(.*)" $__tmpFile 2>/dev/null)
        fi
        # 如果找到main函数则获取目标文件
        if [[ -n "$__tmpContents" ]];then
            targetFiles="${targetFiles} ${__tmpFile#./}"
            if [ "${__tmpFile#./}" = "$projectFile" ];then
                __isSearched=1
            fi
        else
            sourceFiles="${sourceFiles} ${__tmpFile#./}"
        fi
        # 只要当前中有不为c文件类型的，即将编译类型设置为cpp
        if [ -z "$buildType" -a "${__tmpFile##*.}" != "c"  ];then
            buildType="cpp"
        fi
    done
    if [ -z "$buildType" ]; then
        buildType="c"
    fi
    # 将找到的目标文件序列转换为数组
    targetFiles=($targetFiles)
    # 如果用户指定的项目主文件在源文件中没找到，并且目标源文件存在，则设置项目主文件
    if [ $__isSearched -eq 0 -a -n "${targetFiles[0]}" ];then
        projectFile=${targetFiles[0]}
    fi
    unset __tmpContents
    unset __tmpFile
}

#生成通配符表示的路径
getSourcePattern(){
    __results=""
    for i in "$@"; do
        # 将文件路径转化为模式匹配，
        # 如：abc/cd/test.c转为abc/*/*.c
        OLD_IFS="$IFS"
        IFS="/"
        arrs=($i)
        tmpsrc=${arrs[0]}
        unset arrs[0]
        for s in ${arrs[@]}; do
            tmpsrc="${tmpsrc}|*" 
        done
        if [ ${#arrs[@]} -gt 0 ]; then
            tmpsrc="${tmpsrc}.${buildType}" 
        fi
        IFS="$OLD_IFS"

        # 检查当前匹配是否在结果集中，如果不在则加入
        if [ -z "$__results" ]; then
            __results="${tmpsrc}"
        fi
        hastmpsrc="no"
        for m in $__results; do
            if [ $m = "${tmpsrc}" ]; then
                hastmpsrc="yes"
            fi
        done
        if [ $hastmpsrc = "no" ]; then
            __results="${__results} ${tmpsrc}"
        fi
    done
    echo "${__results//|//}"
    unset __results  
}


############生成Makefile文件#########

# 常用变量定义
makefileForCommon(){
    echo "PROJECT_NAME=${projectName}"
    echo "TARGET_DIR=release"
    #编译工具
    if [ $buildType == "cpp" ];then
        echo "CC=g++"
    else
        echo "CC=gcc"
    fi
    #静态库打包工具
    echo "ifeq (\$(shell uname),Darwin)"
    echo "AR=libtool -static -o"
    echo "else"
    echo "AR=ar -rc"
    echo "endif"
    #动态连接库的扩展名
    echo "ifdef win32"
    echo "EXE_EXT=.exe"
    echo "DLL_EXT=.dll"
    echo "else"
    echo "EXE_EXT="
    echo "DLL_EXT=.so"
    echo "endif"

    #编译和链接参数
    echo "CFLAGS=$(trim_space "${compileFlags}")"
    echo "LDFLAGS=$(trim_space "${libraries} ${linkFlags}")"

    #相关路径
    echo "INC_DIR=${includes}"
    echo "PREFIX=${installPrefix}"
    echo "INSTALL_DIR=\$(PREFIX)/app/\$(PROJECT_NAME)"
    echo "BUILD_DIR=.build"
}

# 对象编译
makefileForObject(){
    echo "\$(BUILD_DIR)/%.o:%.${buildType}"
    echo -e "\t@[ -d \"\$(dir \$@)\" ] || mkdir -p \"\$(dir \$@)\""
    echo -e "\t@\$(CC) -c -fPIC -o \$@ \$(CFLAGS) \$(INC_DIR) \$<"
    echo 
    echo "\$(BUILD_DIR)/%.d:%.${buildType}"
    echo -e "\t@[ -d \"\$(dir \$@)\" ] || mkdir -p \"\$(dir \$@)\""
    echo -e "\t@set -e; \\"
    echo -e "\t\$(CC) \$(CFLAGS) -MM \$(INC_DIR) \$< > \$@; \\"
    echo -e "\tsed -ie 's,^\(.*\)\.o[ :]*,.build/\1.o \$@ : ,g' \$@"
    echo    
}

# 目标文件编译
makefileForBin(){

    # 常用配置
    makefileForCommon

    # 目标文件
    echo "TARGET_SOURCE=${targetFiles[0]}"
    echo "EXE_TARGET=\$(TARGET_DIR)/bin/\$(PROJECT_NAME)\$(EXE_EXT)"
    echo "TARGET_OBJECT=\$(addprefix \$(BUILD_DIR)/,\$(strip \$(addsuffix .o,\$(basename \$(TARGET_SOURCE))) ))"
    echo "TARGET_SRC_MKS=\$(addprefix \$(BUILD_DIR)/,\$(strip \$(addsuffix .d,\$(basename \$(TARGET_SOURCE))) ))"
    
    #【如果有源文件则编译进目标文件】
    if [ -n "$sourcePatterns" ]; then
        echo "LIB_SOURCES=\$(wildcard $sourcePatterns)"
        echo "SHARE_TARGET=\$(TARGET_DIR)/lib/lib\$(PROJECT_NAME)\$(DLL_EXT)"
        echo "STATIC_TARGET=\$(TARGET_DIR)/lib/lib\$(PROJECT_NAME).a"
        echo "LIB_OBJECTS=\$(addprefix \$(BUILD_DIR)/,\$(strip \$(addsuffix .o,\$(basename \$(LIB_SOURCES))) ))"
        echo "LIB_SRC_MKS=\$(addprefix \$(BUILD_DIR)/,\$(strip \$(addsuffix .d,\$(basename \$(LIB_SOURCES))) ))"
    fi

    # 编译目标
    echo 
    echo "all:\$(EXE_TARGET) lib"
    #【如果有源文件则编译进目标文件】
    if [ -n "$sourcePatterns" ]; then
        echo "\$(EXE_TARGET):\$(TARGET_OBJECT) \$(LIB_OBJECTS)"
    else
        echo "\$(EXE_TARGET):\$(TARGET_OBJECT)"
    fi
    echo -e "\t@[ -d \"\$(dir \$@)\" ] || mkdir -p \"\$(dir \$@)\""
    echo -e "\t@\$(CC) -o \$@ \$^ \$(LDFLAGS)"
    echo 

    #【如果有源文件则编译库文件】
    if [ -n "$sourcePatterns" ]; then
        # 库文件
        echo "lib:share static"
        echo "share:\$(LIB_OBJECTS)"
        echo -e "\t@[ -d \"\$(dir \$(SHARE_TARGET))\" ] || mkdir -p \"\$(dir \$(SHARE_TARGET))\""
        echo -e "\t@\$(CC) -o \$(SHARE_TARGET) \$^ \$(LDFLAGS) -shared"
        echo 
        echo "static:\$(LIB_OBJECTS)"
        echo -e "\t@[ -d \"\$(dir \$(STATIC_TARGET))\" ] || mkdir -p \"\$(dir \$(STATIC_TARGET))\""
        echo -e "\t@\$(AR) \$(STATIC_TARGET) \$^"
        echo 

    fi

    # 对象编译
    makefileForObject

    #【如果有源文件则包含库文件定义】
    if [ -n "$sourcePatterns" ]; then
        echo "sinclude \$(LIB_SRC_MKS)"
    fi

    echo "sinclude \$(TARGET_SRC_MKS)"
    echo

    # 运行、清理
    echo ".PHONY: clean install run stop dev test"
    if [ -n "$sourcePatterns" ]; then
        echo "test: \$(TARGET_OBJECT) lib"
        echo -e "\t@\$(CC) \$(CFLAGS) \$(INC_DIR) -o \$(BUILD_DIR)/test \$(LDFLAGS) \$< -Wl,-rpath \$(TARGET_DIR)/lib  -L\$(TARGET_DIR)/lib -l\$(PROJECT_NAME) && echo ./\$(BUILD_DIR)/test"

    fi
    echo "run:./\$(EXE_TARGET)"
    echo -e "\t./\$(EXE_TARGET)"
    echo "stop:"
    echo -e "\t@ps -ef | grep \"\$(EXE_TARGET)\" | grep -v \"grep\" | awk '{system(\"kill \"\$2)}' 2>/dev/null >/dev/null"
    echo "dev:"
    echo -e "\t@watchman-make -p '**/*.${buildType}' '**/*.h' '**/*.hpp' 'Makefile' --run \"make stop && make run\""
    echo "clean:"
    echo -e "\trm -rf \$(TARGET_DIR) \$(BUILD_DIR)"

    # 安装
    echo "install:all"
    echo -e "\t@if [ ! -d \"\$(INSTALL_DIR)\" ]; then \\"
    echo -e "\t\tmkdir -p \"\$(INSTALL_DIR)/bin\"; \\"
    #【如果有源文件则建立库文件目录】
    if [ -n "$sourcePatterns" ]; then
        echo -e "\t\tmkdir -p \"\$(INSTALL_DIR)/lib\"; \\"
        echo -e "\t\tmkdir -p \"\$(INSTALL_DIR)/include\"; \\"
    fi
    echo -e "\tfi"
    #【如果有源文件则拷贝库文件】
    if [ -n "$sourcePatterns" ]; then
        echo -e "\t@if [ -d \"include\" ]; then \\"
        echo -e "\t\tcp include/*.h* \$(INSTALL_DIR)/include/;\\"
        echo -e "\tfi"
        echo -e "\tcp \$(TARGET_DIR)/lib/lib\$(PROJECT_NAME).* \$(INSTALL_DIR)/lib/"
    fi
    # 可自动检查目标文件是否存在，如果存在则不建立软链接
    echo -e "\tcp \$(EXE_TARGET) \$(INSTALL_DIR)/bin/"
    echo -e "\t@if [ ! -e \"\$(PREFIX)/bin/\$(PROJECT_NAME)\$(EXE_EXT)\" \\"
    echo -e "\t-o \"\$(shell readlink \$(PREFIX)/bin/\$(PROJECT_NAME)\$(EXE_EXT))\" == \"\$(INSTALL_DIR)/bin/\$(PROJECT_NAME)\$(EXE_EXT)\" \\"
    echo -e "\t]; then  \\"
    echo -e "\t\tln -sf \$(INSTALL_DIR)/bin/\$(PROJECT_NAME)\$(EXE_EXT) \$(PREFIX)/bin/\$(PROJECT_NAME)\$(EXE_EXT); \\"
    echo -e "\telse  \\"
    echo -e "\t\techo \"\033[31mexists: \$(PREFIX)/bin/\$(PROJECT_NAME)\$(EXE_EXT) \033[0m\"; \\"
    echo -e "\tfi"
}

# 库文件编译
makefileForLib(){
    # 常用配置
    makefileForCommon

    # 库文件对象
    echo "LIB_SOURCES=\$(wildcard $sourcePatterns)"
    echo "SHARE_TARGET=\$(TARGET_DIR)/lib/lib\$(PROJECT_NAME)\$(DLL_EXT)"
    echo "STATIC_TARGET=\$(TARGET_DIR)/lib/lib\$(PROJECT_NAME).a"
    echo "LIB_OBJECTS=\$(addprefix \$(BUILD_DIR)/,\$(strip \$(addsuffix .o,\$(basename \$(LIB_SOURCES))) ))"
    echo "LIB_SRC_MKS=\$(addprefix \$(BUILD_DIR)/,\$(strip \$(addsuffix .d,\$(basename \$(LIB_SOURCES))) ))"

    # 编译目标
    echo 
    echo "all:share static"
    

    # 库文件编译
    echo "share:\$(LIB_OBJECTS)"
    echo -e "\t@[ -d \"\$(dir \$(SHARE_TARGET))\" ] || mkdir -p \"\$(dir \$(SHARE_TARGET))\""
    echo -e "\t@\$(CC) -o \$(SHARE_TARGET) \$^ \$(LDFLAGS) -shared"
    echo 
    echo "static:\$(LIB_OBJECTS)"
    echo -e "\t@[ -d \"\$(dir \$(STATIC_TARGET))\" ] || mkdir -p \"\$(dir \$(STATIC_TARGET))\""
    echo -e "\t@\$(AR) \$(STATIC_TARGET) \$^"
    echo 

    # 对象编译
    makefileForObject

    echo "sinclude \$(LIB_SRC_MKS)"
    echo

    # 运行、清理、安装
    echo ".PHONY: clean install run stop dev"
    echo "dev:"
    echo -e "\t@watchman-make -p '**/*.${buildType}' '**/*.h' '**/*.hpp' 'Makefile' --run \"make\""
    echo "clean:"
    echo -e "\trm -rf \$(TARGET_DIR) \$(BUILD_DIR)"
    echo "install:all"
    echo -e "\t@if [ ! -d \"\$(INSTALL_DIR)\" ]; then \\"
    echo -e "\t\tmkdir -p \"\$(INSTALL_DIR)/lib\"; \\"
    echo -e "\t\tmkdir -p \"\$(INSTALL_DIR)/include\"; \\"
    echo -e "\tfi"
    echo -e "\t@if [ -d \"include\" ]; then \\"
    echo -e "\t\tcp include/*.h* \$(INSTALL_DIR)/include/;\\"
    echo -e "\tfi"
    echo -e "\tcp \$(TARGET_DIR)/lib/lib\$(PROJECT_NAME).* \$(INSTALL_DIR)/lib/"
    echo -e "\tln -sf \$(INSTALL_DIR)/include \$(PREFIX)/include/\$(PROJECT_NAME)"
    echo -e "\tln -sf \$(INSTALL_DIR)/lib/lib\$(PROJECT_NAME)\$(DLL_EXT) \$(PREFIX)/lib/lib\$(PROJECT_NAME)\$(DLL_EXT)"
    echo -e "\tln -sf \$(INSTALL_DIR)/lib/lib\$(PROJECT_NAME).a \$(PREFIX)/lib/lib\$(PROJECT_NAME).a"
    echo -e "\t@ldconfig"
}

# 生成.gitignore文件
makeGitignore(){
    if [ ! -e ".gitignore" ]; then
        echo ".*" >> .gitignore
        echo "!.vscode" >> .gitignore
        echo "!.gitignore" >> .gitignore
        echo "release" >> .gitignore
    fi
}

# 生成vscode配置文件
makeVscodeSetting(){
    if [ ! -d ".vscode" ]; then
        mkdir ".vscode"
    fi
    settingFile=".vscode/c_cpp_properties.json"
    if [ ! -e $settingFile ]; then
        echo -e "{" >> $settingFile
        echo -e "\t\"configurations\": [" >> $settingFile
        echo -e "\t\t{" >> $settingFile
        echo -e      "\t\t\t\"name\": \"Mac\"," >> $settingFile
        echo -e     "\t\t\t\"includePath\": [" >> $settingFile
        echo -e         "\t\t\t\t\"\${workspaceFolder}/**\"" >> $settingFile
        echo -e      "\t\t\t]," >> $settingFile
        echo -e      "\t\t\t\"defines\": []," >> $settingFile
        echo -e      "\t\t\t\"macFrameworkPath\": [" >> $settingFile
        echo -e          "\t\t\t\t\"/System/Library/Frameworks\"," >> $settingFile
        echo -e          "\t\t\t\t\"/Library/Frameworks\"" >> $settingFile
        echo -e      "\t\t\t]," >> $settingFile
        echo -e      "\t\t\t\"compilerPath\": \"/usr/bin/clang\"," >> $settingFile
        echo -e      "\t\t\t\"cStandard\": \"c11\"," >> $settingFile
        echo -e      "\t\t\t\"cppStandard\": \"c++11\"," >> $settingFile
        echo -e      "\t\t\t\"intelliSenseMode\": \"clang-x64\"" >> $settingFile
        echo -e  "\t\t}" >> $settingFile
        echo -e "\t]," >> $settingFile
        echo -e "\t\"version\": 4" >> $settingFile
        echo -e "}" >> $settingFile
    fi
}

# 扫描源代码文件，获取目标文件与其它源文件
scanSourceFiles

# 获取源文件的匹配路径
sourcePatterns=$(getSourcePattern $sourceFiles)

# 如果项目名称未设置，则使用当前目录名称作为项目名称
if [ -z "$projectName" ];then
    projectName=$(basename $(pwd))
fi

# 如果目标文件不存在且源文件并为空，自动将编译类型设为库文件
if [ -z "${targetFiles[0]}" -a -n "$sourcePatterns" ];then
    projectType="library"
fi

# 如果编译为可执行文件，但目标文件不存在
if [ $projectType = "executable" -a -z "${targetFiles[0]}" ];then
    #找不到入口函数则退出
    echo "Error: No entry function main for ${buildType} project!"
    exit
fi
# 编译为库文件，但源文件不存在
if [ $projectType = "library" -a -z "$sourcePatterns" ];then
    echo "Error: No source files for build a lib name!"
    exit
fi

# 设置默认C++11
if [ "${buildType}" = "cpp" ]; then
    compileFlags=" -std=c++11 ${compileFlags}"
fi

# 自动保护include目录
if [ -d "include" ]; then
    includes="-I./include $includes"
fi

# 生成Makefile文件
if [ $projectType = "executable" ];then
    makefileForBin > $makeFilename
else
    makefileForLib > $makeFilename
fi
# 生成.gitignore文件
makeGitignore
# 生成vscode配置文件
makeVscodeSetting
echo -e "\033[32mCreate \"Makefile\" for ${projectType} file of \"${buildType}\" successfully!\033[0m"
echo "You can run: make && make install"

