#!/bin/bash
#
# Author: Steffen Kremsler <mocp-bookmark-manager@gobuki.org>
# Date:   Feb. 4th, 2020
# License: GPL 2
# Version: 0.9
#
# Manages audio file bookmarks in combination with the fabulous
# mocp commmand line audio player. 
#
# Developed on Ubuntu 19.10 with the following versions
#    mocp 2.6-alpha3
#    dash 0.5.10
#    GNU Awk 4.2.1
#    GNU coreutils 8.30 (mv, cat, cut, sort, uniq)
#    GNU grep 3.3
#
#
# Changelog: 
#
#    Version 0.8
#       - Rating field added. Must be a number.
#         Should be between 1 and 5.
#	- Added commands 'rating' and 'comment' to
#         set these fields
#       - Updated the 'add' command to accept and
#         optional rating at the first position when
#         it is called with two arguments
#
#    Version 0.9
#       - Implemented output filtering by rating or comment
#       - Added 'first', 'next', 'previous' and 'last' commands
#         to jump to a bookmark in the playing file
#         'next' and 'previous' will jump to the first bookmark,
#         if there was no previous jump (recorded in /tmp/last_bookmark_jump)
#       - Commands can be entered in a short version or as
#         readable commands. If the command input is unambigous
#         it will be replaced by the full command internally.
#       - Added support fort bash completions
#       - Reformatted usage output to make it parseable for available commands
#         to enable better integration with completions (completion script
#         doesn't have to be updated, when the bookmark manager script evolves.
#       - Formatted timestamp displayed when jumping to bookmarks

BOOKMARKS_FILE="/home/gobuki/Radio_X/bookmarks.csv"

# full paths to all used shell utils
# the only other command used in this script is /bin/mv 
MOCP=/usr/bin/mocp
GREP=/bin/grep
AWK=/usr/bin/awk
CUT=/usr/bin/cut
UNIQ=/usr/bin/uniq
SORT=/usr/bin/sort
CAT=/bin/cat
BASE64=/usr/bin/base64
GUNZIP=/bin/gunzip

FIELD_ID=1
FIELD_FILE=2
FIELD_POS=3
FIELD_CREATED=4
FIELD_RATING=5
FIELD_COMMENT=6

RED="\033[1;31m"
BLUE="\033[1;34m"
CYAN="\033[1;36m"
GREEN="\033[0;32m"
RESET="\033[0;0m"
BOLD="\033[;1m"
REVERSE="\033[;7m"

display_bookmark() {
	CSV_LINE="$1"
	printf "\t%12s %s\n" "Index:" "$(echo "$CSV_LINE" | $CUT -f$FIELD_ID -d';')"
	printf "\t%12s %s\n" "File:" "$(echo "$CSV_LINE" | $CUT -f$FIELD_FILE -d';')"
	printf "\t%12s %s\n" "Position:" "$(echo "$CSV_LINE" | $CUT -f$FIELD_POS -d';' | $AWK '{printf "%02dh:%02dm:%02ds", $1/(60*60), $1%(60*60)/60, $1%60}')"
	printf "\t%12s %s\n" "Created:" "$(echo "$CSV_LINE" | $CUT -f$FIELD_CREATED -d';')"
	printf "\t%12s %s\n" "Rating:" "$(format_rating $(echo "$CSV_LINE" | $CUT -f$FIELD_RATING -d';'))"
	printf "\t%12s %s\n" "Comment:" "$(echo "$CSV_LINE" | $CUT -f$FIELD_COMMENT -d';')"
}

list_all_bookmarks() {
	AUDIO_FILES="$($CUT -f2 -d';' ${BOOKMARKS_FILE} | $SORT | $UNIQ)"
	while read AUDIO_FILE; do
	        list_file_bookmarks "$AUDIO_FILE"
		echo
	done <<EOF
$AUDIO_FILES
EOF
}

