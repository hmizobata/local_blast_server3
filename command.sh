#!/bin/bash

cd /local_blast_server/Local_blast_server2
bash makeconfig.sh $1 > config/default.json
nohup npm start &

cd /sequenceserver
nohup bundle exec sequenceserver &

