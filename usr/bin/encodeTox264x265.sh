#!/bin/bash

# logs the process here
LOGFILE=./actual.txt
TEMPFILE=./temp.mp4
TASK_LIST=./list.txt
SEARCHDIR=$1
X264_POST=_x264
X265_POST=_x265
PROCESS_MARKERS="enc $X264_POST $X265_POST"
X264_ENCODE_OPTIONS="-c:v libx264 -preset veryslow -crf 20 -tune film -c:a copy -movflags faststart"
X265_ENCODE_OPTIONS="-c:v libx265 -preset slow -crf 20 -c:a copy -movflags faststart"
SUBDIR=encode
LOG_DATE_FORMAT="+%Y-%m-%d_%H:%M:%S"

rm $LOGFILE
rm $TEMPFILE
rm $TASK_LIST
x=0

function encode {
if [ -f $3 ]; then
	echo $3 is already complete >> $LOGFILE
	return
fi

case "$1" in
	$X264_POST)
		ENCODE_OPTIONS=$X264_ENCODE_OPTIONS
	;;
	$X265_POST)
		ENCODE_OPTIONS=$X265_ENCODE_OPTIONS
	;;
*)
	  echo "Unknown encode method: "$1
esac
ffmpeg -y -i $2 $ENCODE_OPTIONS temp.mp4
echo  `date $LOG_DATE_FORMAT` Processing $2 - $1 >> $LOGFILE
#echo "ffmpeg -y -i $2 $ENCODE_OPTIONS $TEMPFILE"
if [ ! -d `dirname $3` ]; then
	mkdir `dirname $3`
fi
mv $TEMPFILE $3
touch -r $2 $3
}


for video in `find $SEARCHDIR -name '*.mp4'`
do
	encoding_needed=true
	for marker in $PROCESS_MARKERS 
	do
		if [[ $video == *$marker* ]]; then
			#echo Skipping... $video
			encoding_needed=false
		fi
	done
	if [[ $encoding_needed == "true" ]]; then
		FILES[$x]=$video
		((x+=1))
	fi
done

for t in ${FILES[*]}
do
	echo $t >> $TASK_LIST
done

for POST in $X264_POST $X265_POST
do
	for v in ${FILES[*]}
	do
		fname=`basename $v .mp4`
		targetdir=`dirname $v`/$SUBDIR
#		targetdir=/mnt/data/tmp
		targetfile=$targetdir/$fname$POST".mp4"
 		encode $POST $v $targetfile
	done
done