list_file_bookmarks() {
	AUDIO_FILE="$1"
	FILTER_COLUMN=$2
	FILTER="$3"
	PLAYING_FILE=$($MOCP -Q "%file")
	if [ "$AUDIO_FILE" = "$PLAYING_FILE" ]; then
		echo -e bookmarks for $AUDIO_FILE "${COLOR_GREEN}" '< < <   N O W   P L A Y I N G'
		echo | awk "{print substr(\"===========================================================================================================================================================================================================================================================================================================\", 0, $COLUMNS)}"
	        echo -e "${COLOR_RESET}"
	else
		echo bookmarks for $AUDIO_FILE
	fi


	# filter by rating
	if [ "$FILTER_COLUMN" = "5" ]; then
		$SORT -nk$FIELD_POS -t';' "${BOOKMARKS_FILE}" | $GREP "${AUDIO_FILE}" \
			| $AWK -F';' "\$$FILTER_COLUMN>=$FILTER {printf \"%3d at %02dh:%02dm:%02ds\t%s\t%s\t%s\n\", \
		       	\$1, \$3/(60*60), \$3%(60*60)/60, \$3%60, \$4, substr(\"*******\", 1, \$5), \$6}"
        # filter by comment
	elif [ "$FILTER_COLUMN" = "6" ]; then
		$SORT -nk$FIELD_POS -t';' "${BOOKMARKS_FILE}" | $GREP "${AUDIO_FILE}" \
			| $AWK -F';' "\$$FILTER_COLUMN ~ /$FILTER/ {printf \"%3d at %02dh:%02dm:%02ds\t%s\t%s\t%s\n\", \
		       	\$1, \$3/(60*60), \$3%(60*60)/60, \$3%60, \$4, substr(\"*******\", 1, \$5), \$6}"
	# diplay unfiltered
	elif [ -z "$FILTER_COLUMN" ]; then
		$SORT -nk$FIELD_POS -t';' "${BOOKMARKS_FILE}" | $GREP "${AUDIO_FILE}" \
			| $AWK -F';' '{printf "%3d at %02dh:%02dm:%02ds\t%s\t%s\t%s\n", \
		       	$1, $3/(60*60), $3%(60*60)/60, $3%60, $4, substr("*******", 1, $5), $6}'
	fi
}

list_playing_file_bookmarks() {
	PLAYING_FILE=$($MOCP -Q "%file")
	list_file_bookmarks "$PLAYING_FILE"
	echo Current position in file: $($MOCP -Q "%ct - %tt")
}

bookmark_exists() {
	BOOKMARK_INDEX=$1
	RET=1
	if [ "${BOOKMARK_INDEX}x" != "x" ]; then
		$GREP "^${BOOKMARK_INDEX};" "${BOOKMARKS_FILE}" >> /dev/null
		RET=$?
	fi
	if [ "$RET" -ne "0" ]; then
		echo "Bookmark with index=${BOOKMARK_INDEX} doesn't exist"
	fi
	return $RET
}
jump_to_bookmark_by_index() {
	BOOKMARK_INDEX=$1
	BOOKMARK_POSITION=$($GREP "^${BOOKMARK_INDEX};" "${BOOKMARKS_FILE}" | $AWK -F';' '{print $3}')
	if bookmark_exists $BOOKMARK_INDEX; then
		POS="$BOOKMARK_POSITION"
		echo Jumping to bookmark $BOOKMARK_INDEX at position $(echo $POS | awk '{printf "%02dh:%02dm:%02ds",  $1/(60*60), $1%(60*60)/60, $1%60}')
		PLAYING_FILE=$($MOCP -Q "%file")
		BOOKMARK_FILE=$($GREP "^${BOOKMARK_INDEX};" "${BOOKMARKS_FILE}" | $AWK -F';' '{print $2}')
		if [ "$PLAYING_FILE" != "$BOOKMARK_FILE" ]; then
			echo "Bookmark is in a different file (not currently playing)"
			echo "\tplaying : $PLAYING_FILE"
			echo "\tbookmark: $BOOKMARK_FILE"
			if $MOCP -l "${BOOKMARK_FILE}"; then
				sleep .1
				echo "Playing bookmark file now"
			else
				echo "Error playing bookmark file"
			fi
			
		fi

		echo $BOOKMARK_INDEX > /tmp/last_bookmark_jump
		$MOCP -j ${BOOKMARK_POSITION}s
	fi
}
get_rating_by_index() {
	BOOKMARK_INDEX=$1
	RATING=$($GREP "^${BOOKMARK_INDEX};" "${BOOKMARKS_FILE}" | $AWK -F';' '{print $5}')
	echo $RATING
}

