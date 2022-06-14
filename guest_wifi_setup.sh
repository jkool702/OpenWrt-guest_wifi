# set guest network SSID + router IP + netmask
GuestWiFi_SSID='Guest_WiFi'
GuestWiFi_IP='10.0.1.1'
GuestWiFi_netmask='255.255.255.0'

# explicity set whether or not to use OWE 
# '1' --> use OWE  /  '0' --> dont use OWE 
# <blank>/<anything else> --> auto-determine based on wpad/hostapd version
use_OWE_flag=''

# determine whether or not to use OWE 
# if not explicitly defined, then it will be enabled if the full version of wpad or hostapd is present, and otherwise disabled
mkdir -p /var/lock
if [ -z ${use_OWE_flag} ] || ! { [ "${use_OWE_flag}" == '0' ] || [ "${use_OWE_flag}" == '1']; }; then
	opkg list-installed | grep -E '((wpad)|(hostapd))' | grep -q -E '((mini)|(basic)|(mesh))' && use_OWE_flag='0' || use_OWE_flag='1'
fi

if [ "${use_OWE_flag}" == '0' ] || ! [ -f /root/guest-wifi-OWE-setup-2nd-reboot-flag ] ; then
	
	# setup network config
	
	uci -q delete network.guest_dev
	uci batch << EOI
set network.guest_dev=device
set network.guest_dev.type='bridge'
set network.guest_dev.name='br-guest'
set network.guest_dev.bridge_empty='1'
EOI

	uci -q delete network.guest
	uci batch << EOI
set network.guest=interface
set network.guest.proto='static'
set network.guest.device='br-guest'
set network.guest.force_link='0'
set network.guest.ip6assign='60'
set network.guest.ipaddr="${GuestWiFi_IP}"
set network.guest.netmask="${GuestWiFi_netmask}"
set network.guest.type='bridge'
add_list network.guest.dns="${GuestWiFi_IP}"

EOI

	uci commit network

	# setup wireless config

	uci -q delete wireless.guest_radio0
	uci batch << EOI
set wireless.guest_radio0=wifi-iface
set wireless.guest_radio0.device="$(uci get wireless.@wifi-iface[0].device)"
set wireless.guest_radio0.mode='ap'
set wireless.guest_radio0.network='guest'
set wireless.guest_radio0.ssid="${GuestWiFi_SSID}"
set wireless.guest_radio0.isolate='1'
set wireless.guest_radio0.encryption='open'
set wireless.guest_radio0.na_mcast_to_ucast='1'
set wireless.guest_radio0.disabled='1'
EOI

	uci -q delete wireless.guest_radio1
	uci batch << EOI
set wireless.guest_radio1=wifi-iface
set wireless.guest_radio1.device="$(uci get wireless.@wifi-iface[1].device)"
set wireless.guest_radio1.mode='ap'
set wireless.guest_radio1.network='guest'
set wireless.guest_radio1.ssid="${GuestWiFi_SSID}"
set wireless.guest_radio1.isolate='1'
set wireless.guest_radio1.encryption='open'
set wireless.guest_radio1.na_mcast_to_ucast='1'
set wireless.guest_radio1.disabled='1'
EOI

	if [ "${use_OWE_flag}" == '1' ]; then

		# setup (most of) the OWE wireless config

		uci batch << EOI
set wireless.guest_radio0.owe_transition_ssid="${GuestWiFi_SSID}_OWE_5g"
set wireless.guest_radio1.owe_transition_ssid="${GuestWiFi_SSID}_OWE_2g"
EOI

		uci -q delete wireless.guest_radio0_owe
		uci batch << EOI
