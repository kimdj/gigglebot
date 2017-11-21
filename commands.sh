#!/bin/bash
# gigglebot ~ Subroutines/Commands
# Copyright (c) 2017 David Kim
# This program is licensed under the "MIT License".

read nick chan msg
IFS=''                  # internal field separator; variable which defines the char(s)
                        # used to separate a pattern into tokens for some operations
                        # (i.e. space, tab, newline)
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BOT_NICK="$(grep -P "BOT_NICK=.*" ${DIR}/bot.sh | cut -d '=' -f 2- | tr -d '"')"

function has { $(echo "$1" | grep -P "$2" > /dev/null) ; }

function say { echo "PRIVMSG $1 :$2" ; }

if [ "$chan" = "$BOT_NICK" ] ; then chan="$nick" ; fi

###############################################  Subroutines Begin  ###############################################

function send {
    while read -r line; do
      newdate=`date +%s%N`
      if [ $prevdate -gt $newdate ] ; then
        sleep `bc -l <<< "($prevdate - $newdate) / $nanos"`
        newdate=`date +%s%N`
      fi
      prevdate=$newdate+$interval
      echo "-> $1"
      echo "$line" >> ${BOT_NICK}.io
    done <<< "$1"
}

function outputSubroutine {
    filename=$1
    say $dest "$nick says:"             # show the sender's nick
    while read -r line
    do
        sleep .2
        say $dest "$line"
    done < $filename
}

function outputSubroutine2 {
    filename=$1
    while read -r line
    do
        sleep .2
        say $chan "$line"
    done < $filename
}

function countdownSubroutine {
    TIME=$(($1+1))
    CUR=$TIME
     
    t1=$(date +%T)
    while [ $CUR -gt 1 ]
    do
     CUR=$(($CUR - 1))
     sleep 1
    done
    t2=$(date +%T)
    say $chan "~~    COUNTDOWN ENDED: $t2  ~~"
    say $chan "~~  COUNTDOWN STARTED: $t1  ~~"
}