jump_to_first_bookmark_in_file() {
	PLAYING_FILE=$($MOCP -Q "%file")
	FIRST_BOOKMARK=$($GREP "$PLAYING_FILE" "$BOOKMARKS_FILE" | $AWK -F';' "{print \$$FIELD_ID}" | $SORT | head -n1)
	jump_to_bookmark_by_index $FIRST_BOOKMARK
}

jump_to_previous_bookmark_in_file() {
	if [ -s /tmp/last_bookmark_jump ]; then
		LAST_BOOKMARK_INDEX=$(cat /tmp/last_bookmark_jump)
		# find next bookmark index
		PLAYING_FILE=$($MOCP -Q "%file")
		if [ -z "$LAST_BOOKMARK_INDEX" ]; then
			echo "no previous jump" 
			jump_to_first_bookmark_in_file
		else
			echo "previously jumped to bookmark $LAST_BOOKMARK_INDEX"
			echo "trying to find a bookmark with lower index in the file"
			NEXT_LOWER_INDEX_IN_FILE=$($GREP "$PLAYING_FILE" "$BOOKMARKS_FILE" | $AWK -F';' "{print \$$FIELD_ID}" | $SORT | $GREP ^$LAST_BOOKMARK_INDEX\$ -B1 | head -n1)
			if [ "x$NEXT_LOWER_INDEX_IN_FILE" != "x" ]; then
				echo "lower index found: $NEXT_LOWER_INDEX_IN_FILE"
				jump_to_bookmark_by_index $NEXT_LOWER_INDEX_IN_FILE
			else
				echo "next lower index not found"
				jump_to_first_bookmark_in_file
			fi
		fi
	else
		jump_to_first_bookmark_in_file
	fi
}

jump_to_next_bookmark_in_file() {
	if [ -s /tmp/last_bookmark_jump ]; then
		LAST_BOOKMARK_INDEX=$(cat /tmp/last_bookmark_jump)
		PLAYING_FILE=$($MOCP -Q "%file")
		if [ -z "$LAST_BOOKMARK_INDEX" ]; then
			jump_to_first_bookmark_in_file
		else
			NEXT_HIGHEST_INDEX_IN_FILE=$($GREP "$PLAYING_FILE" "$BOOKMARKS_FILE" | $AWK -F';' "{print \$$FIELD_ID}" | $SORT | $GREP ^$LAST_BOOKMARK_INDEX\$ -A1 | tail -n1)
			if [ ! -z "$NEXT_HIGHEST_INDEX_IN_FILE" ]; then
				jump_to_bookmark_by_index $NEXT_HIGHEST_INDEX_IN_FILE
			else
				jump_to_first_bookmark_in_file
			fi
		fi
	else
		jump_to_first_bookmark_in_file
	fi
}

jump_to_last_bookmark_in_file() {
	PLAYING_FILE=$($MOCP -Q "%file")
	LAST_BOOKMARK=$($GREP "$PLAYING_FILE" "$BOOKMARKS_FILE" | $AWK -F';' "{print \$$FIELD_ID}" | $SORT | tail -n1)
	jump_to_bookmark_by_index $LAST_BOOKMARK
}