set wireless.guest_radio0_owe=wifi-iface
set wireless.guest_radio0_owe.device="$(uci get wireless.@wifi-iface[0].device)"
set wireless.guest_radio0_owe.mode='ap'
set wireless.guest_radio0_owe.network='guest'
set wireless.guest_radio0_owe.ssid="${GuestWiFi_SSID}_OWE_5g"
set wireless.guest_radio0_owe.isolate='1'
set wireless.guest_radio0_owe.encryption='owe'
set wireless.guest_radio0_owe.hidden='1'
set wireless.guest_radio0_owe.owe_transition_ssid="${GuestWiFi_SSID}"
set wireless.guest_radio0_owe.ieee80211w='2'
set wireless.guest_radio0_owe.na_mcast_to_ucast='1'
set wireless.guest_radio0_owe.disabled='1'
EOI

		uci -q delete wireless.guest_radio1_owe
		uci batch << EOI
set wireless.guest_radio1_owe=wifi-iface
set wireless.guest_radio1_owe.device="$(uci get wireless.@wifi-iface[1].device)"
set wireless.guest_radio1_owe.mode='ap'
set wireless.guest_radio1_owe.network='guest'
set wireless.guest_radio1_owe.ssid="${GuestWiFi_SSID}_OWE_2g"
set wireless.guest_radio1_owe.isolate='1'
set wireless.guest_radio1_owe.encryption='owe'
set wireless.guest_radio1_owe.hidden='1'
set wireless.guest_radio1_owe.owe_transition_ssid="${GuestWiFi_SSID}"
set wireless.guest_radio1_owe.ieee80211w='2'
set wireless.guest_radio1_owe.na_mcast_to_ucast='1'
set wireless.guest_radio1_owe.disabled='1'
EOI

	fi

	uci commit wireless

	# setup dhcp config

	uci -q delete dhcp.guest
	uci batch << EOI
set dhcp.guest=dhcp
set dhcp.guest.interface='guest'
set dhcp.guest.start='100'
set dhcp.guest.limit='150'
set dhcp.guest.leasetime='1h'
set dhcp.guest.dhcpv4='server'
set dhcp.guest.dhcpv4_forcereconf='1'
set dhcp.guest.dhcpv6='server'
set dhcp.guest.dhcpv6_na='1'
set dhcp.guest.dhcpv6_pd='1'
set dhcp.guest.ra='server'
set dhcp.guest.ra_management='1'
set dhcp.guest.ra_dns='1'
set dhcp.guest.force='1'
set dhcp.guest.netmask="${GuestWiFi_netmask}"
add_list dhcp.guest.router="${GuestWiFi_IP}"
add_list dhcp.guest.dhcp_option="3,${GuestWiFi_IP}"
add_list dhcp.guest.dhcp_option="6,${GuestWiFi_IP}"
EOI

	uci commit dhcp

	# setup firewall config

	uci -q delete firewall.guest
	uci batch << EOI
set firewall.guest=zone
set firewall.guest.name='guest'
set firewall.guest.network='guest'
set firewall.guest.input='REJECT'
set firewall.guest.output='ACCEPT'
set firewall.guest.forward='REJECT'
EOI

	uci -q delete firewall.guest_wan
	uci batch << EOI
set firewall.guest_wan=forwarding
set firewall.guest_wan.src='guest'
set firewall.guest_wan.dest='wan'
EOI

	uci -q delete firewall.guest_dhcp
	uci batch << EOI
set firewall.guest_dhcp=rule
set firewall.guest_dhcp.name='Allow-DHCP-guest'
set firewall.guest_dhcp.src='guest'
set firewall.guest_dhcp.family='ipv4'
set firewall.guest_dhcp.target='ACCEPT'
set firewall.guest_dhcp.src_port='67-68'
set firewall.guest_dhcp.dest_port='67-68'
set firewall.guest_dhcp.proto='udp'
EOI

	uci -q delete firewall.guest_dhcpv6
	uci batch << EOI
set firewall.guest_dhcpv6=rule
set firewall.guest_dhcpv6.name='Allow-DHCPv6-guest'
set firewall.guest_dhcpv6.src='guest'
set firewall.guest_dhcpv6.dest_port='547'
set firewall.guest_dhcpv6.proto='udp'
set firewall.guest_dhcpv6.family='ipv6'
set firewall.guest_dhcpv6.target='ACCEPT'
EOI

	uci -q delete firewall.guest_dns
	uci batch << EOI
