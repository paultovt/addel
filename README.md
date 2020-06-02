# Bash script to add/delete users to/from linux servers.

Sometimes there is a need to add or remove users to/from a bunch of servers quickly when hire or fire staff. Or need to add admins to brand new server. This script allows you to do that in few steps.

I've done this script to satisfy my personal needs. So you can modify it if you want more functionality. Or you can share your idea.

#### If you don't like this script, then make your own, goddammit!

## Features

- tested on centos, debian and ubuntu servers.
- only works with your default private key (on user/.ssh folder) that you usually use for servers administration if pubkey authentication used.
- left full execution output specially to see what's happening.
- if add users, you can make them sudoers (or not).
- if delete user, it does: kill all processes owned by user; rename users folder to user_deleted; `userdel`.

## Requirements

#### Debian/Ubuntu:

    sudo apt install expect

#### Centos:

    sudo yum install expect

## Using

### add users:
- ask user to generate authentication keys with `ssh-keygen` and send pubkey to you. 
- `./addel.sh`.
- *"Add new user to \<keys\> folder"*.
- *"Add users to servers"*.

#### If all you have is a public key from a user in PuTTY-style format, you can convert it to standard openssh format like so:
`ssh-keygen -i -f keyfile.pub > newkeyfile.pub`


### delete user:
- `./addel.sh`.
- follow steps.


## Demos

![demo_add](https://raw.githubusercontent.com/paultovt/addel/master/demo_add.gif)

![demo_del](https://raw.githubusercontent.com/paultovt/addel/master/demo_del.gif)