jump_to_random_bookmark() {
	MIN_RATING=$1

	# randomly choose item from filtered list
	AUDIO_FILES="$($AWK -F';' "\$$FIELD_RATING>=$RATING {print \$0}" "${BOOKMARKS_FILE}" | $CUT -f$FIELD_FILE -d';' | $SORT | $UNIQ)"
	while read AUDIO_FILE; do
	        list_file_bookmarks "$AUDIO_FILE" $FIELD_RATING $MIN_RATING
		echo
	done <<EOF
$AUDIO_FILES
EOF
	# an idea
	return 1
}

bookmark_playing_position() {
	if [ ! -z "$2" ]; then
		RATING=$1
		COMMENT="$2"
	else 
		COMMENT="$1"
	fi

	NEXT_INDEX=$(expr $($AWK -F';' "\$1>max{max=\$1;r=\$1}END{print r}" "$BOOKMARKS_FILE") + 1)
	NEW_BOOKMARK_LINE=$($MOCP -Q "$NEXT_INDEX;%file;%cs;$(date +%c);$RATING;$COMMENT")
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
	if bookmark_exists $BOOKMARK_INDEX; then
		echo Deleting bookmark
		$GREP -v -e "^${BOOKMARK_INDEX};" "${BOOKMARKS_FILE}" > /tmp/bookmarks.after.delete
		if [ "$?" -eq "0" ]; then
		        /bin/mv /tmp/bookmarks.after.delete "${BOOKMARKS_FILE}"
		fi
	fi
}

filter_bookmarks_by_rating() {
	RATING=$1
	AUDIO_FILES="$($AWK -F';' "\$5>=$RATING {print \$0}" "${BOOKMARKS_FILE}" | $CUT -f$FIELD_FILE -d';' | $SORT | $UNIQ)"
	while read AUDIO_FILE; do
	        list_file_bookmarks "$AUDIO_FILE" 5 $1
		echo
	done <<EOF
$AUDIO_FILES
EOF
}
filter_bookmarks_by_comment() {
	COMMENT="$1"
	AUDIO_FILES="$($AWK -F';' "\$$FIELD_COMMENT ~ /$COMMENT/ {print \$0}" "${BOOKMARKS_FILE}" | $CUT -f$FIELD_FILE -d';' | $SORT | $UNIQ)"
	while read AUDIO_FILE; do
		list_file_bookmarks "$AUDIO_FILE" $FIELD_COMMENT "$COMMENT"
		echo
	done <<EOF
$AUDIO_FILES
EOF
}

set_field() {
	BOOKMARK_INDEX=$1
	FIELD_NO=$2
	VALUE="$3"
	if bookmark_exists $BOOKMARK_INDEX; then
		CSV_LINE=$($GREP "^${BOOKMARK_INDEX};" "${BOOKMARKS_FILE}")
		if [ "$FIELD_NO" = "$FIELD_RATING" ]; then
			LINE_START="$(echo "$CSV_LINE" | $AWK -F';' '{print $1";"$2";"$3";"$4}')";
		elif [ "$FIELD_NO" = "$FIELD_COMMENT" ]; then
			LINE_START="$(echo "$CSV_LINE" | $AWK -F';' '{print $1";"$2";"$3";"$4";"$5}')";
		fi
		PREV_RATING=$($GREP "^${BOOKMARK_INDEX};" "${BOOKMARKS_FILE}" | $AWK -F';' '{print $5}')
		sed -i.backup "s|${LINE_START};${PREV_RATING}|${LINE_START}${VALUE};|g" "${BOOKMARKS_FILE}"
	fi
}

set_rating() {
	BOOKMARK_INDEX=$1
	RATING=$2
	echo Updating rating to $VALUE
	set_field $BOOKMARK_INDEX 5 $RATING
}


# converts a numeric rating to a string with <value> amount of stars
# examples:
# 1 -> *
# 5 -> *****
format_rating() {
	RATING=$1
	if [ ! -z "$RATING" ]; then
		while read CHAR; do
			printf "%0s" "*" 
		done <<EOF
$(seq 1 $RATING)
EOF
	fi
}

