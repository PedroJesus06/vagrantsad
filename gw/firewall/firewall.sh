#!/bin/bash
set -ex

# Activar IP forwarding
sysctl -w net.ipv4.ip_forward=1

# Limpiar reglas previas
iptables -F
iptables -t nat -F
iptables -Z
iptables -t nat -Z

# ANTI-LOCK: Acceso SSH vía eth0 (Vagrant/Gestión externa)
iptables -A INPUT -i eth0 -p tcp --dport 22 -j ACCEPT
iptables -A OUTPUT -o eth0 -p tcp --sport 22 -j ACCEPT

# POLÍTICAS POR DEFECTO
iptables -P INPUT DROP
iptables -P OUTPUT DROP
iptables -P FORWARD DROP

###########################
# Reglas de protección local (FIREWALL)
###########################

# L1. Loopback
iptables -A OUTPUT -o lo -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT

# L2. Ping saliente del firewall
iptables -A OUTPUT -p icmp --icmp-type echo-request -j ACCEPT
iptables -A INPUT -p icmp --icmp-type echo-reply -j ACCEPT

# L3. Recibir ping desde LAN (eth3) y DMZ (eth2)
iptables -A INPUT -i eth2 -s 172.1.1.0/24 -p icmp --icmp-type echo-request -j ACCEPT
iptables -A INPUT -i eth3 -s 172.2.1.0/24 -p icmp --icmp-type echo-request -j ACCEPT
iptables -A OUTPUT -o eth2 -d 172.1.1.0/24 -p icmp --icmp-type echo-reply -j ACCEPT
iptables -A OUTPUT -o eth3 -d 172.2.1.0/24 -p icmp --icmp-type echo-reply -j ACCEPT

# L4. DNS para el propio firewall
iptables -A OUTPUT -o eth0 -p udp --dport 53 -m conntrack --ctstate NEW -j ACCEPT
iptables -A INPUT -i eth0 -p udp --sport 53 -m conntrack --ctstate ESTABLISHED -j ACCEPT

# L5. HTTP/HTTPS para el propio firewall (actualizaciones)
iptables -A OUTPUT -o eth0 -p tcp -m multiport --dports 80,443 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
iptables -A INPUT -i eth0 -p tcp -m multiport --sports 80,443 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# L6. SSH al firewall solo desde Admin PC
iptables -A INPUT -i eth3 -s 172.2.1.10 -p tcp --dport 22 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -o eth3 -d 172.2.1.10 -p tcp --sport 22 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT


############################
# Reglas de protección de red (FORWARDING)
############################

# R1. NAT de salida para LAN y DMZ
iptables -t nat -A POSTROUTING -s 172.2.1.0/24 -o eth0 -j MASQUERADE
iptables -t nat -A POSTROUTING -s 172.1.1.0/24 -o eth0 -j MASQUERADE

# R2. Port Forwarding (DNAT) de WAN a Servidor Web DMZ
# Corregido: Si viene de WAN usualmente es eth0 o eth1 (usaré eth0 según lógica estándar de salida)
iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 80 -j DNAT --to-destination 172.1.1.3:80
iptables -A FORWARD -i eth0 -o eth2 -d 172.1.1.3 -p tcp --dport 80 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i eth2 -o eth0 -s 172.1.1.3 -p tcp --sport 80 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# R3.A. LAN puede ver la Web de la DMZ
iptables -A FORWARD -i eth3 -o eth2 -s 172.2.1.0/24 -d 172.1.1.3 -p tcp --dport 80 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i eth2 -o eth3 -s 172.1.1.3 -d 172.2.1.0/24 -p tcp --sport 80 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# R3.B. Admin PC SSH a toda la DMZ
iptables -A FORWARD -i eth3 -o eth2 -s 172.2.1.10 -d 172.1.1.0/24 -p tcp --dport 22 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i eth2 -o eth3 -s 172.1.1.0/24 -d 172.2.1.10 -p tcp --sport 22 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# R4. Tráfico de salida de la LAN
# R4.1. LAN hacia Proxy SQUID en DMZ
iptables -A FORWARD -i eth3 -o eth2 -s 172.2.1.0/24 -d 172.1.1.2 -p tcp --dport 3128 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i eth2 -o eth3 -s 172.1.1.2 -d 172.2.1.0/24 -p tcp --sport 3128 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# R4.2. DNS Directo desde LAN
iptables -A FORWARD -i eth3 -o eth0 -s 172.2.1.0/24 -p udp --dport 53 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i eth0 -o eth3 -d 172.2.1.0/24 -p udp --sport 53 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# R4.3. NTP y ICMP desde LAN
iptables -A FORWARD -i eth3 -o eth0 -s 172.2.1.0/24 -p udp --dport 123 -j ACCEPT
iptables -A FORWARD -i eth0 -o eth3 -d 172.2.1.0/24 -p udp --sport 123 -j ACCEPT
iptables -A FORWARD -i eth3 -o eth0 -s 172.2.1.0/24 -p icmp --icmp-type echo-request -j ACCEPT
iptables -A FORWARD -i eth0 -o eth3 -d 172.2.1.0/24 -p icmp --icmp-type echo-reply -j ACCEPT

