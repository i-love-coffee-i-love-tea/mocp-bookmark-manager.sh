#!/bin/sh
#
# Author: Steffen Kremsler <mocp-bookmark-manager@gobuki.org>
# Date:   Feb. 4th, 2020
# License: GPL 2
#
# Manages audio file bookmarks in combination with the fabulous
# mocp commmand line audio player. 
#
# Developed on Ubuntu 19.10 with the following versions
#    mocp 2.6-alpha3
#    dash 0.5.10
#    GNU Awk 4.2.1
#    GNU coreutils 8.30 (mv, cut, sort, uniq)
#    GNU grep 3.3

BOOKMARKS_FILE="/home/gobuki/Radio_X/bookmarks.csv"

# full paths to all used shell utils
# the only other command used in this script is /bin/mv 
MOCP=/usr/bin/mocp
GREP=/bin/grep
AWK=/usr/bin/awk
CUT=/usr/bin/cut
UNIQ=/usr/bin/uniq
SORT=/usr/bin/sort

FIELD_ID=1
FIELD_FILE=2
FIELD_POS=3
FIELD_CREATED=4
FIELD_COMMENT=5

display_bookmark() {
	CSV_LINE="$1"
	printf "\t%12s %s\n" "Index:" "$(echo "$CSV_LINE" | $CUT -f$FIELD_ID -d';')"
	printf "\t%12s %s\n" "File:" "$(echo "$CSV_LINE" | $CUT -f$FIELD_FILE -d';')"
	printf "\t%12s %s\n" "Position:" "$(echo "$CSV_LINE" | $CUT -f$FIELD_POS -d';')"
	printf "\t%12s %s\n" "Created:" "$(echo "$CSV_LINE" | $CUT -f$FIELD_CREATED -d';')"
	printf "\t%12s %s\n" "Comment:" "$(echo "$CSV_LINE" | $CUT -f$FIELD_COMMENT -d';')"
}

list_all_bookmarks() {
	AUDIO_FILES="$($CUT -f2 -d';' ${BOOKMARKS_FILE} | $SORT | $UNIQ)"
	while read AUDIO_FILE; do
	        list_file_bookmarks "$AUDIO_FILE"
	done <<EOF
$AUDIO_FILES
EOF
}

list_file_bookmarks() {
	AUDIO_FILE="$1"
	echo bookmarks for $AUDIO_FILE
	# sorted by timestamp position
	$SORT -nk3 -t';' "${BOOKMARKS_FILE}" | $GREP "${AUDIO_FILE}" | $AWK -F';' '{printf "%3d at %02dh:%02dm:%02ds\t%s\t%s\n", $1, $3/(60*60), $3%(60*60)/60, $3%60, $4, $5}'
}

list_playing_file_bookmarks() {
	PLAYING_FILE=$($MOCP -Q "%file")
	list_file_bookmarks "$PLAYING_FILE"
}

jump_to_bookmark_by_index() {
	BOOKMARK_INDEX=$1
	BOOKMARK_POSITION=$($GREP "^${BOOKMARK_INDEX};" "${BOOKMARKS_FILE}" | $AWK -F';' '{print $3}')
	echo jumping to bookmark $BOOKMARK_INDEX at position $BOOKMARK_POSITION
	$MOCP -j ${BOOKMARK_POSITION}s
}

bookmark_playing_position() {
	COMMENT="$1"
	NEXT_INDEX=$(expr $($AWK -F';' "\$1>max{max=\$1;r=\$1}END{print r}" "$BOOKMARKS_FILE") + 1)
	NEW_BOOKMARK_LINE=$($MOCP -Q "$NEXT_INDEX;%file;%cs;$(date +%c);$COMMENT")
	echo "Adding bookmark"
	display_bookmark "$NEW_BOOKMARK_LINE"
	# append bookmark to file
	echo "${NEW_BOOKMARK_LINE}" >> "${BOOKMARKS_FILE}"
	# sort file after appending the new bookmark
	$SORT "${BOOKMARKS_FILE}" > /tmp/bookmarks.sorted
	# replace bookmarks file with new file, if it isn't empty
	[ -s /tmp/bookmarks.sorted ] && /bin/mv /tmp/bookmarks.sorted "${BOOKMARKS_FILE}"
}

remove_bookmark_by_index() {
	BOOKMARK_INDEX=$1
	echo deleting bookmark
	$GREP "^${BOOKMARK_INDEX};" "${BOOKMARKS_FILE}"
	$GREP -v -e "^${BOOKMARK_INDEX};" "${BOOKMARKS_FILE}" > /tmp/bookmarks.after.delete
	if [ "$?" -eq "0" ]; then
	        /bin/mv /tmp/bookmarks.after.delete "${BOOKMARKS_FILE}"
	else
	        echo "failed to delete bookmark"
	fi
}

while [ $# -gt 0 ]; do
	if [ "$1" = "list" ]; then
		list_all_bookmarks	
		exit 0
	elif [ "$1" = "remove" ]; then
		if [ ! -z "$2" ]; then
			remove_bookmark_by_index $2
			exit 0
		fi
	elif [ "$1" = "add" ]; then
		bookmark_playing_position "$2"
		exit 0
	elif [ "$1" = "go" ]; then
		jump_to_bookmark_by_index $2
		exit 0
	elif [ "$1" = "listp" ]; then
		list_playing_file_bookmarks
		exit 0
	elif [ "$1" = "show" ]; then
		if [ ! -z "$2" ]; then
			BOOKMARK_INDEX=$2
			display_bookmark $($GREP "^${BOOKMARK_INDEX};" "${BOOKMARKS_FILE}")
			exit 0
		fi
	elif [ "$1" = "csv" ]; then
		cat "${BOOKMARKS_FILE}"
		exit 0
	fi
	shift
done

echo "usage: $0 <command>"
echo
echo "  the following commands are available:"
echo "  -------------------------------------"
printf "  %-25s %s\n" "add [comment]" "bookmark the current mocp playing position"
printf "  %-25s %s\n" "" "with an optional comment"
echo
printf "  %-25s %s\n" "go <bookmark_index>" "jump to the bookmark playing position"
printf "  %-25s %s\n" "" "the file containing the bookmark must be playing in mocp"
echo
printf "  %-25s %s\n" "show <bookmark_index>" "show bookmark details"
echo
printf "  %-25s %s\n" "remove <bookmark_index>" "remove a bookmark"
echo
printf "  %-25s %s\n" "list" "list all bookmarks by file"
echo
printf "  %-25s %s\n" "listp" "list playing file bookmarks"
echo
printf "  %-25s %s\n" "csv" "outputs the bookmarks csv database to the terminal"
echo
printf "  %-25s %s\n" "" "columns:"
printf "  %-25s %s\n" "" "  bookmark index" 
printf "  %-25s %s\n" "" "  filename" 
printf "  %-25s %s\n" "" "  position (seconds)" 
printf "  %-25s %s\n" "" "  bookmark creation date" 
printf "  %-25s %s\n" "" "  comment" 

