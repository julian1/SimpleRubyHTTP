
iptables -t nat -F 
iptables -t nat -X


# this won't work if it's not an external connection
iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 80  -j REDIRECT --to-port 8000
iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 443 -j REDIRECT --to-port 8443

iptables -t nat -L

