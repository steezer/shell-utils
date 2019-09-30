#!/bin/bash
#C语言运行和编译器

#文件路径
file_path="$1"
#项目路径（没有为空）
project_path="$2"


#Make配置文件名称
makefile="Makefile"
#是否为linux运行环境
is_linux=0
#是否为可执行文件
is_exec=1
#构建类型
build_type="none"

#检查是否构建为lib
checkLib(){
    grep "^\s*\/\/#!lib$" "$1" 2>/dev/null
}

#main函数检查
checkMain(){
    tmp_contents=$(grep "^\s*int\s\s*main\s*(.*)" $1 2>/dev/null)
    if [[ -z "$tmp_contents" ]];then
        tmp_contents=$(grep "^\s*void\s\s*main\s*(.*)" $1 2>/dev/null)
    fi
    if [[ -z "$tmp_contents" ]];then
        tmp_contents=$(grep "^\s*main\s*(.*)" $1 2>/dev/null)
    fi
    echo $tmp_contents
}

#检查构建类型
getBuildType(){
    if [ -n "$1" ]; then
        if [ -e "$(dirname "$1")/${makefile}" ]; then
            echo "make"
        elif [ -n "$(checkLib "$1")" ];then
            echo "lib"
        elif [ -n "$(checkMain "$1")" ]; then
            echo "exe"
        else
            echo "none"
        fi 
    elif [ -e "$(dirname "$1")/${makefile}"  ]; then
        echo "make"
    else
        tmp_type="none"
        for cur_file in `ls *.c* 2>/dev/null`; do
            if [ -n "$(checkMain "$cur_file")" ];then
                tmp_type="exe"
                break
            elif [ -n "$(checkLib "$cur_file")" ]; then
                tmp_type="lib"
                break
            fi
        done
        echo $tmp_type
        unset tmp_type
    fi
}

#搜索当前目录下应用路径
searchAppPath(){
    for cur_file in `ls *.c* 2>/dev/null`; do
        if [ "$1" = "exe" ]; then
            if [ -n "$(checkMain "$cur_file")" ];then
                echo "$(pwd)/${cur_file#./}"
                break
            fi
        elif [ "$1" = "lib" ]; then
            if [ -n "$(checkLib "$cur_file")" ];then
                echo "$(pwd)/${cur_file#./}"
                break
            fi
        else
            if [ -n "$(checkLib "$cur_file")" -o -n "$(checkMain "$cur_file")" ];then
                echo "$(pwd)/${cur_file#./}"
                break
            fi
        fi
    done
}

#获取应用路径
getAppPath(){
    app_tmp_file=""
    if [ -n "$(checkLib "$1")" -o -n "$(checkMain "$1")" ]; then
        app_tmp_file=$1
    else
        cd $(dirname $1)
        max_level=2;
        #检查当前文件是否有main函数，如果没有则依次向上层目录检查（最多3层）
        while [ $max_level -gt 0 ]; do
            let max_level=$max_level-1
            cd ..
            app_tmp_file=$(searchAppPath)
            if [ -n "$app_tmp_file" ]; then
                break
            fi
        done
    fi

    if [ -n "$app_tmp_file" ]; then
        echo $app_tmp_file
    fi
    unset app_tmp_file 
}


#获取根目录
getMakefileDir(){
    #如果找到了main方法，并且不存在Makefile 
    if [ $build_type = "none" -o $build_type = "make" ];then
        tmp_base_dir=$(dirname $1)
        #查找当前项目根目录
        if [ -n "$2" -a -f "$2" ];then
            all_projects=$(cat $2 | grep path | awk '{split($0,arr,"\"");print arr[4];}')

            #判断是否为linux运行
            if [[ -n "$(cat $2 | grep debian)" ]]; then
                is_linux=1
            fi
            for cproject in $all_projects; do
                if [[ "$1" =~ ^$cproject.* ]]; then
                    tmp_base_dir=$cproject
                    break
                fi
            done
        fi

        #如果当前项目根目录下不存在Makefile文件，则将根目录设置为当前文件根目录
        if [ ! -e "${tmp_base_dir}/${makefile}" ];then
            tmp_base_dir=$(dirname $1)
            #最多向上查找2级目录
            max_level=2
            #从当前目录依次查找Makefile文件
            while [ ! -e "${tmp_base_dir}/${makefile}" -a "${tmp_base_dir}" != '/' -a $max_level -gt 0 ]; do
                let max_level=$max_level-1
                tmp_base_dir=$(dirname $tmp_base_dir)
                cd $tmp_base_dir
            done
        fi

        if [ -e "${tmp_base_dir}/${makefile}" ];then
            echo $tmp_base_dir
        fi
        unset tmp_base_dir
    fi
}