set_comment() {
	BOOKMARK_INDEX=$1
	COMMENT="$2"
	echo Updating comment to $VALUE
	set_field $BOOKMARK_INDEX 6 $COMMENT
}

find_command() {
	COMMAND_LIST="$2"
	COMMAND_INPUT="$1"
	LONGEST_MATCH_COMMAND=
	LONGEST_MATCH_CHARS=0
	MORE_THAN_ONE_EQ_LEN_MATCH=1
	for CMD in $FIRST_LEVEL_COMMANDS; do
		MATCHING_CHARS=$(echo $CMD | $GREP -o ^$COMMAND_INPUT | wc -c)
		if [ "${MATCHING_CHARS}" -gt "$LONGEST_MATCH_CHARS" ]; then
			LONGEST_MATCH_CHARS=$MATCHING_CHARS
			LONGEST_MATCH_COMMAND=$CMD
		fi
		#if [ "${MATCHING_CHARS}" = "$LONGEST_MATCH_CHARS" ]; then
		#fi
	done
	#echo substituting input $1 with command $LONGEST_MATCH_COMMAND
	echo $LONGEST_MATCH_COMMAND
}

check_program_existence() {
	PATH="$1"
	if type "$1" >/dev/null; then
		printf "\t${COLOR_GREEN}%-30s${COLOR_RESET}" "$(type $1)" 

		# check the executable bit
		[ -x "$1" ] && IS_EXECUTABLE=0
		if [ -x "$1" ]; then
			echo -e "\t\t${COLOR_GREEN}[is executable]${COLOR_RESET}"
		else
			echo -e "\t\t${COLOR_RED}[isn't executable]${COLOR_RESET}"
		fi
	else 
		echo -e "\t${COLOR_RED}$(type "$1")${COLOR_RESET}"
	fi
}


# initialization	
echo $TERM | $GREP color >/dev/null
TERMINAL_SUPPORTS_COLORS=$?
if [ "$TERMINAL_SUPPORTS_COLORS" ]; then
	COLOR_GREEN="${GREEN}"
	COLOR_RED="${RED}"
	COLOR_RESET="${RESET}"
fi

