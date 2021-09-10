#!/bin/bash

trap 'stty icanon echo; tput cup $(tput lines) 0; tput smam; exit 0' INT

case $# in
  0) dir=. ;;
  1) dir=$1 ;;
  *) echo "Usage: showDir [ dir-name ]" >&2
    exit 1 ;;
esac
if [ ! -d $dir ]
  then echo "showDir: $dir is not a valid directory name" >&2
    exit 1
fi

clear
# initial display with instructions at the bottom
tput cup $(($(tput lines)-4)) 0
echo "Valid keys: k (up), j (down): move between Dir_Names"
echo "            h (left), l (right): move between permission"
echo "            r, w, x, -: change permission; q: quit"

tput cup 0
redraw=yes

# turn on non-canonical mode
stty -icanon min 1 time 0 -echo

cd $dir

# array of directories from root to current directory
directories=(/ $(echo $PWD | tr "/" " "))

numberOfDirectories=${#directories[@]}

# full path of selected directory
selectedDir=$PWD

#number of directories in the path
selectedDirIndex=$numberOfDirectories

# initial line and column for cursor position
line=$((1 + $numberOfDirectories * 2))
column=24


while true
do
    # disable output lines to wrap to the next line
    tput rmam

    # selected user at specific column
    if [[ $column -eq 0 || $column -eq 2 || $column -eq 4 ]]; then
        user=u
    elif [[ $column -eq 8 || $column -eq 10 || $column -eq 12 ]]; then
        user=g
    elif [[ $column -eq 16 || $column -eq 18 || $column -eq 20 ]]; then
        user=o
    else
        user=na
    fi

    # selected permission at specific column
    if [[ $column -eq 0 || $column -eq 8 || $column -eq 16 ]]; then
        permission=r
    elif [[ $column -eq 2 || $column -eq 10 || $column -eq 18 ]]; then
        permission=w
    elif [[ $column -eq 4 || $column -eq 12 || $column -eq 20 ]]; then
        permission=x
    fi

    if [ $redraw == yes ]; then
        tput civis #disable cursor
        tput cup 0
        echo "Owner   Group   Other   Dir_Name"
        echo "-----   -----   -----   --------"
        echo
        
        for dir in ${directories[*]}
        do
            if [ $dir == / ]; then
                cd /
                ls -ld | sed "s/./& /g" | sed -r "s/(.{2})(.{6})(.{6})(.{6}).*/\2  \3  \4  \//"
            else
                cd $dir 2>/dev/null
                ls -ld | sed "s/./& /g" | sed -r "s/(.{2})(.{6})(.{6})(.{6}).*/\2  \3  \4  $dir/"
            fi
            
            if [ $PWD == $selectedDir ]; then
                ls -ld | awk '{ print "  Links: " $2 "  Owner: " $3 "  Group: " $4 "  Size: " $5 "  Modified: " $6, $7, $8 }' FS=' '
            else
                tput el #clear line
                echo
            fi
        done
        
        redraw=no
        tput cup $line $column
        tput cnorm #enable cursor
    fi
    

    command=$(dd bs=3 count=1 2> /dev/null)
    case $command in
        k)  if [ $line -gt 3 ]; then
                line=$(($line - 2))
                
                total=${#directories[@]}
                diff=$((${#directories[@]} - $selectedDirIndex))
                for ((i = $diff ; i >= 0 ; i--)); do
                    cd ..
                done
                selectedDir=$PWD
                selectedDirIndex=$(($selectedDirIndex - 1))
            fi
            redraw=yes ;;
           
        j)  if [ $line -lt $(( 1 + $numberOfDirectories * 2)) ]; then
               line=$(($line + 2))
                
                for ((i = 0 ; i <= $selectedDirIndex ; i++)); do
                    cd ${directories[$i]}
                done
                selectedDir=$PWD
                selectedDirIndex=$(($selectedDirIndex + 1))
            fi
            redraw=yes ;;

        h)  if [[ $column -eq 24 || $column -eq 16 || $column -eq 8 ]]; then
                column=$(($column - 4))
            elif [[ $column -lt 21 && $column -gt 16 ]]; then
                column=$(($column - 2))
            elif [[ $column -lt 13 && $column -gt 8 ]]; then
                column=$(($column - 2))
            elif [[ $column -lt 5 && $column -gt 0 ]]; then
                column=$(($column - 2))
            fi
            redraw=yes ;;
            
        l)  if [[ $column -eq 4 || $column -eq 12 || $column -eq 20 ]]; then
                column=$(($column + 4))
            elif [[ $column -ge 0 && $column -lt 4 ]]; then
                column=$(($column + 2))
            elif [[ $column -ge 6 && $column -lt 12 ]]; then
                column=$(($column + 2))
            elif [[ $column -gt 14 && $column -lt 20 ]]; then
                column=$(($column + 2))
            fi
            redraw=yes ;;

        r)  if [ $permission == r ]; then
                chmod $user+r $selectedDir &> /dev/null
                redraw=yes
            fi ;;

        w)  if [ $permission == w ]; then
                chmod $user+w $selectedDir &> /dev/null
                redraw=yes
            fi ;;

        x)  if [ $permission == x ]; then
                chmod $user+x $selectedDir &> /dev/null
                redraw=yes
            fi ;;
            
        -)  if [ ! $user == na ]; then
                chmod $user-$permission $selectedDir &> /dev/null
                redraw=yes
            fi ;;
    
        q)  # turn on canonical mode
            stty icanon echo
            #position cursor at the bottom
            tput cup $(tput lines) 0
            # enable output lines to wrap to the next line
            tput smam
            exit 0 ;;
    esac
done
