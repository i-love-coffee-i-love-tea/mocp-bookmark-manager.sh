#!/bin/bash
#
# Author: Steffen Kremsler <mocp-bookmark-manager@gobuki.org>
# Date:   Feb. 8th, 2020
# License: GPL 2
# Version: 1.0
#
# Manages audio file bookmarks in combination with the fabulous
# mocp commmand line audio player. 
#
# Developed on Ubuntu 19.10 with the following versions
#    mocp 2.6-alpha3
#    dash 0.5.10
#    GNU Awk 4.2.1
#    GNU coreutils 8.30 (mv, cat, cut, tr, sort, uniq, base64)
#    GNU grep 3.3
#
#    Optional dependencies:
#
#      base64    to extract embedded bash-completions file
#      gunzip    to extract embedded bash-completions file
#
#      mp3splt   if mp3splt is installed you can use two bookmarks
#		 in an mp3 file as a range to export the audio
#		 between them 
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
#
#    Version 1.0
#       - Reordered, grouped, renamed command functions to the command name
#       - Added function documentation
#       - Fixed a bug in the set-<field> commands
#	- The playing file is displayed with a "N O W   P L A Y I N G" notice
#	- Added better filtering options for ratings:
#
#	  Comparison operator	Filter command
#	  <             	lt
#         <=			le
#         =			eq
#         >=			ge
#         >			gt
#           

BOOKMARKS_FILE="/home/gobuki/Radio_X/bookmarks.csv"
MP3SPLT_DEFAULT_OUTPUT_DIR="/home/gobuki/Radio_X/extracts"

# create directories and files
BOOKMARKS_FILE_DIR="$(dirname "$BOOKMARKS_FILE")"
mkdir -p "$BOOKMARKS_FILE_DIR"
mkdir -p "$MP3SPLT_DEFAULT_OUTPUT_DIR"
[ ! -d "$BOOKMARKS_FILE_DIR" ] \
	&& echo couldn\'t create bookmark file parent directory "$BOOKMARKS_FILE_DIR" \
	&& exit 

TMPL_LINE_DBL="==========================================================================================================================================================================================================================================================================================================="

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
MP3SPLT=/usr/bin/mp3splt

# Field names
FIELD_ID=1
FIELD_FILE=2
FIELD_POS=3
FIELD_CREATED=4
FIELD_RATING=5
FIELD_COMMENT=6

# Terminal colors
RED="\033[1;31m"
BLUE="\033[1;34m"
CYAN="\033[1;36m"
GREEN="\033[0;32m"
RESET="\033[0;0m"
BOLD="\033[;1m"
REVERSE="\033[;7m"


### 

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

# returns 0 if the passed filename equals the playing file
file_is_playing() {
	AUDIO_FILE="$1"
	if [ "${AUDIO_FILE}x" = "$(get_playing_file)x" ]; then
		return 0;
	else
		return 1;
	fi
}

# echoes the full name, with path, of the playing file
get_playing_file() {
	$MOCP -Q "%file"
}

### Output functions

display_bookmark() {
	CSV_LINE="$1"
	printf "\t%12s %s\n" "Index:" "$(echo "$CSV_LINE" | $CUT -f$FIELD_ID -d';')"
	printf "\t%12s %s\n" "File:" "$(echo "$CSV_LINE" | $CUT -f$FIELD_FILE -d';')"
	printf "\t%12s %s\n" "Position:" "$(format_timestamp $(echo "$CSV_LINE" | $CUT -f$FIELD_POS -d';'))"
	printf "\t%12s %s\n" "Created:" "$(echo "$CSV_LINE" | $CUT -f$FIELD_CREATED -d';')"
	printf "\t%12s %s\n" "Rating:" "$(format_rating $(echo "$CSV_LINE" | $CUT -f$FIELD_RATING -d';'))"
	printf "\t%12s %s\n" "Comment:" "$(echo "$CSV_LINE" | $CUT -f$FIELD_COMMENT -d';')"
}

print_file_bookmarks_header() {
	AUDIO_FILE="$1"
	if file_is_playing "$AUDIO_FILE"; then
		echo -e Bookmarks for $AUDIO_FILE "${COLOR_GREEN}" '< < <   N O W   P L A Y I N G'
		echo -e $(echo | awk "{print substr(\"$TMPL_LINE_DBL\", 0, $COLUMNS)}") "${COLOR_RESET}"
	else
		echo Bookmarks for $AUDIO_FILE
	fi
}

