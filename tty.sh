#!/bin/bash
trap "exit 1" TERM
export TOP_PID=$$

function listow ()
{
        clear
        echo "1-Wire Details"
        mastercount=`owdir /| grep -c /81`
        tempcount=`owdir /| grep -c /28`
        mscount=`owdir /| grep -c /26`
        buttoncount=`owdir /| grep -c /01`
        echo "1-Wire Busmaster: $mastercount Tempsensoren: $tempcount Humidity/Multi: $mscount iButton/IO: $buttoncount"
        owdir /| grep /01| while read; do echo -n `basename $REPLY`":       " ; echo "Present"; done
        owdir /| grep /28| while read; do echo -n `basename $REPLY`":" ; owread $REPLY/fasttemp ; echo " C"; done
        owdir /| grep /26| while read; do echo -n `basename $REPLY`":" ; owread $REPLY/temperature $REPLY/HIH4000/humidity $REPLY/VDD; echo " (T/H/Volt)"; done
        owdir /| grep /bus.| while read; 
              do 
              #echo -n `basename $REPLY`
              echo -n `owdir $REPLY| grep /81`
              echo -n " Errors/Search Errors:"
              owread $REPLY/interface/statistics/errors $REPLY/interface/statistics/search_errors/error_pass_1
              echo
              done 
        echo
        menu
}

function help ()
{
  CONFIRM=0
  clear
  echo "$logo"
  echo
  echo "Console 1 (ALT+F1): Server Menu"
  echo "Console 2 (ALT+F2): Terminal - back to Server Menu use (ALT+F1)"
  echo 
  echo "(M) Return to main menu"
  read -n 1 -t 60 CONFIRM
  case $CONFIRM in
  	m|M)  
        echo 
	listinfo
        ;;
    *) return;;
  esac
}

function shutdown()
{
  CONFIRM=0
  clear
  echo "$logo"
  echo
  echo
  echo "SHUTDOWN  (Y/N J/N)"
  echo "RESTART   (R)"
  echo
  echo "(M) Return to main menu"
  read -n 1 -t 60 CONFIRM
  case $CONFIRM in
  	y|Y|j|J)  
        clear
        echo 
        echo "Goodbye.."
        sync
        #echo "Pending data written to flash.."
        /sbin/shutdown -h now
        sleep 300
        ;;
  	r|R)  
        clear
        echo 
        echo "Goodbye.. restarting"
        sync
        #echo "Pending data written to flash.."
        /sbin/shutdown -r now
        sleep 300
  	    ;;
  	m|M)  
        echo 
		listinfo
        ;;
    *) return;;
  esac
}

function logs()
{
  clear
  echo "$logo"
  echo
  echo "View-Log for 5 Minutes"
  echo "(S) SmartHome.py    (5 minutes)"
  echo "(C) Syslog          (5 minutes - quit with "q")"
  echo "(E) EIB/KNX Monitor (5 minutes)"
  echo "Press Key to view Logs"
  echo "(M) Return to main menu"
  read -n 1 -t 60 CONFIRM  
  case $CONFIRM in
  	s|S)  
        echo 
        echo "Log: smarthome.py:"
        timeout 300s tail -f /var/log/smarthome.log
        ;;
	c|C)
		echo
		echo "Log: syslog:"
		timeout 300s cat /var/log/syslog | more
		;;
	e|E)
		echo
		echo "Log: EIB/KNX:"
		timeout 300s vbusmonitor1 local:/tmp/eib
		;;
	m|M)  
        echo 
	listinfo
        ;;
    *)return;;
  esac
  listinfo
}


function restart_svc()
{
  clear
  echo "$logo"
  echo
  echo "Restarting services"
  echo "(E) Restarting eibd"
  echo "(S) Restarting smarthome.py"
  echo "(O) Restarting owserver"
  echo "Press Key to restart Service"
  echo "(M) Return to main menu"
  read -n 1 -t 60 CONFIRM  
  case $CONFIRM in
  	e|E)  
        echo 
        echo "Restarting eibd:"
        /etc/init.d/eibd restart
        ;;
  	s|S)  
        echo 
        echo "Restarting smarthome.py:"
        /etc/init.d/smarthome.py restart
        ;;
  	o|O)  
        echo 
        echo "Restarting owserver:"
        /etc/init.d/owserver restart
        ;;
  	m|M)  
        echo 
	listinfo
        ;;
    *)restart_svc;;
  esac
  restart_svc

}

function ex ()
{
   clear
   echo "Goodbye ... "
   kill -s TERM $TOP_PID
}

