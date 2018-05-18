#!/bin/bash
#
# Kimberly Decker
# Tue May 17 2018

# BASH script to manage and run antivirus: Clamscan
#    - run freshclam to download and update signature files once per day
#    - evaluate age of signature files; send text if older than 24 hours
#    - check to see if freshclam running; don't run if already active process
#    - run clamscan once per day
# 
# Note: freshclam runs by default, 24X/day, to update signatures
# To disable:
#    - change /etc/clamav/freshclam.conf > Checks 0
#    - ran dpkg-reconfigure clamav-freshclam & changed to manual updates
#
#
# Check for root privileges

if [[ $EUID -ne 0 ]]; then
   echo "Virus scan; only root can do that" 1>&2
   exit 1
fi

# Prepare virus scan log

sudo rm -f /var/log/virus_scan.log
sudo touch /var/log/virus_scan.log

# Evaluate whether freshclam already running
# Kill any running processes

case "$(pidof freshclam | wc -w)" in

0)  echo "all ok" 
    ;;

1)  echo "Active freshclam process."
    echo "Killing freshclam process... $(date)" >> /var/log/freshclam.txt
    kill $(pidof freshclam | awk '{print $1}')
    ;;

esac

# Update virus signatures
# Evaluate whether signatures are older than 24 hours

DAILY=$(stat --format=%Y /var/lib/clamav/daily.cld)
NOW=`date +%s`
DIFF=$(echo $NOW - $DAILY | bc)

if [ $DIFF -ge 86400 ]; then
   
   # Start freshclam signature update
   # Send text alert 
   echo "Upating virus signatures... "
   sudo freshclam
   return_code=$?

   # Evaluate success of signature update
   # If failed, display return_code and exit

   if [ $return_code -ne 0 ]; then
      echo ""; echo "Failed to update virus signatures... Scan aborted."; echo ""
      exit $return_code
   fi

fi

# Complete virus scan

echo "Update completed. Commencing virus scan... (this may take a while)"
sudo clamscan -r / --log='/var/log/virus_scan.log' --exclude='^/var/log/virus_scan\.log$' \ --exclude-dir='^/sys|^/proc|^/mnt|^/media|^/dev' \
return_code=$?

# Display virus scan status

if [ $return_code -ne 0 ] && [ $return_code -ne 1 ]; then
   echo ""; echo "Failed to complete virus scan"; echo ""
else
   echo ""; echo -n "Virus scan completed successfully."
   if sudo grep -rl 'Infected files: 0' /var/log/virus_scan.log > /dev/null 2>&1; then
      echo "NO INFECTIONS FOUNDS"; echo ""
   else
      echo "INFECTIONS FOUND"; echo ""
   fi
fi
