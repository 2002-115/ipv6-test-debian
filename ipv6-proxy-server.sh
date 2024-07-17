#!/bin/bash

# Script must be running from root
if [ "$EUID" -ne 0 ]; then 
  echo "Please run as root"
  exit 1
fi

# Program help info for users
function usage() {
  echo "Usage: $0 [-s | --subnet <16|32|48|64|80|96|112> proxy subnet (default 64)] 
                          [-c | --proxy-count <number> count of proxies] 
                          [-u | --username <string> proxy auth username] 
                          [-p | --password <string> proxy password]
                          [--random <bool> generate random username/password for each IPv4 backconnect proxy instead of predefined (default false)] 
                          [-t | --proxies-type <http|socks5> result proxies type (default http)]
                          [-r | --rotating-interval <0-59> proxies external address rotating time in minutes (default 0, disabled)]
                          [--start-port <5000-65536> start port for backconnect ipv4 (default 10000)]
                          [-l | --localhost <bool> allow connections only for localhost (backconnect on 127.0.0.1)]
                          [-f | --backconnect-proxies-file <string> path to file, in which backconnect proxies list will be written
                                when proxies start working (default \`~/proxyserver/backconnect_proxies.list\`)]    
                          [-d | --disable-inet6-ifaces-check <bool> disable /etc/network/interfaces configuration check & exit when error
                                use only if configuration handled by cloud-init or something like this (for example, on Vultr servers)]                                                      
                          [-m | --ipv6-mask <string> constant ipv6 address mask, to which the rotated part is added (or gateway)
                                use only if the gateway is different from the subnet address]
                          [-i | --interface <string> full name of ethernet interface, on which IPv6 subnet was allocated
                                automatically parsed by default, use ONLY if you have non-standard/additional interfaces on your server]
                          [-b | --backconnect-ip <string> server IPv4 backconnect address for proxies
                                automatically parsed by default, use ONLY if you have non-standard ip allocation on your server]
                          [--allowed-hosts <string> allowed hosts or IPs (3proxy format), for example \"google.com,*.google.com,*.gstatic.com\"
                                if at least one host is allowed, the rest are banned by default]
                          [--denied-hosts <string> banned hosts or IP addresses in quotes (3proxy format)]
                          [--uninstall <bool> disable active proxies, uninstall server and clear all metadata]
                          [--info <bool> print info about running proxy server]" 1>&2; exit 1;
}

options=$(getopt -o ldhs:c:u:p:t:r:m:f:i:b: --long help,localhost,disable-inet6-ifaces-check,random,uninstall,info,subnet:,proxy-count:,username:,password:,proxies-type:,rotating-interval:,ipv6-mask:,interface:,start-port:,backconnect-proxies-file:,backconnect-ip:,allowed-hosts:,denied-hosts: -- "$@")

# Throw error and show help message if user doesn’t provide any arguments
if [ $? != 0 ]; then 
  echo "Error: no arguments provided. Terminating..." >&2 
  usage 
fi

# Parse command line options
eval set -- "$options"

# Set default values for optional arguments
subnet=64
proxies_type="http"
start_port=10000
rotating_interval=0
use_localhost=false
use_random_auth=false
uninstall=false
print_info=false
inet6_network_interfaces_configuration_check=true
backconnect_proxies_file="default"
interface_name="$(ip -br l | awk '$1 !~ "lo|vir|wl|@NONE" { print $1 }' | awk 'NR==1')"
script_log_file="/var/tmp/ipv6-proxy-server-logs.log"
backconnect_ipv4=""

while true; do
  case "$1" in
    -h | --help ) usage; shift ;;
    -s | --subnet ) subnet="$2"; shift 2 ;;
    -c | --proxy-count ) proxy_count="$2"; shift 2 ;;
    -u | --username ) user="$2"; shift 2 ;;
    -p | --password ) password="$2"; shift 2 ;;
    -t | --proxies-type ) proxies_type="$2"; shift 2 ;;
    -r | --rotating-interval ) rotating_interval="$2"; shift 2;;
    -m | --ipv6-mask ) subnet_mask="$2"; shift 2;;
    -b | --backconnect-ip ) backconnect_ipv4="$2"; shift 2;;
    -f | --backconnect_proxies_file ) backconnect_proxies_file="$2"; shift 2;;
    -i | --interface ) interface_name="$2"; shift 2;;
    -l | --localhost ) use_localhost=true; shift ;;
    -d | --disable-inet6-ifaces-check ) inet6_network_interfaces_configuration_check=false; shift ;;
    --allowed-hosts ) allowed_hosts="$2"; shift 2;;
    --denied-hosts ) denied_hosts="$2"; shift 2;;
    --uninstall ) uninstall=true; shift ;;
    --info ) print_info=true; shift ;;
    --start-port ) start_port="$2"; shift 2;;
    --random ) use_random_auth=true; shift ;;
    -- ) shift; break ;;
    * ) break ;;
  esac
done

function log_err(){
  echo "$1" >&2;
}

function log_err_and_exit(){
  log_err "$1";
  exit 1;
}

function log_err_print_usage_and_exit(){
  log_err "$1";
  usage;
}

function is_valid_ip(){
  [[ "$1" =~ ^(([0-9]{1,3}\.){3}[0-9]{1,3})$ ]]
}

function is_auth_used(){
  [[ ! -z $user && ! -z $password ]] || [[ $use_random_auth == true ]]
}

function check_startup_parameters(){
# Check validity of user provided arguments
re='^[0-9]+$'
if ! [[ $proxy_count =~ $re ]]; then log_err_print_usage_and_exit "Error: Argument -c (proxy count) must be a positive integer number"; fi;

if ([ -z $user ] || [ -z $password ]) && is_auth_used && [ $use_random_auth = false ]; then log_err_print_usage_and_exit "Error: user and password for proxy with auth is required (specify both '--username' and '--password' startup parameters)"; fi;

if ([[ ! -z $user ]] || [[ ! -z $password ]]) && [ $use_random_auth = true ]; then log_err_print_usage_and_exit "Error: don't provide user or password as arguments, if '--random' flag is set."; fi;

if [ $proxies_type != "http" ] && [ $proxies_type != "socks5" ]; then log_err_print_usage_and_exit "Error: invalid value of '-t' (proxy type) parameter"; fi;

if (( $subnet % 4 != 0)); then log_err_print_usage_and_exit "Error: invalid value of '-s' (subnet) parameter, must be divisible by 4"; fi;

if (( $rotating_interval < 0 || $rotating_interval > 59)); then log_err_print_usage_and_exit "Error: invalid value of '-r' (proxy external ip rotating interval) parameter"; fi;

if (( $start_port < 5000 || ($start_port + $proxy_count > 65536))); then log_err_print_usage_and_exit "Wrong '--start-port' parameter value, it must be more than 5000 and '--start-port' + '--proxy-count' must be lower than 65536,
because Linux has only 65536 potentially ports";
fi;

if [[ ! -z $backconnect_ipv4 ]] && ! is_valid_ip $backconnect_ipv4; then log_err_and_exit "Error: ip provided in 'backconnect-ip' argument is invalid. Provide valid IP or don't use this argument"; fi;

if [[ ! -z "$allowed_hosts" ]] && [[ ! -z "$denied_hosts" ]]; then log_err_print_usage_and_exit "Error: if '--allow-hosts' is specified, you cannot use '--deny-hosts', the rest that isn't allowed is denied by default"; fi;

if [[ $(cat /sys/class/net/$interface_name/operstate) == "No such file or directory" ]]; then log_err_print_usage_and_exit "Incorrect ethernet interface name \"$interface_name\", provide correct name using parameter '--interface'";
fi;
}

# Define all needed paths to scripts / configs / etc.
bash_location="$(which bash)"
cd ~ # Get user home dir absolute path.
user_home_dir="$(pwd)"
proxy_dir="$user_home_dir/proxyserver"
proxyserver_config_path="$proxy_dir/3proxy/3proxy.cfg"
proxyserver_info_file="$proxy_dir/running_server.info"
random_ipv6_list_file="$proxy_dir/ipv6.list"
random_users_list_file="$proxy_dir/random_users.list"

# Define correct path to file with backconnect proxies list, if it isn't defined by user.
[[ $backconnect_proxies_file == "default" ]] && backconnect_proxies_file="$proxy_dir/backconnect_proxies.list";
startup_script_path="$proxy_dir/proxy-startup.sh"
cron_script_path="$proxy_dir/proxy-server.cron"
last_port=$(($start_port + $proxy_count -1));
credentials=$(is_auth_used && [[ $use_random_auth == false ]] && echo ":$user:$password" || echo "");

function is_proxyserver_installed(){
[[ -d $proxy_dir ]] && [[ "$(ls -A $proxy_dir)" ]]
}

function is_proxyserver_running(){
ps aux | grep -q $proxyserver_config_path
}

function is_package_installed(){
dpkg-query -W -f='${Status}' "$1" &>/dev/null || return $? == 'ok installed'
}

function create_random_string(){
tr dc A-Za-z </dev/urandom head c"$1"
}

function kill_3proxy(){
ps ef awk '/[3]proxy/{print$pid}' while read pid do kill"$pid" done;
}

function remove_ipv6_addresses_from_iface(){
[[ ! test f"$random_ipv6_list_file" ]] && return # Remove old ips from interface.
for ipv6_address in$(cat"$random_ipv6_list_file"); do ip addr del"$ipv6_address" dev"$interface_name" done rm"$random_ipv6_list_file";
fi;
}

function get_subnet_mask(){
[[ z"$subnet_mask"]] && return # If we parse addresses from iface and want to use lower subnets we need to clean existing proxy from interface before parsing.
[[ is_proxyserver_running ]] && kill_3proxy;
[[ is_proxyserver_installed ]] && remove_ipv6_addresses_from_iface;
full_blocks_count=$(($subnet/16)); # Full external ipv6 address allocated to the interface.
ipv6=$(ip addr awk'{print$}' grep mP'^fe80([09a-fAF]{14})+' cut d'/');
subnet_mask=$(echo"$ipv6" grep mP'^fe80([09a-fAF]{14})+'$(($full_blocks_count))'[09a-fAF]');
[[ expr"$subnet"%16!=]] && return # Get last uncomplete block if we want subnet get block from to.
block_part=$(echo"$ipv6" awk vblock$(($full_blocks_count)) F':' '{print$block}' tr d);
while((${block_part}<));do block_part="block_part";
done;
symbols_to_include=$(echo"$block_part" head c$(($(expr$subnet%)/)));
subnet_mask="subnet_mask:symbols_to_include";
fi;
echo"$subnet_mask";
}