function menu ()
{
KEYPRESS=""
echo "(M)enu  (O)newire-List  (R)estart-services  (L)ogs  (S)hutdown  (H)elp  (E)xit"
read -n 1 -t 60 KEYPRESS
if [ "$?" = "1" ]; then
  exit
  echo
fi

case $KEYPRESS in
	o|O)  listow;;
	s|S)  shutdown;;
	r|R)  restart_svc;;
	l|L)  logs;;
	h|H)  help;;
	m|M)  listinfo;;
        e|E)  ex;;
esac
listinfo
}


function listinfo () 
{
# sleep after boot
if [ ! -e /tmp/tty_inited ]; then
    beep -f 1000.7 -r 2 -D 50 -l 100
    sleep 1
fi
touch /tmp/tty_inited

#Background Prozess in /etc/inittab
# terminal8:2345:respawn:/usr/bin/tail -f /var/log/syslog >/dev/tty8
# terminal9:2345:respawn:/usr/bin/vbusmonitor1time local:/tmp/eib >/dev/tty9
# terminal10:2345:respawn:/usr/bin/tail -f /var/log/user.log >/dev/tty10

clear
echo "$logo"
echo
uname -snrvm
UPTIME=`uptime`
echo "Status: $UPTIME"
echo "--------------------------------------------------------------------------------------------------------------------------------"
ifconfig | egrep "^[a-z]| +inet" | egrep -v "^lo|127\.0"
route -n | grep -m 1 "^0\." | awk '{print "Route:    "$1 " -> " $2}'
echo "--------------------------------------------------------------------------------------------------------------------------------"
mtot=`cat /proc/meminfo | egrep "^MemTotal" | awk '{ printf("%.0f",$2/1024) }'`
mfree=`cat /proc/meminfo | egrep "^MemFree" | awk '{ printf("%.0f",$2/1024) }'`
mcache=`cat /proc/meminfo | egrep "^Cached" | awk '{ printf("%.0f",$2/1024) }'`
mdirty=`cat /proc/meminfo | egrep "^Dirty" | awk '{ printf("%.0f",$2/1024) }'`
echo "Memory: $mtot MB  Free: $mfree MB  Cached: $mcache MB  WriteCache: $mdirty MB"
echo "--------------------------------------------------------------------------------------------------------------------------------"
mastercount=`owdir /| grep -c /81`
tempcount=`owdir /| grep -c /28`
mscount=`owdir /| grep -c /26`
buttoncount=`owdir /| grep -c /01`
echo "1-Wire Busmaster: $mastercount Temperature: $tempcount Humidity/Multi: $mscount iButton/IO: $buttoncount"
owdir /| grep /bus.| while read; 
              do
              bus=`owdir $REPLY| grep /81`
              errors=`owread $REPLY/interface/statistics/errors | tr -d ' '`
              search_errors=`owread $REPLY/interface/statistics/search_errors/error_pass_1 | tr -d ' '`
              tempcount=`owdir $REPLY| grep -c /28`
              mscount=`owdir $REPLY| grep -c /26`
              buttoncount=`owdir $REPLY| grep -c /01 | tr -d ' '`
              #echo -n `basename $REPLY`
              echo -n -e "$bus Error/SearchError: $errors/$search_errors\tTemperature: $tempcount\tHumidity/MS: $mscount\tiButton/IO: $buttoncount"
              echo
              done 
echo "--------------------------------------------------------------------------------------------------------------------------------"
knxdcmd=`ps -eo args | grep knxd | grep -v grep`
knxdversion=`knxd --version`
echo "knxd-Version: $knxdversion"
echo "knxd-Prozess: $knxdcmd"
echo "--------------------------------------------------------------------------------------------------------------------------------"
#shpy_last=`cat /tmp/sh.startup`
shpy_last=`ps -eo lstart,cmd,etime,command | grep "/usr/bin/python3 /usr/local/smarthome/bin" | grep -v grep | awk '{print $1,$2,$3,$4,$5}'`
shpy_uptime=`ps -eo lstart,cmd,etime,command | grep "/usr/bin/python3 /usr/local/smarthome/bin" | grep -v grep | awk '{print $8}'`
echo "smarthome.py last start: $shpy_last"
echo "smarthome.py uptime: $shpy_uptime"
echo "--------------------------------------------------------------------------------------------------------------------------------"
menu
}

logo="       #####                            #    #
     #     #                       #   #    #
    #                            ###  #    #
   ######  ### ###   #### #  # # #   ######  ####  ### ###   ####       ####  #    #
        # #  ##  #  #    #  #   #   #    #  #   # #  ##  #  #####      #   #  #   #
 #     # #   #   # #    #  #   #   #    #  #   # #   #   # #      ##  #   #   #  #
 #####  #   #   #  ###### #    ## #    #   #### #   #   #  ####  ##  ####      ##
                                                                   #          #  
                                                                  #          #"


listinfo

