#!/bin/sh

CUBESTATS_GAMES="assaultcube"
CUBESTATS_LOGDIRS="logs finished_logs archive_logs"
CUBESTATS_DIRS="logs run localconf"
CUBESTATS_DEPLOY_DIRS="scripts config bin"

if [ ! -d ${CUBESTATS_ROOT} ]; then
	mkdir ${CUBESTATS_ROOT}
fi

for game in ${CUBESTATS_GAMES}
do
	if [ ! -d ${CUBESTATS_ROOT}/${game} ]; then
		for logdir in ${CUBESTATS_LOGDIRS}
		do
			echo Making dir ${CUBESTATS_DEPLOY}/${game}/${logdir}...
			mkdir ${CUBESTATS_DEPLOY}/${game}/${logdir}
		done
		mv ${CUBESTATS_DEPLOY}/${game} ${CUBESTATS_ROOT}/${game}
	fi
done

for dir in ${CUBESTATS_DIRS}
do
	if [ ! -d ${CUBESTATS_ROOT}/${dir} ]; then
		mkdir ${CUBESTATS_ROOT}/${dir}
	fi
done

echo ..........SWITCHING..............
for dir in ${CUBESTATS_DEPLOY_DIRS}
do
	if [ -d ${CUBESTATS_DEPLOY}/${dir} ]; then
		mv ${CUBESTATS_ROOT}/${dir} ${CUBESTATS_ROOT}/${dir}-$( date +%y%m%d%H%M%S )
		mv ${CUBESTATS_DEPLOY}/${dir} ${CUBESTATS_ROOT}/${dir}
	fi
done
echo ............done.................

if [ ! -f ${CUBESTATS_ROOT}/localconf/daemoncontroller.xml ]; then
	echo Installing empty xmlconfig...
	echo \<moosex\>\</moosex\> >${CUBESTATS_ROOT}/localconf/daemoncontroller.xml
fi

echo Installing new crontab...
crontab ${CUBESTATS_ROOT}/scripts/server/crontab

chmod 755 ${CUBESTATS_ROOT}/scripts/server/cron_daemoncontroller.sh

echo Displaying crontab:
crontab -l

echo .........................................
echo ............TOTALLY DONE.................
echo .........................................