list_file_bookmarks() {
	AUDIO_FILE="$1"
	FILTER_COLUMN=$2
	FILTER_OPERATOR="$3"
	FILTER="$4"



	print_file_bookmarks_header "$AUDIO_FILE"

	# filter by rating
	if [ "$FILTER_COLUMN" = "$FIELD_RATING" ]; then
		get_bookmarks_filtered "$AUDIO_FILE" $FIELD_POS \
			| $AWK -F';' "\$${FILTER_COLUMN}${FILTER_OPERATOR}${FILTER}    {printf \"%3d at %02dh:%02dm:%02ds\t%s\t%s\t%s\n\", \
		       	\$1, \$3/(60*60), \$3%(60*60)/60, \$3%60, \$4, substr(\"*******\", 1, \$5), \$6}"
        # filter by comment
	elif [ "$FILTER_COLUMN" = "$FIELD_COMMENT" ]; then
		[ -z "$FILTER" ] && FILTER="$FILTER_OPERATOR"
		get_bookmarks_filtered "$AUDIO_FILE" $FIELD_POS \
			| $AWK -F';' "\$$FILTER_COLUMN ~ /$FILTER/ {printf \"%3d at %02dh:%02dm:%02ds\t%s\t%s\t%s\n\", \
		       	\$1, \$3/(60*60), \$3%(60*60)/60, \$3%60, \$4, substr(\"*******\", 1, \$5), \$6}"
	# unfiltered
	elif [ -z "$FILTER_COLUMN" ]; then
		get_bookmarks_filtered "$AUDIO_FILE" $FIELD_POS \
			| $AWK -F';' '{printf "%3d at %02dh:%02dm:%02ds\t%s\t%s\t%s\n", \
		       	$1, $3/(60*60), $3%(60*60)/60, $3%60, $4, substr("*******", 1, $5), $6}'
	fi
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
		# used in sed
		PREV_RATING=$(get_bookmark $BOOKMARK_INDEX | $AWK -F';' '{print $5}')

		echo $(get_bookmark $BOOKMARK_INDEX)
		echo sed -i.backup "s|${LINE_START};${PREV_RATING}|${LINE_START};${VALUE}|g" "${BOOKMARKS_FILE}"
		sed -i.backup "s|${LINE_START};|${LINE_START};${VALUE}|g" "${BOOKMARKS_FILE}"
		exit 3 

	fi
}

set_rating() {
	BOOKMARK_INDEX=$1
	RATING=$2
	echo Updating rating to $VALUE
	set_field $BOOKMARK_INDEX $FIELD_RATING $RATING
}






#====================================================================================================
# CSV functions
#

# Checks if a bookmark index exists in the CSV datasource
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

# simple grep, only food enough for filenames. This will not work correctly when there are filenames
# which contain the complete name of another file.
# For example: 
#   Track.mp3
#   Track.mp3.extract-01.mp3

# Echoes the CSV line matching the passed index.
# If a second parameter is passed, it is used as the bookmark source. (used in the filtering functions)
# Otherwise the bookmarks file is used as source.
get_bookmark() {
	BOOKMARK_INDEX=$1
	STDIN_SRC="$2"

	if [ "${STDIN_SRC}x" != "x" ]; then
		# CSV passed as second parameter
		echo "$STDIN_SRC" | $GREP "^${BOOKMARK_INDEX};"
	else 
		# CSV file as source
		$GREP "^${BOOKMARK_INDEX};" "$BOOKMARKS_FILE"
	fi
}


# Echoes CSV lines matching the passed filter expression, sorted by the field with the index
# passed as second parameter
get_bookmarks_filtered() {
	FILTER="$1"
	SORT_FIELD=$2
	if [ "${SORT_FIELD}x" = "x" ]; then
		$GREP "$FILTER" "${BOOKMARKS_FILE}"
	else
		$SORT -nk$SORT_FIELD -t';' "${BOOKMARKS_FILE}" | $GREP "$FILTER" "${BOOKMARKS_FILE}"
	fi
}