function reverbSubroutine {
    # t1=$(($(date +%s%N)/1000000))    # DEBUG: running time
    sentence=$(echo $message | sed 's/\s+/\+/')
    if [ $# -ne 0 ] ; then                                                  # case: function argument(s) exist
        d="$1"                                                              # allow user to choose font
        # pathComponent=$(echo $sentence | sed -r 's/^\w*\ *//' |           # catch the first word
        pathComponent=$(echo $sentence | sed -r 's/\+/%2B/'   |             # replace special characters with URL-encoded characters
                                         sed -r 's/!/%21/'    |
                                         sed -r 's/\?/%3F/'   |
                                         sed -r 's/@/%40/'    |
                                         sed -r 's/#/%23/'    |
                                         sed -r 's/:/%3A/'    |
                                         sed -r 's/,/%2C/'    |
                                         tr ' ' '+')                        # replace all whitespaces with '+'
    else
        d="smshadow"                                                        # or set default font to cybermedium
        pathComponent=$(echo $sentence | sed -r 's/\+/%2B/'   |
                                         sed -r 's/!/%21/'    |
                                         sed -r 's/\?/%3F/'   |
                                         sed -r 's/@/%40/'    |
                                         sed -r 's/#/%23/'    |
                                         sed -r 's/:/%3A/'    |
                                         sed -r 's/,/%2C/'    |
                                         tr ' ' '+')
    fi

    a="http://www.network-science.de/ascii/ascii.php?TEXT="
    b=$pathComponent
    c="&x=34&y=5&FONT="
    e="&RICH=no&FORM=left&STRE=no&WIDT=180"
    a+=$b
    a+=$c
    a+=$d
    a+=$e                                                                       # a is the crafted link to the ASCII art generator.

    $(curl "$a" > ascii_art/tmp/tmp.ascii.art)                                  # Download the html source code.

    ######## ORIGINAL ALGORITHM #########
    sed 's/.*<TR><TD><PRE>//' ascii_art/tmp/tmp.ascii.art > ascii_art/tmp/b
    tail -n +34 ascii_art/tmp/b > ascii_art/tmp/c                               # chopped of the first 34 lines
    grep -n '</PRE>' ascii_art/tmp/c > ascii_art/tmp/d                          # then chop off the html portion
    cat ascii_art/tmp/d | sed 's/[^0-9]*//g' > ascii_art/tmp/e                  # find the line number to delete from
    num="$(cat ascii_art/tmp/e)"
    num=$((num-1))
    head -n ${num} ascii_art/tmp/c > ascii_art/tmp/f                            # get the ascii art lines
    cat ascii_art/tmp/f | perl -MHTML::Entities -pe 'decode_entities($_);' > ascii_art/tmp/convertedAscii  # convert HTML entities to characters

    filename="ascii_art/tmp/convertedAscii"
    outputSubroutine $filename                                                  # output to irc
    # t2=$(($(date +%s%N)/1000000))    # DEBUG: running time
    # say #gigglebottestchannel "DEBUG: running time (in milliseconds) -> $((t2-t1))"
}

function reverbSubroutine2 {
    rm ascii_art/tmp/b ascii_art/tmp/c ascii_art/tmp/d                          # clean up intermediary files
    rm ascii_art/tmp/e ascii_art/tmp/f
}

function emailSubroutine {
    message=$(echo $buffer | sed -r 's/^(.+)\s(.+)/\1/')
    destination=$(echo $buffer | sed -r 's/^(.+)\s(.+)/\2/')
    echo "$message" > tmp
    echo "" >> tmp
    echo "Sent on: $(date)" >> tmp
    echo "Sent by: gigglebot!" >> tmp
    mail -s "Reminder sent from gigglebot!" -a "From: megalon@gmail.com" $destination < tmp
    rm tmp
    # mail -s "Reminder sent from gigglebot!" -a "From: gigglebot2017@gmail.com" $destination <<< $message
    say $chan "Reminder e-mail sent to $destination!"
}

function whoisSubroutine {
    found=0    # Initialize found flag to 0.
    dir=`pwd`
    if [ $# -gt 0 ] ; then                          # If an arg exists...
        handle=$(echo $1 | sed 's/ .*//')           # Just capture the first word.

        for file in "$dir"/whois/roster/* ; do      # Loop through each roster.

            # Look for the Handle in the file.
            # Otherwise, continue on the next file.
            # Note: grep matches based on anchors ^ and $.
            # The purpose is to mitigate unintentional substring matches.
            handleLine=$(cat $file | grep -in "^handle: $handle$")                              # 129:handle: handle
            if [ $handleLine ] ; then
                handleLineNumber=$(echo $handleLine | sed -e 's/\([0-9]*\):.*/\1/')             # 129
            else
                continue
            fi

            # Get the Handle.
            handle=$(sed -n ${handleLineNumber}p $file | grep -Po '(?<=(handle: )).*')          # handle

            # Get the Username.
            # Note: subpath == username in most cases.
            usernameLineNumber="$(($handleLineNumber - 1))"                                     # 128
            subpath=$(sed -n ${usernameLineNumber}p $file | grep -Po '(?<=(subpath: )).*')      # username
            if [ $file == "/u/dkim/sandbox/gigglebot/whois/roster/staff.roster" ] ; then
                say $chan "Try ⤑ https://chronicle.cat.pdx.edu/projects/cat/wiki/$subpath"
            else
                say $chan "Try ⤑ https://chronicle.cat.pdx.edu/projects/braindump/wiki/$subpath"
            fi

            # Get the Realname.
            realnameLineNumber="$(($handleLineNumber + 1))"                                     # 130
            realname=$(sed -n ${realnameLineNumber}p $file)                                     # realname
            say $chan "$handle's real name is $realname"

            # Get the Title.
            titleLineNumber="$(($handleLineNumber + 2))"                                        # 131
            title=$(sed -n ${titleLineNumber}p $file | grep -Po '(?<=(title: )).*')             # title
            if [ $title ] ; then
                say $chan "$handle $title"
            fi

            # Get the Batch and Year.
            year=$(sed -n 1p $file | grep -Po '(?<=(year: )).*')                                # 2017-2018
            batch=$(sed -n 2p $file | grep -Po '(?<=(batch: )).*')                              # Yet-To-Be-Named (YTBN)
            say $chan "$handle belongs to the $batch, $year"

            found=$(($found + 1))    # Set found flag to 1. ; done
        done

        # If a match was not found..
        if [ $found -lt 1 ] ; then
            say $chan "User not found in the CAT Roster."
        fi
    else
        say $chan "Usage: !whois username"
    fi
}

function fontlistSubroutine {
    say $chan "Try ⤑ !reverb FONT CHAN test message      Fontlist ⤑ avatar[5] banner[6] bell[6] big[6] block[5] bubble[4] chunky[4] contessa[3] cyberlarge[3] cybermedium[3] cybersmall[2] cygnet[3] digital[3] doom[6] drpepper[4] eftirobot[5] eftiwall[4] eftiwater[3] epic[8] fuzzy[5] invita[5] isometric1[11] isometric2[11] isometric3[11] isometric4[11] larry3d[7] lcd[5] lean[5] ..."
    say $chan "... marquee[7] mirror[5] ogre[5] pepper[2] puffy[6] rectangles[4] rev[11] roman[7] rounded[6] script[7] serifcap[4] shadow[4] short[2] slant[5] slscript[5] small[4] smisome1[7] smkeyboard[4] smscript[4] smshadow[3] smslant[4] speed[5] stampatello[5] standard[5] starwars[6] stellar[7] stop[6] straight[4] swan[5] thin[4] threepoint[2] usaflag[5] weird[5]"
}

function titleSubroutine {
    found=0    # Initialize found flag to 0.
    dir=`pwd`
    if [ $# -gt 0 ] ; then                              # If an arg exists...
        handle=$(echo $1 | sed 's/ .*//')               # Just capture the first word.
        newTitle=$(echo $1 | cut -d " " -f2-)           # Capture the remaining words.

        if [ ! $handle ] ; then
            say $chan "input error"
            return 1
        fi

        for file in "$dir"/whois/roster/* ; do      # Loop through each roster.

            # Look for the Handle in the file.
            # Otherwise, continue on the next file.
            # Note: grep matches based on anchors ^ and $.
            # The purpose is to mitigate unintentional substring matches.
            handleLine=$(cat $file | grep -in "^handle: $handle$")                              # 129:handle: handle
            if [ $handleLine ] ; then
                handleLineNumber=$(echo $handleLine | sed -e 's/\([0-9]*\):.*/\1/')             # 129
            else
                continue
            fi

            # Modify the Title.
            titleLineNumber="$(($handleLineNumber + 2))"
            oldTitle=$(sed -n ${titleLineNumber}p $file | grep -Po '(?<=(title: )).*')          # title

            if [[ $newTitle == $handle ]] ; then                                                # clear title
                newTitle=''
            fi

            if [ -n "$newTitle" ] ; then
                say $chan "$handle's title was modified"
                $(sed -i "${titleLineNumber}s|.*|title: ${newTitle}|" $file)                    # replace title with new title
                currentTitle=$(sed -n ${titleLineNumber}p $file | grep -Po '(?<=(title: )).*')  # title
            else
                say $chan "$handle's title was cleared"
                $(sed -i "${titleLineNumber}s/.*/title: /" $file)                               # clear title
            fi

            found=$(($found + 1))    # Set found flag to 1. ; done
        done

        # If a match was not found..
        if [ $found -lt 1 ] ; then
            say $chan "User not found in the CAT Roster."
        fi
    else
        say $chan "Usage: !whois username"
    fi
}

function aboutSubroutine {
    say $chan "╔═════════════════════════════════════╗"
    say $chan "║  ~~ I live in /u/dkim/gigglebot ~~  ║"
    say $chan "║     github.com/kimdj/gigglebot      ║"
    say $chan "╚═════════════════════════════════════╝"
}

function helpSubroutine {
    say $chan "╔══════════════════════════════════════════════════════════════╗"
    say $chan "║         Usage  ~>  !alive   !hare   !gigglebot   !gb         ║"
    say $chan "║  !giggle   !countdown 3   !read   !write a message   !about  ║"
    say $chan "║   !reverb [font]? [chan | user] this is a msg   !fontlist    ║"
    # say $chan "║          !remind me about a reminder dest@email.com          ║"
    say $chan "║       !whois _sharp   !title _sharp is a DOG   !marco        ║"
    say $chan "║             !listprinters   !listnix   !listlabs             ║"
    say $chan "║      Full Font List  ~>  web.cecs.pdx.edu/~dkim/fontlist     ║"
    say $chan "╚══════════════════════════════════════════════════════════════╝"
}

################################################  Subroutines End  ################################################

# Ω≈ç√∫˜µ≤≥÷åß∂ƒ©˙∆˚¬…ææœ∑´®†¥¨ˆøπ“‘¡™£¢∞••¶•ªº–≠«‘“«`
# ─━│┃┄┅┆┇┈┉┊┋┌┍┎┏┐┑┒┓└┕┖┗┘┙┚┛├┝┞┟┠┡┢┣┤┥┦┧┨┩┪┫┬┭┮┯┰┱┲┳┴┵┶┷┸┹┺┻┼┽┾┿╀╁╂╃╄╅╆╇╈╉╊╋╌╍╎╏
# ═║╒╓╔╕╖╗╘╙╚╛╜╝╞╟╠╡╢╣╤╥╦╧╨╩╪╫╬╭╮╯╰╱╲╳╴╵╶╷╸╹╺╻╼╽╾╿

################################################  Commands Begin  #################################################

# Help Command.

if has "$msg" "!gigglebot" || has "$msg" "!gb" ; then
    helpSubroutine

elif has "$msg" "gigglebot: help" ; then
    helpSubroutine

# Giggle.

elif has "$msg" "gigglebot: !giggle" || has "$msg" "gb: !giggle" || has "$msg" "!giggle" ; then
    filename="ascii_art/giggle"
    outputSubroutine2 $filename    

# Hare.

elif has "$msg" "gigglebot: !hare" || has "$msg" "gb: !hare" || has "$msg" "!hare" ; then
    filename="ascii_art/hare"
    outputSubroutine2 $filename

# Marco-Polo.

elif has "$msg" "gigglebot: !marco" || has "$msg" "gb: !marco" || has "$msg" "!marco" ; then
    a="^gigglebot:[[:space:]]!marco"
    b="^gb:[[:space:]]!marco"
    c="^!marco"
    if [[ "$msg" =~ $a ]] || [[ "$msg" =~ $b ]] || [[ "$msg" =~ $c ]] ; then
        say $chan "polo!"
    fi

# Alive?.

elif has "$msg" "gigglebot: !alive?" || has "$msg" "gb: !alive?" || has "$msg" "!alive?" ; then
    a="^gigglebot:[[:space:]]!alive?"
    b="^gb:[[:space:]]!alive?"
    c="^!alive?"
    if [[ "$msg" =~ $a ]] || [[ "$msg" =~ $b ]] || [[ "$msg" =~ $c ]] ; then
        say $chan "running!"
    fi

# A tidbit on this script.

elif has "$msg" "gigglebot: !about?" || has "$msg" "gb: !about?" || has "$msg" "!about?" ; then
    a="^gigglebot:[[:space:]]!about?"
    b="^gb:[[:space:]]!about?"
    c="^!about?"
    if [[ "$msg" =~ $a ]] || [[ "$msg" =~ $b ]] || [[ "$msg" =~ $c ]] ; then
        aboutSubroutine
    fi

# Reverb. Converts text to ASCII art. 

elif has "$msg" "gigglebot: !reverb" ; then
    words=$(echo $msg | sed -r 's/^.{19}//')
    reverbSubroutine
    reverbSubroutine2

elif has "$msg" "gb: !reverb" ; then
    words=$(echo $msg | sed -r 's/^.{12}//')
    reverbSubroutine
    reverbSubroutine2

elif has "$msg" "!reverb" ; then
    if [[ "$msg" =~ ^!reverb ]] ; then                                              # make sure the incoming msg begins properly
        words=$(echo $msg | sed -r 's/^.{8}//')                                     # cut out the '!reverb'
        found=0
        while read font; do                                                         # Validate requested font.
            firstWord=$(echo $words | sed -e 's|\([[:space:]].*\)||')               # get the first word (font)
            if [ $firstWord == $font ] ; then                                       # case: first word is in fontlist.
                found=1
                dest=$(echo $words | sed -e 's|[a-zA-Z]*[[:space:]]\([#a-zA-Z]*\)[[:space:]].*|\1|')                # get the destination
                message=$(echo $words | sed -e 's|\([a-zA-Z0-9]*[[:space:]][#_a-zA-Z0-9]*[[:space:]]\)||')          # get the message

                reverbSubroutine $font
                reverbSubroutine2
                break
            fi ; done < ascii_art/fontlist
        if [ $found -eq 0 ] ; then
            firstWord=$(echo $words | sed -e 's|\([[:space:]].*\)||')               # get the first word (destination)
            dest=$firstWord                                                         # set the destination
            message=$(echo $words | sed -e 's|\([#_a-zA-Z0-9]*[[:space:]]\)||')     # get the message

            reverbSubroutine
            reverbSubroutine2
        fi
    fi

# Countdown.

elif has "$msg" "gigglebot: !countdown" ; then
    SEC=$(echo $msg | sed -r 's/^.{22}//') 
    countdownSubroutine $SEC

elif has "$msg" "gb: !countdown" ; then
    SEC=$(echo $msg | sed -r 's/^.{15}//') 
    countdownSubroutine $SEC

elif has "$msg" "!countdown" ; then
    SEC=$(echo $msg | sed -r 's/^.{11}//') 
    countdownSubroutine $SEC

# Write.

elif has "$msg" "gigglebot: !write" ; then
    message=$(echo $msg | sed -r 's/^.{18}//') 
    i=$(echo $message > read)

elif has "$msg" "gb: !write" ; then
    message=$(echo $msg | sed -r 's/^.{11}//') 
    i=$(echo $message > read)

elif has "$msg" "!write" ; then
    if [[ "$msg" =~ ^!write ]] ; then
        message=$(echo $msg | sed -r 's/^.{7}//') 
        i=$(echo $message > read)
    fi

# Read.

elif has "$msg" "gigglebot: !read" || has "$msg" "gb: !read" || has "$msg" "!read" ; then
    if [[ "$msg" =~ ^!read ]] ; then
        filename="read"
        outputSubroutine2 $filename
    fi

# # Send a reminder in an e-mail.
# #      Source: dkim@cat.pdx.edu
# # Destination: Specified E-mail Address

# elif has "$msg" "gigglebot: !remind me" ; then
#     buffer=$(echo $msg | sed -r 's/^.{12}//') 
#     emailSubroutine

# elif has "$msg" "gb: !remind me" ; then
#     buffer=$(echo $msg | sed -r 's/^.{5}//') 
#     emailSubroutine

# elif has "$msg" "!remind me" ; then
#     buffer=$(echo $msg | sed -r 's/^.{1}//') 
#     emailSubroutine

# Whois.

elif has "$msg" "gigglebot: !whois" ; then
    # if [[ "$msg" =~ ^gigglebot: !whois ]] ; then
        handle=$(echo $msg | sed -r 's/^.{18}//')
        whoisSubroutine $handle
    # fi

elif has "$msg" "gb: !whois" ; then
    say _sharp "TESTING"
    if [[ "$msg" =~ ^gb:[[:space:]]!whois ]] ; then
        say _sharp "FOOBAR"
        handle=$(echo $msg | sed -r 's/^.{11}//') 
        whoisSubroutine $handle
    fi

elif has "$msg" "!whois" ; then
    if [[ "$msg" =~ ^!whois ]] ; then
        handle=$(echo $msg | sed -r 's/^.{7}//') 
        whoisSubroutine $handle
    fi

# Change title.

elif has "$msg" "!title" ; then
    if [[ "$msg" =~ ^!title ]] ; then
        title=$(echo $msg | sed -r 's/^.{7}//') 
        titleSubroutine $title
    fi

# Fontlist.

elif has "$msg" "gigglebot: !fontlist" ; then
    if [[ "$msg" =~ "^gigglebot: !fontlist" ]] ; then
        fontlistSubroutine
    fi

elif has "$msg" "gb: !fontlist" ; then
    if [[ "$msg" =~ "^gb: !fontlist" ]] ; then
        fontlistSubroutine
    fi

elif has "$msg" "!fontlist" ; then
    if [[ "$msg" =~ ^!fontlist ]] ; then
        fontlistSubroutine
    fi

# Inject a command.
# Have gigglebot send an IRC command to the IRC server.
elif has "$msg" "!injectcmd" ; then
    if [[ $nick == "_sharp" ]] || [[ $nick == "MattDamon" ]]; then    # only _sharp can execute this command
        if [[ "$msg" =~ ^!injectcmd ]] ; then
            message=$(echo $msg | sed -r 's/^.{11}//') 
            send "$message"
        fi
    fi

# Have gigglebot send a message.
elif has "$msg" "!sendcmd" ; then
    if [[ $nick == "_sharp" ]] || [[ $nick == "MattDamon" ]]; then    # only _sharp can execute this command
        if [[ "$msg" =~ ^!sendcmd ]] ; then
            buffer=$(echo $msg | sed -re 's/^.{9}//')
            user=$(echo $buffer | sed -e "s| .*||")
            message=$(echo $buffer | cut -d " " -f2-)
            say $user "$message"
        fi
    fi

# Labs list.
# have gigglebot send a private message to the user

elif has "$msg" "!listlabs" ; then
    if [[ "$msg" =~ ^!listlabs ]] ; then
        filename=labs
        while read -r line ; do
            sleep .2
            say $nick "$line" ; done < $filename
        say $nick "----This file is located in /u/dkim/labs"
        say $nick "----For more info, visit: https://chronicle.cat.pdx.edu/projects/deskcat-manual/wiki/Printer_and_Lab_Checks#The-lab-check-routine"
    fi

# *nix machine list.
# have gigglebot send a private message to the user

elif has "$msg" "!listnix" ; then
    if [[ "$msg" =~ ^!listnix ]] ; then
        filename=nixlist.column
        while read -r line ; do
            sleep .2
            say $nick "$line" ; done < $filename
        say $nick "----This file is located in /u/dkim/nixlist.column"
        say $nick "----Full list is located in /u/dkim/nixlist.sorted"
    fi

# Wintel list.
# have gigglebot send a private message to the user

# elif has "$msg" "!wintellist" ; then
#     if [[ "$msg" =~ ^!wintellist ]] ; then


# Printer list.
# have gigglebot send a private message to the user

elif has "$msg" "!listprinters" ; then
    if [[ "$msg" =~ ^!listprinters ]] ; then
        filename=printers
        while read -r line ; do
            sleep .2
            say $nick "$line" ; done < $filename
        say $nick "----This file is located in /u/dkim/printers"
        say $nick "----For more info, visit: https://chronicle.cat.pdx.edu/projects/deskcat-manual/wiki/Printer_and_Lab_Checks#The-lab-check-routine"
    fi

# List of floorplans.
elif has "$msg" "!floorplans" ; then
    if [[ "$msg" =~ ^!floorplans ]] ; then
        say $chan "FAB floorplans: https://www.pdx.edu/floorplans/sites/www.pdx.edu.floorplans/files/floorplans/floorplans/FAB-All%20Plan.pdf"
        say $chan "EB floorplans: https://www.pdx.edu/floorplans/sites/www.pdx.edu.floorplans/files/floorplans/floorplans/EB-All%20Plans.pdf"
    fi

fi

#################################################  Commands End  ##################################################
