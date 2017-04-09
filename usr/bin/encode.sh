#!/bin/bash

# logs the process here
LOGFILE=./actual.txt
TEMPFILE=./temp.mp4
TASK_LIST=./list.txt
SEARCHDIR="$1"
EXTENSIONS=".*\.\(avi\|mpg\|mp4\|mov\)$"

X264_POST=_x264
X265_POST=_x265
PROCESS_MARKERS="enc $X264_POST $X265_POST"
X264_ENCODE_OPTIONS="-c:v libx264 -preset veryslow -crf 20 -tune film -c:a aac -strict experimental -ab 128k -movflags faststart"
X265_ENCODE_OPTIONS="-c:v libx265 -preset slow -crf 20 -c:a aac -strict experimental -ab 128k -movflags faststart"
SUBDIR=encode
LOG_DATE_FORMAT="+%Y-%m-%d_%H:%M:%S"

rm -f $LOGFILE
rm -f $TEMPFILE
rm -f $TASK_LIST

# -----
# $1 - codec
# $2 - absolute input file
# $3 - absolute output file
# -----
function encode {
if [ -f "$3" ]; then
	echo "$3" has been already transcoded >> $LOGFILE
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
	  echo "Unknown codec: "$1
	  echo "Unknown codec: "$1 >> $LOGFILE
	exit -1
esac
echo  `date $LOG_DATE_FORMAT` Transcoding $2 - $1 >> $LOGFILE
FFMPEG="ffmpeg -y -i"
COMMAND="$FFMPEG \"$2\" $ENCODE_OPTIONS $TEMPFILE"
echo $COMMAND
sh -c $COMMAND

local ret=$?
if [ $ret -ne 0 ];then
	echo failed
	echo failed >> $LOGFILE
	return $ret
fi
}

function move_temp {
if [ ! -d `dirname "$1"` ]; then
	mkdir `dirname "$1"`
fi
mv "$TEMPFILE" "$1"
}

function encode_test {
case "$1" in
	$X264_POST)
		ENCODE_OPTIONS=$X264_ENCODE_OPTIONS
	;;
	$X265_POST)
		ENCODE_OPTIONS=$X265_ENCODE_OPTIONS
	;;
*)
	  echo "Unknown codec: "$1
	  echo "Unknown codec: "$1 >> $LOGFILE
	exit -1
esac
echo ffmpeg -y -i "$2" $ENCODE_OPTIONS $TEMPFILE
}

# collect all videos within the input directory
OIFS=$IFS
NIFS=$'\n'
IFS=$NIFS
#find $SEARCHDIR  -iregex $EXTENSIONS -print0 | while IFS= read -r -d '' video
#find $SEARCHDIR  -iregex $EXTENSIONS -print0 | while read -d '' -r video
x=0
for video in `find $SEARCHDIR -iregex $EXTENSIONS -print0 | xargs -0 -I f echo f`
do
	encoding_needed=true
	IFS=$OIFS
	for marker in $PROCESS_MARKERS 
	do
		if [[ $video == *$marker* ]]; then
			echo Skipping: $video  >> $LOGFILE
			encoding_needed=false
		fi
	done
	if [[ $encoding_needed == "true" ]]; then
		FILES[$x]=$video
		((x+=1))
	fi
done

#( set -o posix ; set ) | grep FILES

# print/write out the found videos
IFS=$NOFS
for t in ${FILES[*]}
do
	echo $t | tee $TASK_LIST
done
read -n1 -r -p "Press a key to continue..." key

# prepare the output filenames and start the encoding 
for POST in $X264_POST $X265_POST
do
	for v in ${FILES[*]}
	do
		videofile="$v"
		fname=`basename $videofile .mp4`
		targetdir=`dirname $videofile`/$SUBDIR
#		targetdir=/mnt/data/tmp
		targetfile=$targetdir/$fname$POST".mp4"
 		encode $POST $videofile $targetfile
		ret=$?
		if [ ! $ret -ne 0 ]; then
			move_temp $targetfile
			touch -r $videofile "$targetfile"
			echo "done" >> "$LOGFILE"
		else
			echo "failed" >> "$LOGFILE"
fi
	done
done
