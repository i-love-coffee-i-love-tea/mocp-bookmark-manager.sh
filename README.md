# mocp-bookmark-manager.sh
## Description

This little shell script manages bookmarks of positions in audio files in a CSV file. 

It can be used in combination with mocp to bookmark positions in playing files, jump to bookmarks and manage bookmarks from the command line. Bookmarks can have a rating and a comment.
A bookmark manager for the wonderfully simple, yet powerful cli audio player 'mocp'. I have never had an audio player setup that functional and efficient.  

This script might be useful to you, if you identify with at least some of these statements

* you feel at home when you have shell in front of you 
* you like to listen to long audio files
* you need a simple way to set browsable marks at audio file positions, with ratings and comments
* you don't like to throw massive (system) resources on simple problems


## Motivation to develop this script

I record a lot of radio shows with hosts presenting their favourites songs/tracks and dj mixes using a cron job. So i have a lot of files laying around and it wasn't fun to keep track of all the good stuff in them. I used to select a file randomly and skip through it until I find something interesting, then I listened to it for a week or so and then I, life went on, and I forgot where the nice music is hidden. I started to write down some timestamps in a textfile, but that got unmanageable and it wasn't fun.

My expectations weren't that high. I just wanted some... any.. way to save, search and jump to annotated bookmarks.

## Features

* Save a bookmarked position in an audio file with comment and rating.
* List all bookmarks
* List all bookmarks in the playing file
* List bookmarks filtered by (minimum) rating or comment
* Make mocp jump to a bookmarked position by the bookmark's index
* Remove bookmarks
* Edit bookmark rating/comment
* Save the segment between two bookmarks in an mp3 file as mp3. (needs mp3splt)
* Jump to the first, previous, next, last bookmark in a file

## Prerequisites

The script needs mocp and these shell utilities to run. Most linux distributions should have everything but mocp and mp3split installed already.

* Bash

* coreutils for cat, cut, sort, uniq, etc
* awk
* grep

Only for extracting the embedded bash completions.

* base64
* gunzip 

Optionally, for extracting mp3 segments between bookmarks

* mp3splt


To install the packages on Ubuntu/Debian:

```
apt install mocp mp3splt
```


## Installation

Just copy the script to ~/bin/mocp-bookmark-manager.sh and make sure it is executable.

$ wget https://github.com/i-love-coffee-i-love-tea/mocp-bookmark-manager.sh/blob/master/mocp-bookmark-manager.sh
$ cp mocp-bookmark-manager.sh bin
$ chmod +x bin/mocp-bookmark-manager.sh bin

Then edit the variable BOOKMARKS_FILE in the script to a file destination you like. 
The csv file doesn't have to exist. It will be created with the first execution of the 'add' command.

If you want you can also download my mocp and amixer aliases. You don't need them for the bookmark manager script, but I find them
quite handy and use them regularly to change the volume, mute/unmute, pause/unpause mocp, etc.

```
alias mute='amixer set Master toggle'
# increase/decrease master volume
alias vol-='amixer set Master 1%-'
alias vol+='amixer set Master 1%+'
alias vol--='amixer set Master 10%-'
alias vol++='amixer set Master 10%+'
alias vol---='amixer set Master 30%-'
alias vol+++='amixer set Master 30%+'
# set master volume to a specific level
alias vol0='amixer set Master 0%'
alias vol1='amixer set Master 10%'
alias vol2='amixer set Master 20%'
alias vol3='amixer set Master 30%'
alias vol4='amixer set Master 40%'
alias vol5='amixer set Master 50%'
alias vol6='amixer set Master 60%'
alias vol7='amixer set Master 70%'
alias vol8='amixer set Master 80%'
alias vol9='amixer set Master 90%'
alias volmax='amixer set master 100%'
# set rear mic volume
alias micvol-='amixer set "Rear Mic" 1%-'
alias micvol+='amixer set "Rear Mic" 1%+'
alias micvol--='amixer set "Rear Mic" 10%-'
alias micvol++='amixer set "Rear Mic" 10%+'
# mute/unmute rear mic
alias mutemic='amixer cset name="Input Source",index=0 "Rear Mic"'
alias unmutemic='amixer cset name="Input Source",index=0 "Rear Mic"'
```
$ mkdir ~/.bash_aliases.d
$ wget -O ~/.bash_aliases.d/amixer https://github.com/i-love-coffee-i-love-tea/mocp-bookmark-manager.sh/blob/master/bash-completions