# R5. Tráfico de salida de la DMZ (DNS, NTP, HTTP/S para actualizaciones)
iptables -A FORWARD -i eth2 -o eth0 -s 172.1.1.0/24 -p udp -m multiport --dports 53,123 -j ACCEPT
iptables -A FORWARD -i eth0 -o eth2 -d 172.1.1.0/24 -p udp -m multiport --sports 53,123 -j ACCEPT


# P4. Acceso LDAP (DMZ -> LAN Server)
iptables -A FORWARD -i eth2 -o eth3 -s 172.1.1.0/24 -d 172.2.1.2 -p tcp --dport 389 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i eth3 -o eth2 -s 172.2.1.2 -d 172.1.1.0/24 -p tcp --sport 389 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Regla P4.2.1 Permitir acceso WAN (eth1) a servidor VPN
iptables -A INPUT -i eth1 -p udp --dport 1194 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -o eth1 -p udp --sport 1194 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Permitir que el openvpn en el GW consulte al servidor LDAP
iptables -A OUTPUT -o eth3 -d 172.2.1.2 -p tcp --dport 389 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
iptables -A INPUT -i eth3 -s 172.2.1.2 -p tcp --sport 389 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Regla P4.2.2 Permitir acceso de VPN-net a http de la DMZ
iptables -A FORWARD -i tun0 -o eth2 -s 172.3.1.0/24 -d 172.1.1.3 -p tcp -m multiport --dports 80,443 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i eth2 -o tun0 -s 172.1.1.3 -d 172.3.1.0/24 -p tcp -m multiport --sports 80,443 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Regla P4.2.3 Permitir acceso de VPN-net a IDP de la DMZ
iptables -A FORWARD -i tun0 -o eth3 -s 172.3.1.0/24 -d 172.2.1.2 -p tcp --dport 389 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i eth3 -o tun0 -s 172.2.1.2 -d 172.3.1.0/24 -p tcp --sport 389 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Permitir que el ping entre desde el túnel hacia dentro
iptables -A FORWARD -i tun0 -p icmp -j ACCEPT
# Permitir que la respuesta del ping vuelva al túnel
iptables -A FORWARD -o tun0 -p icmp -j ACCEPT

# P6. Permitimos salir a squid a 80 y 443
iptables -A FORWARD -i eth2 -o eth0 -s 172.1.1.2 -p tcp -m multiport --dports 80,443 -j ACCEPT
iptables -A FORWARD -i eth0 -o eth2 -d 172.1.1.2 -p tcp -m multiport --sports 80,443 -j ACCEPT


echo "Configuración de iptables aplicada correctamente."

###### Logs para depurar
iptables -A INPUT -j LOG --log-prefix "PJAO-INPUT: "
iptables -A OUTPUT -j LOG --log-prefix "PJAO-OUTPUT: "
iptables -A FORWARD -j LOG --log-prefix "PJAO-FORWARD: "