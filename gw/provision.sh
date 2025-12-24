#!/usr/bin/env bash

# El script se detiene si hay errores
set -e
export DEBIAN_FRONTEND=noninteractive
echo "########################################"
echo " Aprovisionando Gateway "
echo "########################################"
echo "-----------------"
echo "Actualizando repositorios"
apt-get update -y && apt-get autoremove -y
apt-get install -y net-tools iputils-ping curl tcpdump nmap

echo "------------------------------------------------"
echo "Configurando el Gateway (Hito 1: Conectividad)"
echo "------------------------------------------------"

# 1. Habilitar el reenvío de paquetes (IP Forwarding)
# Sin esto, el kernel de Linux descarta los paquetes que no van dirigidos a él.
sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf

# 2. Configurar NAT (Enmascaramiento)
# Queremos que todo lo que venga de la LAN y la DMZ salga a internet con la IP de la red NAT (eth0)
# Suponiendo que eth0 es la interfaz NAT de Vagrant.
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

# 3. Reglas básicas de Forwarding (Aceptarlo todo por ahora)
# En el Hito 2 (Seguridad) cambiaremos esto a DROP y filtraremos.
iptables -P FORWARD ACCEPT

echo "Gateway configurado y enrutando tráfico."