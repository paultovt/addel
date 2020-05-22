# Bash script to add/delete users to/from linux servers.

Sometimes there is a need to add or remove users to/from a bunch of servers quickly when hire or fire staff. Or need to add admins to brand new server. This script allows you to do that in few steps.

I've done script to satisfy my personal needs. So you can modify it if you want more functionality. Or you can share your idea.

#### If you don't like this script, then make your own, goddammit!

## Features

- tested on centos, debian, ubuntu.
- only works with your default private key (on user/.ssh folder) that you usually use for servers administration if pubkey authentication used.
- left full execution output specially to see what's happening.
- if add user, you can make them sudoers (or not).
- if delete user, it does: kill all processes owned by user; rename users folder to user_deleted; `userdel`.

## Requirements

#### Debian/Ubuntu:

    sudo apt install expect

#### Centos:

    sudo yum install expect

## Using

### add users:
- ask user to generate authentication keys with `ssh-keygen` and send pubkey to you.
- store it in ./keys/user/.ssh/authorized_keys file.
- then: `./addel.sh`.
- follow steps.

### delete user:
- `./addel.sh`.
- follow steps.


## Demos

![demo_add](https://raw.githubusercontent.com/paultovt/addel/master/demo_add.gif)

![demo_del](https://raw.githubusercontent.com/paultovt/addel/master/demo_del.gif)
