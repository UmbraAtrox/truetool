#!/bin/bash

## Simple shortcut to just list the backups without promts and such
listBackups(){
echo -e "${BWhite}Backup Listing Tool${Color_Off}"
clear -x && echo "pulling all restore points.."
list_backups=$(cli -c 'app kubernetes list_backups' | grep -v system-update | sort -t '_' -Vr -k2,7 | tr -d " \t\r"  | awk -F '|'  '{print $2}' | nl | column -t)
[[ -z "$list_backups" ]] && echo -e "${IRed}No restore points available${Color_Off}" && exit || echo "Detected Backups:" && echo "$list_backups"
}
export -f listBackups

## Lists backups, except system-created backups, and promts which one to delete
deleteBackup(){
echo -e "${BWhite}Backup Deletion Tool${Color_Off}"
while true
do
    clear -x && echo "pulling all restore points.."
    list_backups=$(cli -c 'app kubernetes list_backups' | sort -t '_' -Vr -k2,7 | tr -d " \t\r"  | awk -F '|'  '{print $2}' | nl -s ") " | column -t)
    if [[ -z "$list_backups" ]]; then
        echo "No restore points available"
        exit
    fi
    while true
    do
        clear -x
        title
        echo -e "Choose a Restore Point to Delete\nThese may be out of order if they are not TrueTool backups"
        echo "$list_backups"
        echo
        echo "0)  Exit"
        read -rt 240 -p "Please type a number: " selection || { echo -e "\nFailed to make a selection in time" ; exit; }
        restore_point=$(echo "$list_backups" | grep ^"$selection)" | awk '{print $2}')
        if [[ $selection == 0 ]]; then
            echo "Exiting.."
            exit
        elif [[ -z "$selection" ]]; then
            echo "Your selection cannot be empty"
            sleep 3
            continue
        elif [[ -z "$restore_point" ]]; then
            echo "Invalid Selection: $selection, was not an option"
            sleep 3
            continue
        fi
        break # Break out of the loop if all of the If statement checks above are untrue
    done
    while true
    do
        clear -x
        echo -e "WARNING:\nYou CANNOT go back after deleting your restore point"
        echo -e "\n\nYou have chosen:\n$restore_point\n\n"
        read -rt 120 -p "Would you like to proceed with deletion? (y/N): " yesno  || { echo -e "\nFailed to make a selection in time" ; exit; }
        case $yesno in
            [Yy] | [Yy][Ee][Ss])
                echo -e "\nDeleting $restore_point"
                cli -c 'app kubernetes delete_backup backup_name=''"'"$restore_point"'"' &>/dev/null || { echo "Failed to delete backup.."; exit; }
                echo "Sucessfully deleted"
                break
                ;;
            [Nn] | [Nn][Oo])
                echo "Exiting"
                exit
                ;;
            *)
                echo "That was not an option, try again"
                sleep 3
                continue
                ;;
        esac
    done
    while true
    do
        read -rt 120 -p "Delete more backups? (y/N): " yesno || { echo -e "\nFailed to make a selection in time" ; exit; }
        case $yesno in
            [Yy] | [Yy][Ee][Ss])
                break
                ;;
            [Nn] | [Nn][Oo])
                exit
                ;;
            *)
                echo "$yesno was not an option, try again"
                sleep 2
                continue
                ;;

        esac

    done
done
}
export -f deleteBackup

## Creates backups and deletes backups if a "backups to keep"-count is exceeded.
# backups-to-keep takes only heavyscript and truetool created backups into account, as other backups aren't guaranteed to be sorted correctly
backup(){
echo_backup+=("🄱 🄰 🄲 🄺 🅄 🄿 🅂")
echo_backup+=("Number of backups was set to $number_of_backups")
date=$(date '+%Y_%m_%d_%H_%M_%S')
[[ "$verbose" == "true" ]] && cli -c 'app kubernetes backup_chart_releases backup_name=''"'TrueTool_"$date"'"' &> /dev/null && echo_backup+=(TrueTool_"$date")
[[ -z "$verbose" ]] && echo_backup+=("\nNew Backup Name:") && cli -c 'app kubernetes backup_chart_releases backup_name=''"'TrueTool_"$date"'"' | tail -n 1 &> /dev/null && echo_backup+=(TrueTool_"$date")
mapfile -t list_backups < <(cli -c 'app kubernetes list_backups' | grep "HeavyScript\|TrueTool_" | sort -t '_' -Vr -k2,7 | awk -F '|'  '{print $2}'| tr -d " \t\r")
if [[  ${#list_backups[@]}  -gt  "$number_of_backups" ]]; then
    echo_backup+=("\nDeleted the oldest backup(s) for exceeding limit:")
    overflow=$(( ${#list_backups[@]} - "$number_of_backups" ))
    mapfile -t list_overflow < <(cli -c 'app kubernetes list_backups' | grep "TrueTool_"  | sort -t '_' -V -k2,7 | awk -F '|'  '{print $2}'| tr -d " \t\r" | head -n "$overflow")
    for i in "${list_overflow[@]}"
    do
        cli -c 'app kubernetes delete_backup backup_name=''"'"$i"'"' &> /dev/null || echo_backup+=("Failed to delete $i")
        echo_backup+=("$i")
    done
fi

#Dump the echo_array, ensures all output is in a neat order.
for i in "${echo_backup[@]}"
do
    echo -e "$i"
done
echo
echo
}
export -f backup

## Lists available backup and prompts the users to select a backup to restore
restore(){
echo -e "${BWhite}Backup Restoration Tool${Color_Off}"
while true
do
    clear -x && echo "pulling restore points.."
    list_backups=$(cli -c 'app kubernetes list_backups' | grep "TrueTool_" | sort -t '_' -Vr -k2,7 | tr -d " \t\r"  | awk -F '|'  '{print $2}' | nl -s ") " | column -t)
    if [[ -z "$list_backups" ]]; then
        echo "No TrueTool restore points available"
        exit
    fi
    while true
    do
        clear -x
        title
        echo "Choose a Restore Point"
        echo "$list_backups"
        echo
        echo "0)  Exit"
        read -rt 240 -p "Please type a number: " selection || { echo -e "\nFailed to make a selection in time" ; exit; }
        restore_point=$(echo "$list_backups" | grep ^"$selection)" | awk '{print $2}')
        if [[ $selection == 0 ]]; then
            echo "Exiting.."
            exit
        elif [[ -z "$selection" ]]; then
            echo "Your selection cannot be empty"
            sleep 3
            continue
        elif [[ -z "$restore_point" ]]; then
            echo "Invalid Selection: $selection, was not an option"
            sleep 3
            continue
        fi
        break
    done
    while true
    do
        clear -x
        echo -e "WARNING:\nThis is NOT guranteed to work\nThis is ONLY supposed to be used as a LAST RESORT\nConsider rolling back your applications instead if possible"
        echo -e "\n\nYou have chosen:\n$restore_point\n\n"
        read -rt 120 -p "Would you like to proceed with restore? (y/N): " yesno || { echo -e "\nFailed to make a selection in time" ; exit; }
        case $yesno in
            [Yy] | [Yy][Ee][Ss])
                echo -e "\nStarting Backup, this will take a LONG time."
                cli -c 'app kubernetes restore_backup backup_name=''"'"$restore_point"'"' || { echo "Failed to delete backup.."; exit; }
                exit
                ;;
            [Nn] | [Nn][Oo])
                echo "Exiting"
                exit
                ;;
            *)
                echo "That was not an option, try again"
                sleep 3
                continue
                ;;
        esac
    done
done
}
export -f restore
