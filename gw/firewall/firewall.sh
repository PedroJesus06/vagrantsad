#/bin/bash
set -x
#Activar ip forwarding
sysctl -w net.ipv4.ip_forward=1

#Limpiar reglas previas
iptables -F
iptables -t nat -F
iptables -Z
iptables -t nat -Z

# ANTI-LOCK rule: Permitir ssh a traves de ETH0 para acceder con vagrant
iptables -A INPUT -i eth0 -p tcp --dport 22 -j ACCEPT
iptables -A OUTPUT -o eth0 -p tcp --sport 22 -j ACCEPT

# Politica por defecto
iptables -P INPUT DROP
iptables -P OUTPUT DROP
iptables -P FORWARD DROP

##############################################
#Reglas de proteccion local
##############################################
#1. Permitir trafico de loopback

##############################################
#Reglas de proteccion de red
##############################################

###### Logs para depurar
iptables -A INPUT -j LOG --log-prefix "PJAO-INPUT: "
iptables -A OUTPUT -j LOG --log-prefix "PJAO-OUTPUT: "
iptables -A FORWARD -j LOG --log-prefix "PJAO-FORWARD: "