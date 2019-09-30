#!/bin/bash
#获取主机成功登录信息
cmdname="${0##*/}"
showhelp(){
	echo -e "Usage: ${cmdname} [-c] [-n] [-s] [number]"
	echo -e "-c|--count \t Total success login time"
	echo -e "-n|--num 5 \t Last login info in the last 5 time,show all if no num"
	echo -e "-s|--sum 5 \t Show top 5 login info,if no 5,show all if no num"
	echo "This tool use to find login infomation!"
	exit
}
case "$1" in 
	-c|--count)
		echo "Total success login time:"
		who /var/log/wtmp | wc -l
	;;
	-n|--num)
		if [ -z "$2" ];then
			who /var/log/wtmp|awk '{line[NR]=$0} END{for(i=NR;i>0;i--)print line[i]}'|head -n 10
		elif [ "$2" -gt 0 ] 2>/dev/null; then
			who /var/log/wtmp|awk '{line[NR]=$0} END{for(i=NR;i>0;i--)print line[i]}'|head -n $2
		fi
	;;
	-s|--sum)
		if [ -z "$2" ];then
			who /var/log/wtmp | awk '{print $5}'|sort|uniq -c|sort -nr|awk -F '[(|)]' '{printf $1" "$2" ";system("loopupip -q "$2);print ""}'
		elif [ "$2" -gt 0 ] 2>/dev/null; then
			who /var/log/wtmp | awk '{print $5}'|sort|uniq -c|sort -nr| head -n $2 | awk -F '[(|)]' '{printf $1" "$2" ";system("loopupip -q "$2);print ""}'
		fi
	;;
	* )
		showhelp
	;;
esac

