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
#L1. Permitir trafico de loopback
iptables -A OUTPUT -o lo -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT

#L2. Permitir ping a cualquier maquina interna y externa
iptables -A OUTPUT -p icmp --icmp-type echo-request -j ACCEPT
iptables -A INPUT -p icmp --icmp-type echo-reply -j ACCEPT

#L3. Permitir que me hagan ping desde LAN y DMZ
iptables -A INPUT -i eth2 -s 172.1.1.0/24 -p icmp --icmp-type echo-request -j ACCEPT
iptables -A INPUT -i eth3 -s 172.2.1.0/24 -p icmp --icmp-type echo-request -j ACCEPT
iptables -A OUTPUT -o eth2 -s 172.1.1.1 -p icmp --icmp-type echo-reply -j ACCEPT
iptables -A OUTPUT -o eth3 -s 172.2.1.1 -p icmp --icmp-type echo-reply -j ACCEPT

#L4. Permitir consultas DNS
iptables -A OUTPUT -o eth0 -p udp --dport 53 -m conntrack --ctstate NEW -j ACCEPT
iptables -A INPUT -i eth0 -p udp --sport 53 -m conntrack --ctstate ESTABLISHED -j ACCEPT

#L5. Permitir http/https para actualizar y navegar
iptables -A OUTPUT -o eth0 -p tcp --dport 80 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
iptables -A INPUT -i eth0 -p tcp --sport 80 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -o eth0 -p tcp --dport 443 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
iptables -A INPUT -i eth0 -p tcp --sport 443 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

#L6. Permitir solo acceso ssh desde adminpc
iptables -A INPUT -i eth3 -s 172.2.1.10 -p tcp --dport 22 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -o eth3 -d 172.2.1.10 -p tcp --sport 22 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

##############################################
#Reglas de proteccion de red
##############################################
#R1. Se debe hacer NAT desde el trafico saliente
iptables -t nat -A POSTROUTING -s 172.2.1.0/24 -o eth0 -j MASQUERADE
#R4. Permitir salir trafico desde la LAN
iptables -A FORWARD -i eth3 -o eth0 -s 172.2.1.0/24 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i eth0 -o eth3 -d 172.2.1.0/24 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

###### Logs para depurar
iptables -A INPUT -j LOG --log-prefix "PJAO-INPUT: "
iptables -A OUTPUT -j LOG --log-prefix "PJAO-OUTPUT: "
iptables -A FORWARD -j LOG --log-prefix "PJAO-FORWARD: "