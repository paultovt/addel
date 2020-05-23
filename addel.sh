#!/bin/bash

export NEWT_COLORS='
    root=,gray
    checkbox=,gray
    entry=,gray
    label=gray,
    actlistbox=,gray
    helpline=,gray
    roottext=,gray
    emptyscale=gray
    disabledentry=gray,
    checkbox=black,lightgray'

SCRIPT_DIR="$(cd "$( dirname "$0" )" && pwd)"
SERVERLIST=$(cat $SCRIPT_DIR/servers.lst | grep -v '^#' | grep -v '^$' | expand | tr -s " " | tr " " ":")

BACKTITLE="ADD/DELETE USERS TO/FROM LINUX SERVERS"
OPTIONS=("Add users to servers" "" 
        "Delete user from servers" ""
        "" ""
        "Add new user to <keys> folder" ""
        "Add new server to servers list" "")

ACTION=$(whiptail --clear --backtitle "$BACKTITLE" --menu "Select action:" 0 45 0 "${OPTIONS[@]}" 2>&1 >/dev/tty)

if [ "$ACTION" ]
then
    
    if [ "$ACTION" == "Add users to servers" ]
    then
        USERLIST=$(ls $SCRIPT_DIR/keys)
        USRCMD='whiptail --clear --backtitle "'$BACKTITLE'" --checklist "Select users to add:" 0 0 0'
        for EACH in $USERLIST
        do
            USRCMD=$"$USRCMD \"$EACH\" \"\" off"
        done
        USRCMD=$"$USRCMD 2>&1 >/dev/tty"
        USERS=$(eval ${USRCMD[@]} | tr -d \")
        echo $USERNUMS
        if [ -z "$USERS" ]
        then
            exit 0
        fi

        AUTH=$(whiptail --clear --backtitle "$BACKTITLE" --menu "How do you prefer to authenticate?" 0 0 0 "Root user (with password)" "" "YOUR sudo user (with pubkey)" "" 2>&1 >/dev/tty)
        if [ "$AUTH" ]
        then
            if [ "$AUTH" == "Root user (with password)" ]
            then
                AUTHMETH='1'
                LOGIN='root'
                SUDOPASS=$(whiptail --clear --backtitle "$BACKTITLE" --passwordbox "Enter root password:" 8 40 2>&1 >/dev/tty)
                if [ -z "$SUDOPASS" ]
                then
                    exit 0
                fi
            elif [ "$AUTH" == "YOUR sudo user (with pubkey)" ]
            then
                AUTHMETH='2'
                LOGIN=$(whiptail --clear --backtitle "$BACKTITLE" --inputbox "Enter YOUR SSH login:" 8 40 2>&1 >/dev/tty)
                if [ -z "$LOGIN" ]
                then
                    exit 0
                fi
                SUDOPASS=$(whiptail --clear --backtitle "$BACKTITLE" --passwordbox "Enter YOUR sudo password:" 8 40 2>&1 >/dev/tty)
                if [ -z "$SUDOPASS" ]
                then
                    exit 0
                fi
            fi
        else
            exit 0
        fi

        MAKESUDO=$(whiptail --clear --backtitle "$BACKTITLE" --yesno "Add users to sudoers?" 0 0 0 2>&1 >/dev/tty && echo 1 || echo 0)
        if [ "$MAKESUDO" ]
        then
            if [ $MAKESUDO -eq 1 ]
            then
                USERPASS=$(whiptail --clear --backtitle "$BACKTITLE" --passwordbox "Enter sudo password for new users:" 8 40 2>&1 >/dev/tty)
                if [ -z "$USERPASS" ]
                then
                    exit 0
                fi
            else
                USERPASS="nopass"
            fi
        else
            exit 0
        fi

        SRVCMD='whiptail --clear --backtitle "'$BACKTITLE'" --checklist "Select servers:" 0 40 0'
        s=0
        for EACH in $SERVERLIST
        do
            ((s++))
            IP=$(echo $EACH | cut -f1 -d":")
            NAME=$(echo $EACH | cut -f3- -d":")
            PORT=$(echo $EACH | cut -f2 -d":")
            SRVCMD=$"$SRVCMD \"$IP\" \"${NAME//:/ }\" off"
        done
        SRVCMD=$"$SRVCMD 2>&1 >/dev/tty"
        SERVERNUMS=$(eval ${SRVCMD[@]} | tr -d \")
        if [ "$SERVERNUMS" ]
        then
            SERVERS=''
            for SERVER in $SERVERNUMS
            do
                SERVERS=$"$SERVERS $(cat $SCRIPT_DIR/servers.lst | grep -v '^#' | grep -v '^$' | expand | tr -s " " | tr " " ":" | grep $SERVER)"
            done
        else
            exit 0
        fi

        echo '
        #!/usr/bin/expect

        set ip [lindex $argv 0]
        set port [lindex $argv 1]
        set auth [lindex $argv 2]
        set login [lindex $argv 3]
        set pass $env(SUDOPASS)
        set user [lindex $argv 4]
        set makesudo [lindex $argv 5]
        set userpass $env(USERPASS)

        set basedir [file dirname $argv0]

        if { $ip eq "" || $port eq "" || $login eq "" || $pass eq "" || $user eq "" } {
            exit
        }
        
        log_user 1
        set timeout 5

        puts "\n\033\[01;34mAdding $user to server\033\[00;0m"
        if { $auth eq "1" } {
            spawn -noecho ssh -t -o "UserKnownHostsFile=/dev/null" -o "StrictHostKeyChecking=no" -p $port root@$ip useradd -m -s /bin/bash $user
            expect {
                "assword:" {
                    send "$pass\r"
                    puts "password entered"
                }
                "denied" {
                    puts "\033\[01;31m$ip: Permission denied\033\[00;0m"
                    exit 1
                }
                timeout {
                    puts "\033\[01;31m$ip: Connection timeout\033\[00;0m"
                    exit 1
                }
            }
            expect eof
        } else {
            spawn -noecho ssh -t -o "UserKnownHostsFile=/dev/null" -o "StrictHostKeyChecking=no" -p $port $login@$ip sudo useradd -m -s /bin/bash $user
            expect {
                "sudo" {
                    send "$pass\r"
                    puts "sudo password entered"
                }
                "denied" {
                    puts "\033\[01;31m$ip: Permission denied\033\[00;0m"
                    exit 1
                }
                timeout {
                    puts "\033\[01;31m$ip: Connection timeout\033\[00;0m"
                    exit 1
                }
            }
            expect eof
        }
        
        if { $makesudo eq "1" } {
            puts "\n\033\[01;34mAdding $user to sudoers\033\[00;0m"
            if { $auth eq "1" } {
                spawn -noecho ssh -t -o "UserKnownHostsFile=/dev/null" -o "StrictHostKeyChecking=no" -p $port root@$ip usermod -aG wheel $user ";" usermod -aG sudo $user
                expect "assword:"
                send "$pass\r"
                puts "password entered"
                expect eof
            } else {
                spawn -noecho ssh -t -o "UserKnownHostsFile=/dev/null" -o "StrictHostKeyChecking=no" -p $port $login@$ip sudo usermod -aG wheel $user ";" sudo usermod -aG sudo $user
                expect "sudo"
                send "$pass\r"
                puts "sudo password entered"
                expect eof
            }
        
            puts "\n\033\[01;34mChanging users password\033\[00;0m"
            if { $auth eq "1" } {
                spawn -noecho ssh -t -o "UserKnownHostsFile=/dev/null" -o "StrictHostKeyChecking=no" -p $port root@$ip passwd $user
                expect "assword:"
                sleep 0.5
                send "$pass\r"
                puts "password entered"
                expect ":"
                sleep 0.5
                send "$userpass\r"
                expect ":"
                sleep 0.5
                send "$userpass\r"
                puts "user password entered"
                expect eof
            } else {
                spawn -noecho ssh -t -o "UserKnownHostsFile=/dev/null" -o "StrictHostKeyChecking=no" -p $port $login@$ip sudo passwd $user
                expect "sudo"
                sleep 0.5
                send "$pass\r"
                puts "sudo password entered"
                expect ":"
                sleep 0.5
                send "$userpass\r"
                expect ":"
                sleep 0.5
                send "$userpass\r"
                puts "user password entered"
                expect eof
            }
        }
        
        puts "\n\033\[01;34mCopying key files\033\[00;0m"
        if { $auth eq "1" } {
            spawn -noecho scp -o "UserKnownHostsFile=/dev/null" -o "StrictHostKeyChecking=no" -r -P $port $basedir/keys/$user/.ssh root@$ip:/home/$user/
            expect "assword:"
            send "$pass\r"
            puts "password entered"
            expect eof
        } else {
            spawn -noecho scp -o "UserKnownHostsFile=/dev/null" -o "StrictHostKeyChecking=no" -r -P $port $basedir/keys/$user/.ssh $login@$ip:/tmp/
            expect eof
        }
        
        if { $auth eq "2" } {
            spawn -noecho ssh -t -o "UserKnownHostsFile=/dev/null" -o "StrictHostKeyChecking=no" -p $port $login@$ip sudo mv /tmp/.ssh /home/$user/
            expect "sudo"
            send "$pass\r"
            puts "sudo password entered"
            expect eof
        }

        puts "\n\033\[01;34mChmoding key files\033\[00;0m"
        if { $auth eq "1" } {
            spawn -noecho ssh -t -o "UserKnownHostsFile=/dev/null" -o "StrictHostKeyChecking=no" -p $port root@$ip chown -R $user. /home/$user/.ssh/ ";" chmod 700 /home/$user/.ssh/ ";" sudo chmod 600 /home/$user/.ssh/authorized_keys
            expect "assword:"
            send "$pass\r"
            puts "password entered"
            expect eof
        } else {
            spawn -noecho ssh -t -o "UserKnownHostsFile=/dev/null" -o "StrictHostKeyChecking=no" -p $port $login@$ip sudo chown -R $user. /home/$user/.ssh/ ";" sudo chmod 700 /home/$user/.ssh/ ";" sudo chmod 600 /home/$user/.ssh/authorized_keys
            expect "sudo"
            send "$pass\r"
            puts "sudo password entered"
            expect eof
        }' > $SCRIPT_DIR/add_ssh.exp

        for USER in $USERS
        do
            for SERVER in $SERVERS
            do
                IP=$(echo $SERVER | cut -f1 -d":")
                SERVERNAME=$(echo $SERVER | cut -f3 -d":")
                PORT=$(echo $SERVER | cut -f2 -d":")
                echo
                echo -e "\n$(tput setaf 3)$(tput bold)Adding $USER to $SERVERNAME ($IP)$(tput sgr 0)"
                SUDOPASS=$SUDOPASS USERPASS=$USERPASS expect $SCRIPT_DIR/add_ssh.exp $IP $PORT $AUTHMETH $LOGIN $USER $MAKESUDO
            done
        done
        rm $SCRIPT_DIR/add_ssh.exp


    elif [ "$ACTION" == "Delete user from servers" ]
    then
        USER=$(whiptail --clear --backtitle "$BACKTITLE" --inputbox "Enter user to DELETE:" 8 40 2>&1 >/dev/tty)
        if [ -z "$USER" ]
        then
            exit 0
        fi
        LOGIN=$(whiptail --clear --backtitle "$BACKTITLE" --inputbox "Enter YOUR SSH login:" 8 40 2>&1 >/dev/tty)
        if [ -z "$LOGIN" ]
        then
            exit 0
        fi
        SUDOPASS=$(whiptail --clear --backtitle "$BACKTITLE" --passwordbox "Enter YOUR sudo password:" 8 40 2>&1 >/dev/tty)
        if [ -z "$SUDOPASS" ]
        then
            exit 0
        fi

        SRVCMD='whiptail --clear --backtitle "$BACKTITLE" --checklist "Select servers:" 0 50 0'
        s=0
        for EACH in $SERVERLIST
        do
            ((s++))
            IP=$(echo $EACH | cut -f1 -d":")
            NAME=$(echo $EACH | cut -f3- -d":")
            PORT=$(echo $EACH | cut -f2 -d":")
            SRVCMD=$"$SRVCMD \"$IP\" \"${NAME//:/ }\" on"
        done
        SRVCMD=$"$SRVCMD 2>&1 >/dev/tty"
        SERVERNUMS=$(eval ${SRVCMD[@]} | tr -d \")
        if [ "$SERVERNUMS" ]
        then
            SERVERS=''
            for SERVER in $SERVERNUMS
            do
                SERVERS=$"$SERVERS $(cat $SCRIPT_DIR/servers.lst | grep -v '^#' | grep -v '^$' | expand | tr -s " " | tr " " ":" | grep $SERVER)"
            done
        else
            exit 0
        fi

        echo '
        #!/usr/bin/expect

        set ip [lindex $argv 0]
        set port [lindex $argv 1]
        set login [lindex $argv 2]
        set user [lindex $argv 3]
        set pass $env(SUDOPASS)

        if { $ip eq "" || $port eq "" || $login eq "" || $pass eq "" || $user eq ""} {
            exit 1
        }

        set timeout 5
        log_user 1

        puts "\n\033\[01;33mDeleting $user from $ip\033\[00;0m"
        spawn -noecho ssh -t -o "UserKnownHostsFile=/dev/null" -o "StrictHostKeyChecking=no" -p $port $login@$ip sudo pkill -9 -u $user ";" sudo mv /home/$user /home/$user"_deleted" ";" sudo userdel -f $user
        expect {
            "sudo" {
                send "$pass\r"
                puts "sudo password entered"
            }
            "denied" {
                puts "\033\[01;31m$ip: Permission denied\033\[00;0m"
                exit 1
            }
            timeout {
                puts "\033\[01;31m$ip: Connection timeout\033\[00;0m"
                exit 1
            }
        }
        expect eof' > $SCRIPT_DIR/del_ssh.exp

        for SERVER in $SERVERS
        do
            IP=$(echo $SERVER | cut -f1 -d":")
            SERVERNAME=$(echo $SERVER | cut -f3 -d":")
            PORT=$(echo $SERVER | cut -f2 -d":")
            SUDOPASS=$SUDOPASS expect $SCRIPT_DIR/del_ssh.exp $IP $PORT $LOGIN $USER
        done
        rm $SCRIPT_DIR/del_ssh.exp


    elif [ "$ACTION" == "Add new user to <keys> folder" ]
    then
        USERNAME=$(whiptail --clear --backtitle "$BACKTITLE" --inputbox "Enter new username:" 8 40 2>&1 >/dev/tty)
        if [ -z "$USERNAME" ]
        then
            exit 0
        fi

        PUBKEY=$(whiptail --clear --backtitle "$BACKTITLE" --inputbox "Paste pubkey (everything after 'ssh-rsa'):" 8 80 2>&1 >/dev/tty)
        if [ -z "$PUBKEY" ]
        then
            exit 0
        fi

        mkdir -p $SCRIPT_DIR/keys/"$USERNAME"/.ssh
        echo "ssh-rsa "$PUBKEY > $SCRIPT_DIR/keys/$USERNAME/.ssh/authorized_keys
        echo -e "\n$(tput setaf 3)$(tput bold)Added $USERNAME to <keys> folder.$(tput sgr 0)\n"


    elif [ "$ACTION" == "Add new server to servers list" ]
    then
        IP=$(whiptail --clear --backtitle "$BACKTITLE" --inputbox "Enter IP address:" 8 40 2>&1 >/dev/tty)
        if [ -z "$IP" ]
        then
            exit 0
        fi

        PORT=$(whiptail --clear --backtitle "$BACKTITLE" --inputbox "Enter SSH port:" 8 40 2>&1 >/dev/tty)
        if [ -z "$PORT" ]
        then
            exit 0
        fi

        SERVERNAME=$(whiptail --clear --backtitle "$BACKTITLE" --inputbox "Enter Hostname:" 8 40 2>&1 >/dev/tty)
        if [ -z "$SERVERNAME" ]
        then
            exit 0
        fi

        TAB1=''
        for i in $(seq 1 $(expr 16 - ${#IP}))
        do 
            TAB1=$"$TAB1 "
        done

        TAB2=''
        for i in $(seq 1 $(expr 8 - ${#PORT}))
        do 
            TAB2=$"$TAB2 "
        done

        echo -e $IP"$TAB1"$PORT"$TAB2"${SERVERNAME// /_} >> $SCRIPT_DIR/servers.lst
        echo -e "\n$(tput setaf 3)$(tput bold)Added $SERVERNAME ($IP) to servers list.$(tput sgr 0)\n"
    else
        exit 0
    fi
fi
