# OpenWrt-guest_wifi
Automatic setup script for a guest wireless network for routers running OpenWrt firmware. 
NOTE: this is intended for ath10k 80211-based devices with dual band wifi (2g and 5g). It could likely be adapted for other 80211-based devices without too much modification, but is unlikely to work with these devices "as-is".

The script supports both "standard" guest networks and guest networks that use Open Wireless Encryption (OWE) with a transition SSID. The OWE guest network is setup such that all clients can connect regardless of whether or not they support OWE. Clients that support OWE will utalize it, and clients that dont will automatically fall back to using legacy mode (open network, no encryption).

# Usage
This script is almost fully automated, and using it is quite simple. To use this script, do the following:

1. Download the script and save it somewhere on the router.
      NOTE: If you are using OWE, the script *must* be saved on persistent storage. The OWE install requires a reboot mid-installation, and the script file needs to be available at the same location after this reboot happens.
2. Fill in the `GuestWifi_{SSID,IP,netmask}` variables at the top of the script. 
3. To force OWE support to be enabled/disabled, set `use_OWE_flag` to `1` or `0`. 
      NOTE: if this variable is blank / undefined / anything other than 0 or 1; the default behavior is to use OWE if the "full" version of wpad or hostapd is installed, and not to use OWE if the mesh / mini / basic version is installed.
4. `chmod +x` the script and run it. 
5. Wait for the script to finish running. Your router will restart when it is done. 
6. (for OWE setup only) After booting back up, the script will resume running. When it has finished, the router will restart a 2nd time.
      NOTE: you dont need to do anything to resume the script - it will automatically resume itself. Just wait for the router to restart a 2nd time. 

Your guest wifi network is now setup on your router and should be active and broadcasting!!! 

The script will install a new service (init script) called `guest_wifi` which you can use to control new guest wifi network. The guest wifi network can be started / stopped by running:

```
service guest_wifi up     # start guest wifi
service guest_wifi down   #  stop guest_wifi
```

The command `service guest_wifi restart` is also supported. This will first check if the guest wifi network is running. If it is, it runs `wifi down; sleep 5; wifi up`.If it isn't, it runs the `up` command.

NOTE: the up/down commands enable/disable the wireless interfaces in UCI (via the `disabled` option), **AND THEN IMPLEMENTS THE CHANGE BY RESTARTING THE ROUTER**. A notice will be printed to screen followed by a 10 second wait....If you do not want to immediately reboot the router, stop the running service (e.g. by pressing `ctrl` + `c`) before these 10 seconds are up. To prevent unncessary restarts, the up/down commands first check the guest wifi network state, and if it is already in the desired state then no action is performed. e.g., If the check determines the guest wifi is up and running properly, then running `service guest_wifi up` will not do anything (other than print some suggested actions that you can manually implement to the screen).

# How the script sets everything up
In setting up the guest wifi network, the following actions are performed:

NOTE: a few of these steps are only done when setting up a guest ntwork with OWE support. These are labeled with the tag `(OWE ONLY)`

1. `network` config is setup in UCI. The script creates a bridge device called `br-guest` and guest interface called `guest`
2. `wireless` config is setup in UCI.  The script sets up the guest wifi network interfaces. Two open interfaces are setup (one on the 2GHz radio, one on the 5 GHz radio). These will both use the same SSID (defined by the script variable `GuestWiFi_SSID`). Guests are isolated on all interfaces. All interfaces are (for the moment) disabled.
2a. `(OWE ONLY)` two additional interfaces (one per radio) that are hidden and use OWE encryption are setup. These enable client isolation and are also (for the moment) disabled. They have unique SSID's that are based on `${GuestWiFi_SSID}`. NOTE: BSSIDs are (intentionally) not defined in this step.
3. `dhcp` config is setup in UCI. This allows clients connected to the guest network to obtain DHCP leases.
4. `firewall` config is setup in UCI. a `guest` firewall zone (which forwards to WAN) is created, and firewall rules permitting DCHP, DHCPv6 and DNS traffic are setup
5. The `guest_wifi` service is installed to `/etc/init.d/guest_wifi`. This enables one to easily bring up/down the guest network.
6. `(OWE  ONLY)` The current `/etc/rc.local` is backup up to `/etc/rc.local.orig`, and a modified `/etc/rc.local` which automatically re-calls the script after reboot. A flag to signal script contuation is also setup via  `touch /root/guest-wifi-OWE-setup-2nd-reboot-flag`
7. The guest wifi network is brought up via the (just installed) `guest_wifi`service. This culminates in the device rebooting. After which the guest wifi should be active.

----- END OF STANDARD GUEST WIFI SETUP -----

8.  `(OWE  ONLY)` When the script is automatically re-called after rebooting (via `/etc/rc.local`), it will notice the flag at `/root/guest-wifi-OWE-setup-2nd-reboot-flag` and move to the appropiate place in the script. The script will pause for 20 seconds to allow the guest wifi time to come upo fully.
9.  `(OWE  ONLY)` The script determines the BSSIDs of the guest network (which is currently running without explicitly defining them) and uses these to set `bssid` and `owe_transition_bssid` in the `wireless` UCI config. By setting the BSSID's used in UCI to be the same as the ones that are used by default, we ensure that the BSSIDs used are valid and wont cause problems.
10.  `(OWE ONLY)` `/etc/rc.local` is restored to its original version, and the flag at `/root/guest-wifi-OWE-setup-2nd-reboot-flag` is removed.
11.  `(OWE ONLY)` the router is rebooted to implement the new guest network configuration (with defined BSSIDs).

----- END OF OWE GUEST WIFI SETUP -----