set firewall.guest_dns=rule
set firewall.guest_dns.name='Allow-DNS-guest'
set firewall.guest_dns.src='guest'
set firewall.guest_dns.dest_port='53'
set firewall.guest_dns.proto='tcp udp'
set firewall.guest_dns.target='ACCEPT'
EOI

	uci commit firewall

	# setup init script to bring guest wifi up/down

	if [ "${use_OWE_flag}" == '0' ]; then

		# version without OWE

		cat<<'EOF' | tee /etc/init.d/guest_wifi
#!/bin/sh /etc/rc.common

NAME='guest_wifi'
START=99
STOP=99
EXTRA_COMMANDS='up down'

start() {
	if [ "$(echo $(uci show wireless | grep 'guest_radio' | grep 'disabled' | awk -F '=' '{print $2}' | sed -E s/"'"//g) | sed -E s/' '//g)" == '00' ]; 
	then
		echo "NOTICE: Guest Wifi already enabled in UCI config." >&2
		
		if [ "$(iw dev | grep ssid | grep "$(uci get wireless.guest_radio0.ssid)" | wc -l)" == '2' ] && [ "$(ifconfig | grep -E "$(echo $(iw dev | grep -E '(Interface)|(ssid)' | sed -zE s/'\n[ \t]+ssid'/' -- '/g | sed -E s/'^[ \t]*Interface '// | { grep "$(uci get wireless.guest_radio0.ssid)" || echo 'NONE -- NO MATCHES'; } | awk '{print $1}' | sed -E s/'(.*)'/'(\1)'/ ) | sed -E s/' '/'|'/g)" | wc -l)" == '2' ]; 
		then
			echo -e "Guest network appears to be up and running. \nIf it is not working, try running 'service guest_wifi restart' to cycle wifi off and on. \nIf this does not work, try rebooting the router. \n" >&2
		else
			
			echo "Despite being enabled, guest network appears to be inactive. Router will reboot in 10 seconds" >&2
			sleep 10
			reboot
		fi
	else
		uci set wireless.guest_radio0.disabled='0'
		uci set wireless.guest_radio1.disabled='0'
		uci commit wireless
		reload_config
		
		echo "Guest network enabled. Router will reboot in 10 seconds" >&2
		sleep 10
		reboot
	fi
} 

stop() {
	if [ "$(echo $(uci show wireless | grep 'guest_radio' | grep 'disabled' | awk -F '=' '{print $2}' | sed -E s/"'"//g) | sed -E s/' '//g)" == '11' ]; 
	then
		echo "NOTICE: Guest Wifi already disabled in UCI config." >&2
		
		if [ "$(iw dev | grep ssid | grep "$(uci get wireless.guest_radio0.ssid)" | wc -l)" == '0' ] && [ "$(ifconfig | grep -E "$(echo $(iw dev | grep -E '(Interface)|(ssid)' | sed -zE s/'\n[ \t]+ssid'/' -- '/g | sed -E s/'^[ \t]*Interface '// | { grep "$(uci get wireless.guest_radio0.ssid)" || echo 'NONE -- NO MATCHES'; } | awk '{print $1}' | sed -E s/'(.*)'/'(\1)'/ ) | sed -E s/' '/'|'/g)" | wc -l)" == '0' ]; 
		then
			echo -e "Guest network appears to be fully shut down \nIf it is still running or something else isnt working with the wifi, try rebooting the router. \n" >&2
		else
			
			echo "Despite being disabled, guest network appears to be active. Router will reboot in 10 seconds" >&2
			sleep 10
			reboot
		fi
	else
		uci set wireless.guest_radio0.disabled='1'
		uci set wireless.guest_radio1.disabled='1'
		uci commit wireless
		reload_config
		
		echo "Guest network disabled. Router will reboot in 10 seconds" >&2
		sleep 10
		reboot
	fi
}

restart() {
	if [ "$(echo $(uci show wireless | grep 'guest_radio' | grep 'disabled' | awk -F '=' '{print $2}' | sed -E s/"'"//g) | sed -E s/' '//g)" == '00' ] && [ "$(iw dev | grep ssid | grep "$(uci get wireless.guest_radio0.ssid)" | wc -l)" == '2' ] && [ "$(ifconfig | grep -E "$(echo $(iw dev | grep -E '(Interface)|(ssid)' | sed -zE s/'\n[ \t]+ssid'/' -- '/g | sed -E s/'^[ \t]*Interface '// | { grep "$(uci get wireless.guest_radio0.ssid)" || echo 'NONE -- NO MATCHES'; } | awk '{print $1}' | sed -E s/'(.*)'/'(\1)'/ ) | sed -E s/' '/'|'/g)" | wc -l)" == '2' ]; 
	then
		wifi down
		sleep 5
		wifi up
	else
		start
	fi
}

up() {
	start
}

down() {
	stop
}
EOF

	else	

		# version with OWE

		cat<<'EOF' | tee /etc/init.d/guest_wifi
#!/bin/sh /etc/rc.common

NAME='guest_wifi'
START=99
STOP=99
EXTRA_COMMANDS='up down'

start() {
	if [ "$(echo $(uci show wireless | grep 'guest_radio' | grep 'disabled' | awk -F '=' '{print $2}' | sed -E s/"'"//g) | sed -E s/' '//g)" == '0000' ]; 
	then
		echo "NOTICE: Guest Wifi already enabled in UCI config." >&2
		
		if [ "$(iw dev | grep ssid | grep "$(uci get wireless.guest_radio0.ssid)" | wc -l)" == '4' ] && [ "$(ifconfig | grep -E "$(echo $(iw dev | grep -E '(Interface)|(ssid)' | sed -zE s/'\n[ \t]+ssid'/' -- '/g | sed -E s/'^[ \t]*Interface '// | { grep "$(uci get wireless.guest_radio0.ssid)" || echo 'NONE -- NO MATCHES'; } | awk '{print $1}' | sed -E s/'(.*)'/'(\1)'/ ) | sed -E s/' '/'|'/g)" | wc -l)" == '4' ]; 
		then
			echo -e "Guest network appears to be up and running. \nIf it is not working, try running 'service guest_wifi restart' to cycle wifi off and on. \nIf this does not work, try rebooting the router. \n" >&2
		else
			
			echo "Despite being enabled, guest network appears to be inactive. Router will reboot in 10 seconds" >&2
			sleep 10
			reboot
		fi
	else
		uci set wireless.guest_radio0.disabled='0'
		uci set wireless.guest_radio0_owe.disabled='0'
		uci set wireless.guest_radio1.disabled='0'
		uci set wireless.guest_radio1_owe.disabled='0'
		uci commit wireless
		reload_config
		
		echo "Guest network enabled. Router will reboot in 10 seconds" >&2
		sleep 10
		reboot
	fi
} 

stop() {
	if [ "$(echo $(uci show wireless | grep 'guest_radio' | grep 'disabled' | awk -F '=' '{print $2}' | sed -E s/"'"//g) | sed -E s/' '//g)" == '1111' ]; 
	then
		echo "NOTICE: Guest Wifi already disabled in UCI config." >&2
		
		if [ "$(iw dev | grep ssid | grep "$(uci get wireless.guest_radio0.ssid)" | wc -l)" == '0' ] && [ "$(ifconfig | grep -E "$(echo $(iw dev | grep -E '(Interface)|(ssid)' | sed -zE s/'\n[ \t]+ssid'/' -- '/g | sed -E s/'^[ \t]*Interface '// | { grep "$(uci get wireless.guest_radio0.ssid)" || echo 'NONE -- NO MATCHES'; } | awk '{print $1}' | sed -E s/'(.*)'/'(\1)'/ ) | sed -E s/' '/'|'/g)" | wc -l)" == '0' ]; 
		then
			echo -e "Guest network appears to be fully shut down \nIf it is still running or something else isnt working with the wifi, try rebooting the router. \n" >&2
		else
			
			echo "Despite being disabled, guest network appears to be active. Router will reboot in 10 seconds" >&2
			sleep 10
			reboot
		fi
	else
		uci set wireless.guest_radio0.disabled='1'
		uci set wireless.guest_radio0_owe.disabled='1'
		uci set wireless.guest_radio1.disabled='1'
		uci set wireless.guest_radio1_owe.disabled='1'
		uci commit wireless
		reload_config
		
		echo "Guest network disabled. Router will reboot in 10 seconds" >&2
		sleep 10
		reboot
	fi
}

restart() {
	if [ "$(echo $(uci show wireless | grep 'guest_radio' | grep 'disabled' | awk -F '=' '{print $2}' | sed -E s/"'"//g) | sed -E s/' '//g)" == '0000' ] && [ "$(iw dev | grep ssid | grep "$(uci get wireless.guest_radio0.ssid)" | wc -l)" == '4' ] && [ "$(ifconfig | grep -E "$(echo $(iw dev | grep -E '(Interface)|(ssid)' | sed -zE s/'\n[ \t]+ssid'/' -- '/g | sed -E s/'^[ \t]*Interface '// | { grep "$(uci get wireless.guest_radio0.ssid)" || echo 'NONE -- NO MATCHES'; } | awk '{print $1}' | sed -E s/'(.*)'/'(\1)'/ ) | sed -E s/' '/'|'/g)" | wc -l)" == '4' ]; 
	then
		wifi down
		sleep 5
		wifi up
	else
		start
	fi
}

up() {
	start
}

down() {
	stop
}
EOF

	fi

	chmod +x /etc/init.d/guest_wifi

	if [ "${use_OWE_flag}" == '1' ]; then
		# setup to continue this script after reboot via /etc/rc.local
		touch /root/guest-wifi-OWE-setup-2nd-reboot-flag
		
		[ -f /etc/rc.local ] || { echo 'exit 0' > /etc/rc.local; chmod +x /etc/rc.local; }
		rc_local="$(cat /etc/rc.local | grep -v 'exit 0'; echo 'sleep 20'; echo "chmod +x \"$(readlink -f $0)\""; echo "$(readlink -f $0)"; echo 'exit 0')"
		mv /etc/rc.local /etc/rc.local.orig
		echo "${rc_local}" > /etc/rc.local
		chmod +x /etc/rc.local
	fi
	
	sleep 5
	
	/etc/init.d/guest_wifi up
	
else
	
	# script to run after 1st reboot for OWE setup (requires a 2nd reboot)
	# It is done like this to ensure that the hard-coded BSSIDs in wireless config 
	# match the BSSIDs that would have been automatically used by the interfaces
	#
	# This *should* get run automatically after the 1st reboot, via a temporary alteration to /etc/rc.local
	
	echo "Running 2nd part setup script -- required to set OWE BSSID's" >&2

	kk=0
	iwinfo | sed -zE s/'\n[ \t]*Access Point\: '/' \-\- '/g | grep ESSID | grep "${GuestWiFi_SSID}" | awk -F '--' '{print $2}' | while read -r nn; 
	do
		if [ "${kk}" == '0' ]; then
				uci set wireless.guest_radio0.bssid="${nn}"
				uci set wireless.guest_radio0_owe.owe_transition_bssid="${nn}"

		elif [ "${kk}" == '1' ]; then
				uci set wireless.guest_radio0_owe.bssid="${nn}"
				uci set wireless.guest_radio0.owe_transition_bssid="${nn}"

		elif [ "${kk}" == '2' ]; then
				uci set wireless.guest_radio1.bssid="${nn}"
				uci set wireless.guest_radio1_owe.owe_transition_bssid="${nn}"

		elif [ "${kk}" == '3' ]; then
				uci set wireless.guest_radio1_owe.bssid="${nn}"
				uci set wireless.guest_radio1.owe_transition_bssid="${nn}"
		fi

		kk=$((( $kk + 1 )))
		
	done
	
	uci commit wireless
	
	mv /etc/rc.local.orig /etc/rc.local
	rm -f /root/guest-wifi-OWE-setup-2nd-reboot-flag
	
fi

# reboot to apply changes

sleep 5
reboot

