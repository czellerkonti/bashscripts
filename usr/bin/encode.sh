#!/bin/bash

# logs the process here
LOGFILE=/mnt/data/actual.txt
TEMPFILE=/mnt/data/temp.mp4
TASK_LIST=/mnt/data/list.txt
SEARCHDIR="$1"
EXTENSIONS=".*\.\(avi\|mpg\|mp4\|mov\)$"
FFMPEG=ffmpeg
EXTRAOPTS="-v info -y"

SUBDIR=encode
LOG_DATE_FORMAT="+%Y-%m-%d_%H:%M:%S"

declare -A CODECS
CODECS["mp3"]="-c:v copy -c:a libmp3lame -q:a 5"
CODECS["x264"]="-c:v libx264 -preset veryslow -crf 20 -tune film -c:a aac -strict experimental -ab 128k -movflags faststart"
CODECS["x265"]="-c:v libx265 -preset slow -crf 20 -c:a aac -strict experimental -ab 128k -movflags faststart"
declare -A POSTS
POSTS["mp3"]="_mp3"
POSTS["x264"]="_x264"
POSTS["x265"]="_x265"
PROCESS_MARKERS="enc ${!POSTS[@]}"

if [ -z "$2" ]; then
	SELECTED_CODECS="${!CODECS[@]}"
else
	SELECTED_CODECS=$2
fi

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

	if [ ! ${CODECS[$1]+_} ]; then
		echo Unknown codec: \"$1\" not in ${!CODECS[@]} | tee -a $LOGFILE
		exit -1
	fi

	ENCODE_OPTIONS=${CODECS[$1]}

	echo  `date $LOG_DATE_FORMAT` Transcoding $2 - $1 >> $LOGFILE
	COMMAND="$FFMPEG $EXTRAOPTS -i \"$2\" $ENCODE_OPTIONS $TEMPFILE"
	echo $COMMAND
	sh -c $COMMAND

	local ret=$?
	if [ $ret -ne 0 ]; then
		echo failed | tee -a $LOGFILE
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
	if [ ${CODECS[$1]+_} ]; then
		echo Unknown codec "$1" | tee -a $LOGFILE
		exit -1
	fi

	ENCODE_OPTIONS=${CODECS[$1]}

	echo  `date $LOG_DATE_FORMAT` Transcoding $2 - $1 >> $LOGFILE
	COMMAND="$FFMPEG -y -i \"$2\" $ENCODE_OPTIONS $TEMPFILE"
	echo $COMMAND
}

function collect_videos {
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
}

#( set -o posix ; set ) | grep FILES

# print/write out the found videos
function print_tasklist {
	for t in "${FILES[@]}"
	do
		echo $t | tee -a $TASK_LIST
	done
}


function process_folder {
	# prepare the output filenames and start the encoding
	for c in "${SELECTED_CODECS}"
	do
		for v in "${FILES[@]}"
		do
			process_video "$v" "$c"
		done
	done
}

# ----
# $1 - video file
# $2 - codec option
# ----
function process_video {
	IFS=
	videofile="$1"
	CODEC=$2
	POST=${POSTS[$CODEC]}

	fname=`basename "$videofile" .mp4`
	targetdir=`dirname "$videofile"`/$SUBDIR
	targetfile=$targetdir/"$fname"$POST".mp4"
	encode $CODEC "$videofile" "$targetfile"
	ret=$?
	if [ ! $ret -ne 0 ]; then
		move_temp $targetfile
		touch -r $videofile "$targetfile"
		echo "done" >> "$LOGFILE"
	else
		echo "failed to transcode" >> "$LOGFILE"
	fi
}

echo "Selected codecs: "$SELECTED_CODECS

if [[ -f "$1" ]]; then
	echo "File processing: \"$1\"" | tee -a $LOGFILE
	for c in "${SELECTED_CODECS}"
	do
		process_video "$1" "$c"
	done
fi
if [[ -d "$1" ]]; then
	echo "Folder processing: $1" |tee -a $LOGFILE
	collect_videos
	print_tasklist
	read -n1 -r -p "Press a key to continue..." key
	process_folder
fi
