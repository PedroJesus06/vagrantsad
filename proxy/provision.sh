#!/usr/bin/env bash

# El script se detiene si hay errores
set -e
export DEBIAN_FRONTEND=noninteractive
echo "########################################"
echo " Aprovisionando proxy "
echo "########################################"
echo "-----------------"
echo "Actualizando repositorios"
apt-get update -y 
apt-get install -y net-tools iputils-ping curl tcpdump nmap
apt-get autoremove -y
echo "------ FIN ------"