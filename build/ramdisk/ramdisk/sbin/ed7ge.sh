#!/system/bin/sh
# 


#--------------------------------------
# Define logfile path
#--------------------------------------
DATA_PATH=/data/.fivanbe
fivanbe_LOGFILE="/data/.fivanbe/ED7GE.kernel.log"


#--------------------------------------
# maintain log file history
#--------------------------------------
	rm $fivanbe_LOGFILE.3
	mv $fivanbe_LOGFILE.2 $fivanbe_LOGFILE.3
	mv $fivanbe_LOGFILE.1 $fivanbe_LOGFILE.2
	mv $fivanbe_LOGFILE $fivanbe_LOGFILE.1


#---------------------------------------------------------------------------
# Initialize the log file (chmod to make it readable also via /sdcard link)
#----------------------------------------------------------------------------
	echo $(date) "ED7GE.Kernel initialisation started" > $fivanbe_LOGFILE
	chmod 777 $fivanbe_LOGFILE
	cat /proc/version >> $fivanbe_LOGFILE
	echo "=========================" >> $fivanbe_LOGFILE
	grep ro.build.version /system/build.prop >> $fivanbe_LOGFILE
	echo "=========================" >> $fivanbe_LOGFILE


#--------------------------------------
# Mount
#--------------------------------------
	mount -t rootfs -o remount,rw rootfs;
	mount -o remount,rw /system;
	mount -o remount,rw /data;
	mount -o remount,rw /;


#--------------------------------------
# Make internal storage directory.
#--------------------------------------
    if [ ! -d $DATA_PATH ]; then
	    mkdir $DATA_PATH;
    fi;

	chmod 0777 $DATA_PATH;
	chown 0.0 $DATA_PATH;

#-------------------------
# FAKE KNOX 0
#-------------------------

	/sbin/resetprop -v -n ro.boot.warranty_bit "0"
	/sbin/resetprop -v -n ro.warranty_bit "0"
	echo $(date) "Enabled Fake Knox 0" >> $fivanbe_LOGFILE


#-------------------------
# FLAGS FOR SAFETYNET
#-------------------------

	/sbin/resetprop -n ro.boot.veritymode "enforcing"
	/sbin/resetprop -n ro.boot.verifiedbootstate "green"
	/sbin/resetprop -n ro.boot.flash.locked "1"
	/sbin/resetprop -n ro.boot.ddrinfo "00000001"
	echo $(date) "Enabled Flags for safety net" >> $fivanbe_LOGFILE


#-------------------------
# TWEAKS
#-------------------------

    # SD-Card Readhead
    echo "2048" > /sys/devices/virtual/bdi/179:0/read_ahead_kb;

    # Internet Speed
    echo "0" > /proc/sys/net/ipv4/tcp_timestamps;
    echo "1" > /proc/sys/net/ipv4/tcp_tw_reuse;
    echo "1" > /proc/sys/net/ipv4/tcp_sack;
    echo "1" > /proc/sys/net/ipv4/tcp_tw_recycle;
    echo "1" > /proc/sys/net/ipv4/tcp_window_scaling;
    echo "5" > /proc/sys/net/ipv4/tcp_keepalive_probes;
    echo "30" > /proc/sys/net/ipv4/tcp_keepalive_intvl;
    echo "30" > /proc/sys/net/ipv4/tcp_fin_timeout;
    echo "404480" > /proc/sys/net/core/wmem_max;
    echo "404480" > /proc/sys/net/core/rmem_max;
    echo "256960" > /proc/sys/net/core/rmem_default;
    echo "256960" > /proc/sys/net/core/wmem_default;
    echo "4096,16384,404480" > /proc/sys/net/ipv4/tcp_wmem;
    echo "4096,87380,404480" > /proc/sys/net/ipv4/tcp_rmem;

	echo $(date) "Enabled tweaks" >> $fivanbe_LOGFILE


#-------------------------
# KERNEL INIT VALUES
#-------------------------


#--------------------------------------
# Unmount
#--------------------------------------
	mount -t rootfs -o remount,ro rootfs;
	mount -o remount,ro /system;
	mount -o remount,rw /data;
	mount -o remount,ro /;
