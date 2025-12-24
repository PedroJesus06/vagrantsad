#!/bin/sh

# El script se detiene si hay errores
set -e
echo "########################################"
echo " Aprovisionando adminpc "
echo "########################################"
echo "-----------------"
echo "Actualizando repositorios"
apk update
apk add curl nmap tcpdump wget bash iputils
echo "------ FIN ------"