# Echoes CSV lines of bookmarks for the playing file. Optionally sorted by the field with
# the passed index
get_playing_file_bookmarks() {
	SORT_FIELD=$1 # optional
	get_bookmarks_filtered $(get_playing_file) $SORT_FIELD
}

# Echoes the value of the given field of a passed CSV line
get_csv_value() {
	FIELD_NO=$1
	CSV_LINE="$2"
	echo "$CSV_LINE" | $AWK -F';' "{print \$$FIELD_NO}"
}

# Echoes the rating of the bookmark with the given index
get_rating_by_index() {
	BOOKMARK_INDEX=$1
	RATING=$($GREP "^${BOOKMARK_INDEX};" "${BOOKMARKS_FILE}" | $AWK -F';' "{print \$$FIELD_RATING}")
	echo $RATING
}


#====================================================================================================
# Output formatting functions
#

# Input seconds. Output formatted timestamp for as h:m:s
format_timestamp() {
	TIMESTAMP="$1"
	echo "$TIMESTAMP" | awk '{printf "%02dh:%02dm:%02ds",  $1/(60*60), $1%(60*60)/60, $1%60}'
}

# Echoes the current position in the playing mocp file
format_mocp_time() {
	format_timestamp $($MOCP -Q cs)
}

# Formats the input seconds as time parameter for mp3splt
format_mp3splt_time() {
	TOTAL_SECONDS=$1
	#echo $TOTAL_SECONDS seconds
	SECONDS=$(expr $TOTAL_SECONDS % 60 )
	MINUTES=$(expr $TOTAL_SECONDS / 60 )
	echo $MINUTES.$SECONDS
}

# Converts a numeric rating to a string with <value> amount of stars
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


#====================================================================================================
# Command functions
#

# Iterates through passed $COMMAND_LIST
# Returns the longest match with $COMMAND_INPUT
complete_command() {
	COMMAND_INPUT="$1"
	COMMAND_LIST="$2"
	LONGEST_MATCH_COMMAND=
	LONGEST_MATCH_CHARS=0
	MORE_THAN_ONE_EQ_LEN_MATCH=1
	for CMD in $COMMAND_LIST; do
		MATCHING_CHARS=$(echo $CMD | $GREP -o ^$COMMAND_INPUT | wc -c)
		if [ "${MATCHING_CHARS}" -gt "$LONGEST_MATCH_CHARS" ]; then
			LONGEST_MATCH_CHARS=$MATCHING_CHARS
			LONGEST_MATCH_COMMAND=$CMD
		fi
	done
	echo $LONGEST_MATCH_COMMAND
}

# Prints all known files with bookmarks to the console
cmd_list() {
	AUDIO_FILES="$($CUT -f2 -d';' ${BOOKMARKS_FILE} | $SORT | $UNIQ)"
	while read AUDIO_FILE; do
	        list_file_bookmarks "$AUDIO_FILE"
		echo
	done <<EOF
$AUDIO_FILES
EOF
}

# Prints the bookmarks in the currently playing file
cmd_list_playing() {
	list_file_bookmarks $(get_playing_file)
	echo Current position in file: $(format_mocp_time)
}

# Exports the segement between two bookmarks of an mp3 file
cmd_split() {
	PLAYING_FILE_BOOKMARKS=$(get_playing_file_bookmarks)
	BOOKMARK_START=$(get_csv_value $FIELD_POS $(get_bookmark $1 "$PLAYING_FILE_BOOKMARKS" ))
	BOOKMARK_END=$(get_csv_value $FIELD_POS $(get_bookmark $2 "$PLAYING_FILE_BOOKMARKS" ))
	OUTPUT_FILENAME="$3"
	MP3SPLT_START=$(format_mp3splt_time $BOOKMARK_START)
	MP3SPLT_END=$(format_mp3splt_time $BOOKMARK_END)
	echo $MP3SPLT "$(get_playing_file)" $MP3SPLT_START $MP3SPLT_END -o "$OUTPUT_FILENAME"
	$MP3SPLT -o "${MP3SPLT_DEFAULT_OUTPUT_DIR}" "$(get_playing_file)" $MP3SPLT_START $MP3SPLT_END -o "$OUTPUT_FILENAME"
	echo $MP3SPLT -d "${MP3SPLT_DEFAULT_OUTPUT_DIR}" -o "${OUTPUT_FILENAME}_%m_%s_to_%M_%S" "$(get_playing_file)" $MP3SPLT_START $MP3SPLT_END 
}

