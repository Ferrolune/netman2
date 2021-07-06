#!/bin/bash
cd "$(dirname ${BASH_SOURCE[0]})"
trap ctrl_c INT
trap ctrl_z SIGTSTP


function ctrl_c() {
		./sshlogin.sh "conf/sshlogin/ssh.conf" $$ "1"
}

#function ctrl_z() {
#        ./sshlogin.sh
#}


./sshlogin.sh "conf/sshlogin/ssh.conf" $$ "1"

#ctrl+c should kill all processes down to parent node