```
alias bm='/home/gobuki/bin/mocp-bookmark-manager.sh'

alias skip='mocp --seek +10'
alias skipp='mocp --seek +60'
alias skippp='mocp --seek +300'
alias rev='mocp --seek -10'
alias revv='mocp --seek -60'
alias revvv='mocp --seek -300'
alias playing='mocp -Q "%ct /%tt %file"'
alias jump='mocp -j' # Example: jump 60s

alias recent='play-most-recent mp3'
alias pause='mocp -P'
alias unpause='mocp -U'
```
```
$ mkdir ~/.bash_aliases.d/
$ wget -O ~/.bash_aliases.d/amixer https://github.com/i-love-coffee-i-love-tea/mocp-bookmark-manager.sh/blob/master/bash-completions
```


### Bash completion support

The script has a bash completions file embedded which can be printed to the console or redirected to a file.

```
$ bm output-bash completions > /tmp/bm
$ sudo cp /tmp/bm /usr/share/bash-completion/completions/bm
```
The completions will be active in new bash instances. To load the completion functions in an already running bash,
you can source them:
```
$ . /usr/share/bash-completion/completions/bm
```
## Limitations

I only tested it with very simple filenames, without special characters and spaces.

The filtering functions don't work correctly when your bookmarks list contains bookmarks from files with names
that fully match part of another filename.

Example

full_match.mp3
full_match.mp3.extract_01.mp3

## Usage

For every command, you only need to enter the first characters. As many as are needed to make it unabiguous.
The details are displayed in the usage output, which is shown, when no command could be identified.
Everything that is between [] is optional.

```
$ bm
usage: /home/gobuki/bin/bm command args ...
where command is one of the following:

	a[dd] [comment]                    bookmark the current mocp playing position
	                                   with an optional comment

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

I recommend setting up a shell alias to make the call shorter, if you haven't downloaded my bash aliases.
```
alias bm="~/bin/mocp-bookmark-manager.sh"
```
... so you can use it like this

```
$ bm add "bush choking on pretzel"
```

### Create a bookmark for the current position in the playing file
You can optionally supply a rating between 1 and 5
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

### List bookmarks for the playing file
```
skremsler@morpheus:~$ bm lp
bookmarks for /home/skremsler/Radio_X/RuFFM/2019-10-12_18-55_-_RadioX_-_RuFFM.mp3
 30 at 01h:01m:12s	Mi 05 Feb 2020 03:46:45 CET	****	shut dem down
```

### Make mocp jump to a bookmark by its index.
The bookmark file must be playing. This is good enough for me at the moment.
```
skremsler@morpheus:$ bm goto 7
jumping to bookmark 7 at position 00h:49m:34s
```


### Export the segment between two bookmarks from an mp3 file

For this command to work, mp3split needs to be installed.

```
$ bm split 1 3 /tmp/result.mp3

```
## A word about mocp and why I like it

Of the audio players i have observed - the list grew very long over the years - none that survived can create and manage bookmarks in mp3 files in a satisfying way. VLC currently has support for it, but the interface is horrible and unusable IMHO (2020-02). All GUI audio players I have used over the years have either disappeared, changed in a way I didn't like or are missing something for me. I want consistency, something to build upon. Mocp seems to be around for a long time and i think one reason for it, that it isn't dependent on complex gui toolkits. They draw developer resources and lead to a strong dependency on them. On a medium time frame GUI toolkits come and go and it isn't always a simple task to migrate an application to a different toolkit or a newer toolkit version. 

Its client/server model fits my thinking. It's nice to have the slim terminal compatible ncurses interface, but I seldomly use it. It is very convenient to control the player with shell aliases which dispatch commands to the player, running in the background. I mostly use it like that. It doesn't matter in which terminal window you are, you can control your player on the console without starting a special interface which blocks the console. It enables uninteruptive control, when you're working in the terminal anyway and your hands are on the keyboard. Over the years I have formed a strong opinion against GUI applications and prefer the console where possible, because the applications don't get in my way as much.


## Ideas

* CUE file support
Or maybe better not,... the last twenty years I got the impression that CUE file support
    isn't supported very well, if at all by most players. Maybe i missed some nice player,
    but every other year I searched for current players with CUE sheet support, 
    because I wanted to conveniently set and manages markers in audio files and I wasn't successful.
    So the theoretical standardization benefit of the format isn't very big in my opinion.
    There is some really nice cue sheet software. mp3splt is a great cue sheet tool
    for example... but where are the players? It seems the applications supporting cue files
    are mostly CD and ISO oriented.

* Commands to move bookmarks +/-n seconds and jump to it afterwards.
* Commands to extract mp3 from the beginning to a bookmark or from bookmark to the end.
* Command to list all files, with prefixed index
* Command to list the bookmarks in a file by its index
* Use a default filename when exporting mp3 segments, if the destination filename isn't specified. Pattern: ${cut -c-4 ${ORIGINAL_FILENAME}}_${TIME_FROM}_${TIME_TO}.mp3
* Add a genre field





