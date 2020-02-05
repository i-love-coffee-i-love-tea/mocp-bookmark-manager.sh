# mocp-bookmark-manager.sh
A bookmark manager for the wonderful cli audio player 'mocp'

## Description

This little shell script manages bookmarks of positions in audio files in a csv file. 

It can be used in combination with mocp to bookmark positions in playing files, jump to bookmarks and manage bookmarks from the command line.

## Installation

Just copy the script to ~/bin/mocp-bookmark-manager.sh

Then edit the variable BOOKMARKS_FILE in the script to a file destination you like. 
The csv file doesn't have to exist. It will be created with the first execution of the 'add' command.

## Usage 
```
usage: ./mocp-bookmark-manager.sh <command>

  the following commands are available:
  -------------------------------------
  add [comment]             bookmark the current mocp playing position
                            with an optional comment

  go <bookmark_index>       jump to the bookmark playing position
                            the file containing the bookmark must be playing in mocp

  show <bookmark_index>     show bookmark details

  remove <bookmark_index>   remove a bookmark

  list                      list all bookmarks by file

  listp                     list playing file bookmarks

  csv                       outputs the bookmarks csv database to the terminal

                            columns:
                              bookmark index
                              filename
                              position (seconds)
                              bookmark creation date
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
 30 at 01h:01m:12s	Mi 05 Feb 2020 03:46:45 CET	shut dem down
```

### List all bookmarks
```
skremsler@morpheus:~$ bm list
bookmarks for /home/skremsler/Radio_X/RuFFM/2019-10-12_18-55_-_RadioX_-_RuFFM.mp3
 30 at 01h:01m:12s	Mi 05 Feb 2020 03:46:45 CET	shut dem down
bookmarks for /home/skremsler/Radio_X/RuFFM/2019-11-16_18-55_-_RadioX_-_RuFFM.mp3
 20 at 00h:05m:28s	Mi 05 Feb 2020 01:35:12 CET	bush choking on pretzel
bookmarks for /home/skremsler/Radio_X/RuFFM/2020-01-18_18-55_-_RadioX_-_RuFFM.mp3
  7 at 01h:02m:18s	Mi 05 Feb 2020 00:49:34 CET	fighter
 18 at 01h:02m:46s	Mi 05 Feb 2020 01:26:08 CET	full spectrum
 ```


## Ideas

- CUE file support
