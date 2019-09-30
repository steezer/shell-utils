#!/bin/bash
#注册域名查询

api_url="http://panda.www.net.cn/cgi-bin/check.cgi"
q_param=""
t_str=""

if [[ $* != "" ]];then
	if [[ $* == *,* ]];then
		q_param="${*}"
	elif [[ $* == *-* ]]; then
		t_str=${*#*[}
		t_str=${t_str%]*}
		head_str=${*%[*}
		next_str=${*#*]}
		start_c=`echo $t_str | cut -d \- -f 1`
		end_c=`echo $t_str | cut -d \- -f 2`
		start_n=$(printf "%d" "'${start_c}")
		end_n=$(printf "%d" "'${end_c}")
		cur_c=""

		for((k=$start_n;k<=$end_n;k++))
		do  
		    cur_c=$(printf \\x`printf %x $k`)
		    q_param="${q_param}${head_str}${cur_c}${next_str},"
		done
	else
		q_param="${*},"
	fi

	echo "search domain..."
	q_result=$(curl -s -d "area_domain=${q_param}" "${api_url}")
	res_arr=$(echo ${q_result// /}|tr "#" "\n")
	for x in $res_arr; do
	  if [[ `echo $x|awk -F '|' '{print $3}'` == "210" ]];then
	  	echo $x|awk -F '|' '{print $2}' 
	  fi
	done
fi