# loop through script arguments
while [ $# -gt 0 ]; do

	FIRST_LEVEL_COMMANDS="list list-playing lp remove rm add goto first previous next last set-rating set-comment filter print-csv show output-bash-completions system-info"
	CMD=$(find_command $1 "$FIRST_LEVEL_COMMANDS")

	if [ "$CMD" = "list" ]; then
		list_all_bookmarks	
		exit 0
	elif [ "$CMD" = "remove" ]; then
		shift
		if [ ! -z "$1" ]; then
			remove_bookmark_by_index $1
			exit 0
		fi
	elif [ "$CMD" = "rm" ]; then
		shift
		if [ ! -z "$1" ]; then
			remove_bookmark_by_index $1
			exit 0
		fi
	elif [ "$CMD" = "add" ]; then
		shift
		if [ ! -z "$1" ]; then
			# rating supplied
			bookmark_playing_position $1 "$2"
		else
			bookmark_playing_position "$1"
		fi
		exit 0
	elif [ "$CMD" = "goto" ]; then
		shift
		jump_to_bookmark_by_index $1
		exit 0
	elif [ "$CMD" = "first" ]; then
		jump_to_first_bookmark_in_file
		exit 0
	elif [ "$CMD" = "previous" ]; then
		jump_to_previous_bookmark_in_file
		exit 0
	elif [ "$CMD" = "next" ]; then
		jump_to_next_bookmark_in_file
		exit 0
	elif [ "$CMD" = "last" ]; then
		jump_to_last_bookmark_in_file
		exit 0
	elif [ "$CMD" = "listp" ]; then
		list_playing_file_bookmarks
		exit 0
	elif [ "$CMD" = "lp" ]; then
		list_playing_file_bookmarks
		exit 0
	elif [ "$CMD" = "set-rating" ]; then
		shift
		set_rating $1 $2
		exit 0
	elif [ "$CMD" = "set-comment" ]; then
		shift
		set_comment $1 $2
		exit 0
	elif [ "$CMD" = "show" ]; then
		shift
		if [ ! -z "$1" ]; then
			BOOKMARK_INDEX=$1
			display_bookmark "$($GREP "^${BOOKMARK_INDEX};" "${BOOKMARKS_FILE}")"
			exit 0
		fi
	elif [ "$CMD" = "print-csv" ]; then
		if [ -f "${BOOKMARKS_FILE}" ]; then
			cat "${BOOKMARKS_FILE}"
		else
			echo Bookmarks file "${BOOKMARKS_FILE}" doesn\'t exist.
		fi
		exit 0
	elif [ "$CMD" = "filter" ]; then
		shift
		if [ -z "$1" ]; then
			echo "filter bookmarks by search fields: bm filter <field> <search-term>"
			echo "the following fields are available for filtering:"	
			echo "\tr[ating]"
			echo "\tc[omment]"
			exit 2
		fi
		FILTER_FIELDS="rating comment"
		FILTER_FIELD=$(find_command $1 "$FILTER_FIELDS")
		if [ "$FILTER_FIELD" = "rating" ]; then
			shift
			if [ ! -z "$1" ]; then
				filter_bookmarks_by_rating $1
				exit 0
			fi

		elif [ "$FILTER_FIELD" = "comment" ]; then
			shift
			if [ ! -z "$1" ]; then
				filter_bookmarks_by_comment "$1"
				exit 0
			fi
		fi
	elif [ "$CMD" = "output-bash-completions" ]; then
		BASH_COMPLETIONS_FILE="H4sICAOyOl4AA2JtAK1UUW+bMBB+Hr/iRpASonotfUzH1K3d9tBEjdqHamIUEThSFLCZ7TTqkvz3
2ZCQQBNtk4qUwPnuvu9899kd+DyXT4wP4F5ikiCFG465yJDDx5xFBZkwNstDPiN5SMMp8sspm8xn
6QfGp5+MDgzTCKnAAXwfD+H53DCC4MsouBpdu5NcG5M8mKIMIpar/Fj0bGNpgHqsbRysIFzMoHv6
+FN6Ifntn8Ky4CmVYDnrrvJKDiSGrudrI5pLZXVXXSCJY6z3GJI0k8jVC7ODNJX/LdhCPp3nSNWm
nphAWnNlLAozWDAeQ8FZgVy+lOsJ49VqSsHqCfyl/ntXt6NxcPVwe3dNHNsG4sC5XUbHrHztAAuO
z65pLcsMnXDvWRrOX5t1ZJqA58HrGOL4a3jvAvEkEz74fp0hn5DWxg7CtDSdCa4L3uOJ3z/pqyRY
rVq+vnc58Pv7eAcx9cNRzjmFs4YjSZum6tC2ZWWXLhvuvZa0NqwL0vXo0qp0s13U0cKOFnegwJhR
NFq+em0DshOIEnuRocRATQA5xrViREsrWSqk41rO3lI05651Xi7oYd59HQ9/uD2rpzGn6nSSB7XZ
Ms8EQtS3SjBt+xV3i0lFlUKCKI/1T7QZKvF14JrRrgRRZKkERiFiGatatz3GRaCFJYLJS8AxAUJh
ACQqCUhRcZAF7IQIJIWd2Esoxd8StKPFbOwNdqmBOp3+6VqPd5Jvp9qYpN6Ha/VeXTJ2HXG8hTq3
2cGDmtjM+mBVmxvlXyprXE5vW17V0VCgCl2qtLWpTpDxrvJqVruh5L8IVIEcqxrKSqCBdnFRm/3/
49Fgh6BQhFGltyCTPNUYSoFbpJRRsWnJ/tE70/LfkgH51mRX8jH+ABb4O3PnBgAA"
		echo $BASH_COMPLETIONS_FILE | tr ' ' '\n' | base64 -d | gunzip 
		echo 
		echo "------------>8-------------->8-------------->8--------------"
		echo
		echo You can install this file in the bash completion files firectory
		echo on you system to enable TAB-completion for the bm command.
		echo 
	        echo On Ubuntu 19.10 the global directory is:
		echo 
		echo "\t /usr/share/bash-completions/completions"
		echo 
		exit 0
	elif [ "$CMD" = "system-info" ]; then
		echo "Checking for the existing of used shell utilities."
		echo "If one or more of them display no path after their name"
		echo "they aren't found under the path configured in the script."
		echo 
		PROGRAMS="$MOCP $AWK $CAT $CUT $SORT $UNIQ"
		for PROG in $PROGRAMS; do
			check_program_existence "$PROG"
		done
		echo
		echo "Only needed for extracting the bash completions file:"
		echo
		PROGRAMS="$BASE64 $GUNZIP"
		for PROG in $PROGRAMS; do
			check_program_existence "$PROG"
		done
		echo 
		exit 0
	fi
	shift
done

echo "usage: $0 command args ..."
echo "where command is one of the following:"
echo
printf "\t%-34s %s\n" "a[dd] [comment]" "bookmark the current mocp playing position"
printf "\t%-34s %s\n" "" "with an optional comment"
echo
printf "\t%-34s %s\n" "g[oto] <bookmark_index>" "jump to the bookmark playing position"
printf "\t%-34s %s\n" "" "the file containing the bookmark must be playing in mocp"
printf "\t%-34s %s\n" "pre[vious]" "jump to previous bookmark in file"
printf "\t%-34s %s\n" "n[ext]" "jump to next bookmark in file"
printf "\t%-34s %s\n" "" "If there was a manual jump before."
printf "\t%-34s %s\n" "" "If not the jump will be to the first bookmark"

echo
printf "\t%-34s %s\n" "set-r[ating] <bookmark_index> <rating>" ""
printf "\t%-34s %s\n" "" "set a rating value (can be anything, i use 1-5)"
echo
printf "\t%-34s %s\n" "set-c[omment] <bookmark_index> <comment>" ""
printf "\t%-34s %s\n" "" "set the bookmark comment"
echo
printf "\t%-34s %s\n" "sh[ow] <bookmark_index>" "show bookmark details"
printf "\t%-34s %s\n" "re[move]|rm <bookmark_index>" "remove a bookmark"
printf "\t%-34s %s\n" "d[elete] <bookmark_index>" ""
echo
printf "\t%-34s %s\n" "list" "list all bookmarks by file"
printf "\t%-34s %s\n" "list-[playing]|lp" "list playing file bookmarks"
echo
printf "\t%s %-25s %s\n" "f[ilter]" "r[ating] <1-5>" "bookmark must have a minimum rating of <1-5>"
printf "\t%s %-25s %s\n" "f[ilter]" "c[omment] <search-term>" "comment must contain the search term"
echo
printf "\t%-34s %s\n" "o[utput-bash-completions]" "output bash_completions_file"
printf "\t%-34s %s\n" "sy[stem-info]" "check if the needed shell utils are available"
echo
printf "\t%-34s %s\n" "pri[nt-csv]" "output the bookmarks csv database to the terminal"
printf "\t%-34s %s\n" "" "columns:"
printf "\t%-34s\t%s\n" "" "bookmark index" 
printf "\t%-34s\t%s\n" "" "filename" 
printf "\t%-34s\t%s\n" "" "position (seconds)" 
printf "\t%-34s\t%s\n" "" "rating" 
printf "\t%-34s\t%s\n" "" "bookmark creation time" 
printf "\t%-34s\t%s\n" "" "comment" 