if [ -z "$file_path" ]; then
    file_path=$(searchAppPath)
fi
if [ -z "$file_path" ]; then
    echo "Build target not found!"
    exit
fi

#获取当前文件的构建类型
build_type=$(getBuildType "$file_path")

#根路径，初始为当前文件所在目录
makefile_dir=$(getMakefileDir "$file_path" "$project_path")

#运行根目录下Makefile
if [ -n "$makefile_dir" ];then
    cd $makefile_dir
    CMD_STR="make -f $makefile && make run"

#直接编译当前文件
elif [ -f "${file_path}" ]; then

    #获取应用所在路径
    if [ $build_type = "none" ]; then
        app_filepath=$(getAppPath "$file_path")
        if [ -z "$app_filepath" ]; then
            app_filepath=$file_path
            build_type="lib"
        elif [ -n "$(checkLib "$app_filepath")" ]; then
            build_type="lib"
        else
            build_type="exe"
        fi
    else
        app_filepath=$file_path
    fi

    cd $(dirname $app_filepath)
    

    #编译后的可执行文件名称
    app_name=$(basename ${app_filepath%.*})

    #判断是C还是C++代码
    ext_name=${app_filepath##*.}
    CC="gcc"
    if [ $ext_name != "c" ]; then
        CC="g++ -std=c++11"
    fi
    #静态库打包工具
    lib_tool="ar rcs"
    if [[ $(uname) = "Darwin" ]]; then
        lib_tool="libtool -static -o"
    fi

    #自动获取编译参数及编译的文件
    build_flags=""
    build_files=""
    compile_flags=""
    link_flags=""
    FIRST_CMD_STR=""
    RUN_ARGS=""
    while read LINE
    do
        if [[ "${LINE%:*}" = "//#!" ]]; then
            #编译或链接参数
            build_flags="${build_flags} ${LINE#*:}"
        elif [[ "${LINE%:*}" = "//#!C" ]]; then
            #编译参数
            compile_flags="${compile_flags} ${LINE#*:}"
        elif [[ "${LINE%:*}" = "//#!L" ]]; then
            #链接参数
            link_flags="${link_flags} ${LINE#*:}"
        elif [[ "${LINE%:*}" = "//#@" ]]; then
            #编译的文件
            build_files="${build_files} ${LINE#*:}"
        elif [[ "${LINE%:*}" = "//#&" ]]; then
            #运行前执行的命令
            if [[ -n "${LINE#*:}" ]]; then
                FIRST_CMD_STR="${FIRST_CMD_STR}${LINE#*:} && "
            fi
        elif [[ "${LINE%:*}" = "//##" ]]; then
            #运行的传入的参数
            RUN_ARGS="${RUN_ARGS} ${LINE#*:}"
        fi
    done < $app_filepath

    #生成编译命令
    app_filename=$(basename $app_filepath)
    [ ! -d ".build" ] && mkdir ".build"
    if [ $build_type = "exe" ]; then
        CMD_STR="${CC} -o \".build/${app_name}\" ${build_flags} ${compile_flags} ${link_flags} \"${app_filename}\" ${build_files} && .build/${app_name} ${RUN_ARGS}"
    else
        lib_dir="lib"
        [ ! -d $lib_dir ] && mkdir $lib_dir
        all_buildfiles=("${build_files} ${app_filename}")
        CMD_STR=""
        for i in $all_buildfiles; do
            CMD_STR="${CMD_STR}${CC} -fPIC -c ${compile_flags} -o \"${lib_dir}/${i//\//_}.o\" $i && "
        done
        CMD_STR="${CMD_STR}${CC} -shared -fPIC ${link_flags} -o \"${lib_dir}/lib${app_name}.so\" ${lib_dir}/*.o && "
        CMD_STR="${CMD_STR}${lib_tool} \"${lib_dir}/lib${app_name}.a\" ${lib_dir}/*.o && "
        CMD_STR="${CMD_STR}echo \"build lib success!\" && "
        CMD_STR="${CMD_STR}rm -f ${lib_dir}/*.o"
    fi
    if [[ -n "$FIRST_CMD_STR" ]]; then
        CMD_STR="${FIRST_CMD_STR}${CMD_STR}"
    fi
    # echo $CMD_STR
fi


if [ -n "$CMD_STR" ]; then
    if [ $is_linux = "1" ]; then
        docker run --rm -v$(pwd):/app -w /app steeze/php-dev sh -c "${CMD_STR}"
    else
        bash -c "$CMD_STR"
    fi
fi