# Sets a bookmarks comment
cmd_set_comment() {
	BOOKMARK_INDEX=$1
	COMMENT="$2"
	echo Updating comment to "$COMMENT"
	set_field $BOOKMARK_INDEX $FIELD_COMMENT "$COMMENT"
}

# Makes mocp jump to the bookmark file and position
cmd_goto() {
	BOOKMARK_INDEX=$1
	BOOKMARK_POSITION=$($GREP "^${BOOKMARK_INDEX};" "${BOOKMARKS_FILE}" | $AWK -F';' '{print $3}')
	if bookmark_exists $BOOKMARK_INDEX; then
		POS="$BOOKMARK_POSITION"
		echo Jumping to bookmark $BOOKMARK_INDEX at position $(format_timestamp $POS)
		PLAYING_FILE=$(get_playing_file)
		BOOKMARK_FILE=$($GREP "^${BOOKMARK_INDEX};" "${BOOKMARKS_FILE}" | $AWK -F';' '{print $2}')
		if [ "$PLAYING_FILE" != "$BOOKMARK_FILE" ]; then
			echo "Bookmark is in a different file (not currently playing)"
			echo -e "\tplaying : $PLAYING_FILE"
			echo -e "\tbookmark: $BOOKMARK_FILE"
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

# Jumps to the first bookmark in the playing file
cmd_first() {
	FIRST_BOOKMARK=$($GREP "$(get_playing_file)" "$BOOKMARKS_FILE" | $AWK -F';' "{print \$$FIELD_ID}" | $SORT | head -n1)
	cmd_goto $FIRST_BOOKMARK
}

# Jumps to previous bookmark in the playing file
cmd_previous() {
	if [ -s /tmp/last_bookmark_jump ]; then
		LAST_BOOKMARK_INDEX=$(cat /tmp/last_bookmark_jump)
		# find next bookmark index
		PLAYING_FILE=$(get_playing_file)
		if [ -z "$LAST_BOOKMARK_INDEX" ]; then
			echo "no previous jump" 
			cmd_first
		else
			echo "previously jumped to bookmark $LAST_BOOKMARK_INDEX"
			echo "trying to find a bookmark with lower index in the file"
			NEXT_LOWER_INDEX_IN_FILE=$($GREP "$PLAYING_FILE" "$BOOKMARKS_FILE" | $AWK -F';' "{print \$$FIELD_ID}" | $SORT | $GREP ^$LAST_BOOKMARK_INDEX\$ -B1 | head -n1)
			if [ "x$NEXT_LOWER_INDEX_IN_FILE" != "x" ]; then
				echo "lower index found: $NEXT_LOWER_INDEX_IN_FILE"
				cmd_goto $NEXT_LOWER_INDEX_IN_FILE
			else
				echo "next lower index not found"
				cmd_first
			fi
		fi
	else
		cmd_first
	fi
}

# Jumps to the next bookmark in the playing file
cmd_next() {
	if [ -s /tmp/last_bookmark_jump ]; then
		LAST_BOOKMARK_INDEX=$(cat /tmp/last_bookmark_jump)
		if [ -z "$LAST_BOOKMARK_INDEX" ]; then
			cmd_first
		else
			NEXT_HIGHEST_INDEX_IN_FILE=$($GREP "$(get_playing_file)" "$BOOKMARKS_FILE" | $AWK -F';' "{print \$$FIELD_ID}" | $SORT | $GREP ^$LAST_BOOKMARK_INDEX\$ -A1 | tail -n1)
			if [ ! -z "$NEXT_HIGHEST_INDEX_IN_FILE" ]; then
				cmd_goto $NEXT_HIGHEST_INDEX_IN_FILE
			else
				cmd_first
			fi
		fi
	else
		cmd_first
	fi
}

# Jumps to the last bookmark of the playing file
cmd_last() {
	LAST_BOOKMARK=$($GREP "$(get_playing_file)" "$BOOKMARKS_FILE" | $AWK -F';' "{print \$$FIELD_ID}" | $SORT | tail -n1)
	cmd_goto $LAST_BOOKMARK
}

# Jumps to a random bookmark position
cmd_random() {
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

# Bookmarks a the current mocp position
cmd_add() {
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

# Remove a bookmark by its index
cmd_remove() {
	BOOKMARK_INDEX=$1
	if bookmark_exists $BOOKMARK_INDEX; then
		echo Deleting bookmark
		$GREP -v -e "^${BOOKMARK_INDEX};" "${BOOKMARKS_FILE}" > /tmp/bookmarks.after.delete
		if [ "$?" -eq "0" ]; then
		        /bin/mv /tmp/bookmarks.after.delete "${BOOKMARKS_FILE}"
		fi
	fi
}

# Lists all bookmarks with a passed minimum rating 
cmd_filter_rating() {
	AWK_COMPARISON_OPERATOR="=="
	if [ ! -z "$2" ]; then
		RATING="$2"
		if [ "$1" == "lt" ]; then
			AWK_COMPARISON_OPERATOR="<"
		elif [ "$1" == "le" ]; then
			AWK_COMPARISON_OPERATOR="<="
		elif [ "$1" == "eq" ]; then
			AWK_COMPARISON_OPERATOR="=="
		elif [ "$1" == "gt" ]; then
			AWK_COMPARISON_OPERATOR=">"
		elif [ "$1" == "ge" ]; then
			AWK_COMPARISON_OPERATOR=">="
		else 
			AWK_COMPARISON_OPERATOR="$1"
		fi
	else 
		RATING="$1"
		AWK_COMPARISON_OPERATOR="=="
	fi
	
#	echo "$AWK -F';' \"\$${FIELD_RATING}${AWK_COMPARISON_OPERATOR}$RATING {print \$0}\" \"${BOOKMARKS_FILE}\" | $CUT -f$FIELD_FILE -d';' | $SORT | $UNIQ"
	AUDIO_FILES="$($AWK -F';' "\$${FIELD_RATING}${AWK_COMPARISON_OPERATOR}${RATING} {print \$0}" "${BOOKMARKS_FILE}" | $CUT -f$FIELD_FILE -d';' | $SORT | $UNIQ)"
	while read AUDIO_FILE; do
	        list_file_bookmarks "$AUDIO_FILE" "$FIELD_RATING" "$AWK_COMPARISON_OPERATOR" "$RATING"
		echo
	done <<EOF
$AUDIO_FILES
EOF
}

# Lists all bookmarks with matching comments
cmd_filter_comment() {
	COMMENT="$1"
	AUDIO_FILES="$($AWK -F';' "\$$FIELD_COMMENT ~ /$COMMENT/ {print \$0}" "${BOOKMARKS_FILE}" | $CUT -f$FIELD_FILE -d';' | $SORT | $UNIQ)"
	while read AUDIO_FILE; do
		list_file_bookmarks "$AUDIO_FILE" $FIELD_COMMENT "$COMMENT"
		echo
	done <<EOF
$AUDIO_FILES
EOF
}

cmd_find_nearest_bookmark() {
	get_playing_file_bookmarks
	echo 
}

cmd_mv_bookmark() {
	DELTA_SECONDS=$1
	DIRECTION=$2
	echo
}


 

#====================================================================================================
# Main

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

	FIRST_LEVEL_COMMANDS=$($0 | awk '/^\t[a-z]/ {print $1}' | tr -d '[]' | cut -d'|' -f1)
	CMD=$(complete_command $1 "$FIRST_LEVEL_COMMANDS")

	if [ "$CMD" = "list" ]; then
		cmd_list
		exit 0
	elif [ "$CMD" = "remove" ]; then
		shift
		if [ ! -z "$1" ]; then
			cmd_remove $1
			exit 0
		fi
	elif [ "$CMD" = "rm" ]; then
		shift
		if [ ! -z "$1" ]; then
			cmd_remove $1
			exit 0
		fi
	elif [ "$CMD" = "add" ]; then
		shift
		if [ ! -z "$1" ]; then
			# rating supplied
			cmd_add $1 "$2"
		else
			cmd_add "$1"
		fi
		exit 0
	elif [ "$CMD" = "goto" ]; then
		shift
		cmd_goto $1
		exit 0
	elif [ "$CMD" = "first" ]; then
		cmd_first
		exit 0
	elif [ "$CMD" = "previous" ]; then
		cmd_previous
		exit 0
	elif [ "$CMD" = "next" ]; then
		cmd_next
		exit 0
	elif [ "$CMD" = "last" ]; then
		cmd_last
		exit 0
	elif [ "$CMD" = "list-playing" ]; then
		cmd_list_playing
		exit 0
	elif [ "$CMD" = "lp" ]; then
		cmd_list_playing
		exit 0
	elif [ "$CMD" = "set-rating" ]; then
		shift
		cmd_set_rating $1 $2
		exit 0
	elif [ "$CMD" = "set-comment" ]; then
		shift
		cmd_set_comment $1 $2
		exit 0
	elif [ "$CMD" = "split" ]; then
		shift
		START=$1
		END=$2
		OUTPUT_FILE="$3"
		cmd_split $START $END "$OUTPUT_FILE"
		exit 0
	elif [ "$CMD" = "show" ]; then
		shift
		if [ ! -z "$1" ]; then
			BOOKMARK_INDEX=$1
			cmd_show "$(get_bookmark ${BOOKMARK_INDEX})"
			exit 0
		fi
	elif [ "$CMD" = "print-csv" ]; then
		if [ -f "${BOOKMARKS_FILE}" ]; then
			$CAT "${BOOKMARKS_FILE}"
		else
			echo Bookmarks file "${BOOKMARKS_FILE}" doesn\'t exist.
		fi
		exit 0
	elif [ "$CMD" = "filter" ]; then
		shift
		if [ -z "$1" ]; then
			echo    "filter bookmarks by search fields: bm filter <field> <search-term>"
			echo    "the following fields are available for filtering:"	
			echo -e "\tr[ating]"
			echo -e "\tc[omment]"
			exit 2
		fi
		FILTER_FIELDS="rating comment"
		FILTER_FIELD=$(complete_command $1 "$FILTER_FIELDS")
		if [ "$FILTER_FIELD" = "rating" ]; then
			shift
			if [ ! -z "$1" ]; then
				cmd_filter_rating "$1" "$2"
				exit 0
			fi

		elif [ "$FILTER_FIELD" = "comment" ]; then
			shift
			if [ ! -z "$1" ]; then
				cmd_filter_comment "$1"
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
		!test -x $BASE64 && echo "Error: need the base64 program for this" && exit 2
		!test -x $GUNZIP && echo "Error: need the gunzip program for this" && exit 2
		echo $BASH_COMPLETIONS_FILE | tr ' ' '\n' | $BASE64 -d | $GUNZIP
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
		PROGRAMS="$MOCP $AWK $GREP $CAT $CUT $SORT $UNIQ"
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
printf "\t%-34s %s\n" "list-[playing]" "list playing file bookmarks"
printf "\t%-34s %s\n" "lp" "list playing file bookmarks"
echo
printf "\t%s %-25s %s\n" "f[ilter]" "r[ating] [lt|le|qe|gt|ge] <1-5>" "list bookmarks with a matching rating"
printf "\t%s %-25s %s\n" "" "" ""
printf "\t%s %-25s %s\n" "f[ilter]" "c[omment] <search-term>" "comment must contain the search term"
echo
printf "\t%-34s %s\n" "o[utput-bash-completions]" "output bash_completions_file"
printf "\t%-34s %s\n" "sy[stem-info]" "check if the required shell utils are available"
#printf "\t%-34s %s\n" "sp[lit] <start-index>" "exports the range from <start-index> to the end of the file"
#printf "\t%-34s %s\n" "to a file with a default name in a directory with a default name"
printf "\t%-34s %s\n" "sp[lit] <start-index> <end-index> [output-filename]" "check if the required shell utils are available"
echo
printf "\t%-34s %s\n" "pri[nt-csv]" "output the bookmarks csv database to the terminal"
printf "\t%-34s %s\n" "" "columns:"
printf "\t%-34s\t%s\n" "" "bookmark index" 
printf "\t%-34s\t%s\n" "" "filename" 
printf "\t%-34s\t%s\n" "" "position (seconds)" 
printf "\t%-34s\t%s\n" "" "rating" 
printf "\t%-34s\t%s\n" "" "bookmark creation time" 
printf "\t%-34s\t%s\n" "" "comment" 

