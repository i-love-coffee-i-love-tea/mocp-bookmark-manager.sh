# mocp-bookmark-manager.sh
A bookmark manager for the wonderfully simple, yet powerful cli audio player 'mocp'. I have never had an audio player setup that functional and efficient.  

This script might be useful to you, if you identify with at least some of these statements

* you feel at home when you have shell in front of you 
* you like to listen to long audio files
* you need a simple way to set browsable marks at audio file positions, with ratings and comments
* you don't like to throw massive (system) resources on simple problems


## Motivation for this script

Of the audio players i have observed - the list grew very long over the years - none could create and manage bookmarks in mp3 files in a satisfying way. VLC currently has support for it, but the interface is horrible and unusable IMHO (2020-02). All GUI audio players I have used over the years have either disappeared, changed in a way I didn't like or are missing something for me. I want consistency, something to build upon. Mocp seems to be around for a long time and i think one reason for it, that it isn't dependent on complex gui toolkits. They draw developer resources and lead to a strong dependency on them. On a medium time frame GUI toolkits come and go and it isn't always a simple task to migrate an application to a different toolkit or a newer toolkit version. I have seen many applications die because of developer interest. Technological debt accumulates faster with complex GUIs and .

## A word about mocp and why I like it

This is a reason for me to prefer software with a simpler design. Avoiding desktop GUI complexity can help to reduce possibilities for design descisions to go wrong and to better focus on the core issues. As mocp demonstrates it doesn't have to be less powerful. As a friend of the terminal, I don't like bloated software, which sacrifices stability and efficiency for eye candy in an extreme way. I have used others before, tried about anything. 

Its client/server model fits my thinking. It's nice to have the slim terminal compatible ncurses interface, but I seldomly use it. It is very convenient to control the player with shell aliases which dispatch commands to the player, running in the background. I mostly use it like that. It doesn't matter in which terminal window you are, you can control your player on the console without starting a special interface which blocks the console. It enables uninteruptive control, when you're working in the terminal anyway and your hands are on the keyboard. Over the years I have formed a strong opinion against GUI applications and prefer the console where possible, because the applications don't get in my way as much.


## Description

This little shell script manages bookmarks of positions in audio files in a CSV file. 

It can be used in combination with mocp to bookmark positions in playing files, jump to bookmarks and manage bookmarks from the command line. Bookmarks can have a rating and a comment.

## Installation

Just copy the script to ~/bin/mocp-bookmark-manager.sh

Then edit the variable BOOKMARKS_FILE in the script to a file destination you like. 
The csv file doesn't have to exist. It will be created with the first execution of the 'add' command.

## Usage 
```
usage: /home/gobuki/bin/bm command args ...
where command is one of the following:

	a[dd] [comment]                    bookmark the current mocp playing position
	a[dd] [1-5] [comment]              with an optional rating and comment

	g[oto] <bookmark_index>            jump to the bookmark playing position
	                                   the file containing the bookmark must be playing in mocp
	pre[vious]                         jump to previous bookmark in file
	n[ext]                             jump to next bookmark in file
	                                   If there was a manual jump before.
	                                   If not the jump will be to the first bookmark

	set-r[ating] <bookmark_index> <rating> 
	                                   set a rating value (can be anything, i use 1-5)

	set-c[omment] <bookmark_index> <comment> 
	                                   set the bookmark comment

	sh[ow] <bookmark_index>            show bookmark details
	re[move]|rm <bookmark_index>       remove a bookmark
	d[elete] <bookmark_index>          

	list                               list all bookmarks by file
	list-[playing]|lp                  list playing file bookmarks

	f[ilter] r[ating] <1-5>            bookmark must have a minimum rating of <1-5>
	f[ilter] c[omment] <search-term>   comment must contain the search term

	o[utput-bash-completions]          output bash_completions_file
	sy[stem-info]                      check if the needed shell utils are available

	pri[nt-csv]                        output the bookmarks csv database to the terminal
	                                   columns:
	                                  	bookmark index
	                                  	filename
	                                  	position (seconds)
	                                  	rating
	                                  	bookmark creation time
	                                  	comment

```

## Usage examples

I recommend setting up a shell alias to make the call shorter
```
alias bm="~/bin/mocp-bookmark-manager.sh"
```
... so you can use it like this

```
$ bm add "bush choking on pretzel"
```

### Create a bookmark for the current position in the playing file
```
skremsler@morpheus:~$ bm add "A bookmark description"
Adding bookmark
	      Index: 32
	       File: /home/skremsler/Radio_X/RuFFM/2019-10-12_18-55_-_RadioX_-_RuFFM.mp3
	   Position: 4115
	    Created: Mi 05 Feb 2020 04:23:05 CET
	     Rating:
	    Comment: A bookmark description
```

optionally supply a rating between 1 and 5
```
skremsler@morpheus:~$ bm add 5 "bush choking on pretzel"
Adding bookmark
	      Index: 32
	       File: /home/skremsler/Radio_X/RuFFM/2019-10-12_18-55_-_RadioX_-_RuFFM.mp3
	   Position: 4115
	    Created: Mi 05 Feb 2020 04:23:05 CET
	     Rating: *****
	    Comment: A bookmark description
```

### Make mocp jump to a bookmark by its index.
The bookmark file must be playing. This is good enough for me at the moment.
```
skremsler@morpheus:$ bm go 7
jumping to bookmark 7 at position 3738
```

### List bookmarks for the playing file
```
skremsler@morpheus:~$ bm listp
bookmarks for /home/skremsler/Radio_X/RuFFM/2019-10-12_18-55_-_RadioX_-_RuFFM.mp3
 30 at 01h:01m:12s	Mi 05 Feb 2020 03:46:45 CET	****	shut dem down
```

### List all bookmarks
```
skremsler@morpheus:~$ bm list
bookmarks for /home/skremsler/Radio_X/RuFFM/2019-10-12_18-55_-_RadioX_-_RuFFM.mp3
 30 at 01h:01m:12s	Mi 05 Feb 2020 03:46:45 CET	****	shut dem down
bookmarks for /home/skremsler/Radio_X/RuFFM/2019-11-16_18-55_-_RadioX_-_RuFFM.mp3
 20 at 00h:05m:28s	Mi 05 Feb 2020 01:35:12 CET	***** 	bush choking on pretzel
bookmarks for /home/skremsler/Radio_X/RuFFM/2020-01-18_18-55_-_RadioX_-_RuFFM.mp3
  7 at 01h:02m:18s	Mi 05 Feb 2020 00:49:34 CET	*****	fighter
 18 at 01h:02m:46s	Mi 05 Feb 2020 01:26:08 CET	****	full spectrum
 ```


## Ideas

* CUE file support
** Or maybe better not,... the last twenty years I got the impression that CUE file support
   isn't supported very well, if at all by most players. Maybe i missed some nice player,
   but every other year I searched for current players with CUE sheet support, 
   because I wanted to conveniently set and manages markers in audio files and I wasn't successful.
   So the theoretical standardization benefit of the format isn't very big in my opinion.

   There is some really nice cue sheet software. mp3splt is a great cue sheet tool
   for example... but where are the players? It seems the applications supporting cue files
   are mostly CD and ISO oriented. 
   
