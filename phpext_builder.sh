#!/bin/bash
#PHP扩展开发辅助命令
###################php多版本选择##################
##for php5.2.17 system
#PHP_DIR="/usr/local/php52/"
#for php5.6.28 system
#PHP_DIR="/usr/local/php56/"
#for php7.0.15 source build install
#PHP_DIR="/usr/local/php70/"
#for 7.1.10 source build install
#PHP_DIR="/usr/local/php71/"

#获取PHP版本
PHP_VERSION=$(echo $1 | grep '^php[0-9]\+$')
PHP_VERSION_DEFAULT="php70"
if [ -n "$PHP_VERSION" ];then
	if [ -d "/usr/local/${PHP_VERSION}/" ];then
		shift
	else
		PHP_VERSION=$PHP_VERSION_DEFAULT
	fi
else
	PHP_VERSION=$PHP_VERSION_DEFAULT
fi
echo "Config with ${PHP_VERSION} ..."

PHP_DIR="/usr/local/${PHP_VERSION}/"
#for webserver command
WEBSERVER="/opt/spring/bin/webserver"


module_name=$MODULE_NAME
CUR_DIR=$(pwd)
CUR_DIR=${CUR_DIR%/}


if [ -z "${REMOTE_HOST}" ];then
	REMOTE_HOST=root@180.76.169.237
fi

if [ -z "${REMOTE_DIR}" ];then
	REMOTE_DIR=/root/php-extension/$module_name/
fi

#获取扩展名称
phpext_name(){
	if [ -e "config.m4" ];then
		__ext_name=$(cat config.m4 | grep '^\s*PHP_NEW_EXTENSION')
		__ext_name=${__ext_name#*(}
		echo ${__ext_name%%,*} | /usr/bin/sed "s/[[:space:]]//g"
	fi
}

phpext_help(){
	echo -e "Usage: phpext [option]"
	echo -e "config \t Make configure file with php-config only"
	echo -e "make \t Make php extension and install"
	echo -e "test \t Test the php extension"
	echo -e "clean \t Clean all generated file"
	echo "This tool use to help make php extension!"
	exit
}


#扩展配置
phpext_config(){
	if [ "$1" = "reload" ];then
		${PHP_DIR}bin/phpize
		./configure --with-php-config=${PHP_DIR}bin/php-config $2
	else
		if [ ! -e "configure" ];then
			${PHP_DIR}bin/phpize
		fi
		if [ ! -e "Makefile" ];then
			./configure --with-php-config=${PHP_DIR}bin/php-config $2
		fi
	fi
}

#扩展重载
phpext_reload(){
	case "$1" in
		php)
			$WEBSERVER php restart
		;;
		nginx)
			$WEBSERVER nginx restart
		;;
		all)
			$WEBSERVER restart
		;;
	esac
}

#增加扩展配置
phpext_ini(){
	echo "extension=${module_name}.so" > "${PHP_DIR}etc/conf.d/${module_name}.ini"
}

#本地测试
phpext_test(){
	echo "【local debug】:"
	if [ -e "test/${module_name}.php" -o -e "test-${module_name}.php" -o -e "${module_name}.php" ];then
		if [ -e "test/${module_name}.php" ];then
			${PHP_DIR}bin/php test/${module_name}.php
		elif [ -e "${module_name}.php" ];then
			${PHP_DIR}bin/php ${module_name}.php
		else
			./test_${module_name}.php
		fi
	else
		echo "Please make test file named \"test/${module_name}.php\""
	fi
}

#远程测试
remote_debug(){
	echo "【remote debug】（${REMOTE_HOST}:${REMOTE_DIR}）:"
	ssh ${REMOTE_HOST} "mkdir -p ${REMOTE_DIR}"
	scp -r *.c *.h *.php config.m4 include test ${REMOTE_HOST}:${REMOTE_DIR} >/dev/null 2>&1
	ssh ${REMOTE_HOST} "cd ${REMOTE_DIR} && make >/dev/null && make install >/dev/null && php test/stwms.php"
}

#######################################################################
#######################################################################

#相关变量设置
if [ -n "$module_name"  -a -d "${CUR_DIR}/ext/${module_name}" ];then
	cd "${CUR_DIR}/ext/${module_name}"
else
	module_name=$(phpext_name)
fi

if [ -z "$module_name" ];then
	echo "Error! you should run in a php extension dir!"
	exit
fi

#命令处理
case "$1" in
	config)
		shift
		phpext_config reload $*
	;;
	all | make)
		shift
		phpext_config auto $*
		if [ -e "Makefile" -o -e "makefile" ];then
			make && make -s install >/dev/null 2>&1 && phpext_ini && phpext_reload php
		fi
	;;
	clean)
		make clean &>/dev/null
		echo yes | rm ac*.m4 Makefile* configure* config.s* config.h* config.g* config.log config.nice install-sh libtool ltmain.sh missing mkinstalldirs *.loT run-tests.php &>/dev/null
		rm -rf build *.cache &>/dev/null
		rm -rf .deps
		rmdir include modules &>/dev/null
		echo "clean complete!"
	;;
	test)
		phpext_test
		if [ "${REMOTE_DEBUG}" = "1" ];then
			remote_debug
		fi
	;;
	help | --help | -h | *)
		phpext_help
	;;
esac

