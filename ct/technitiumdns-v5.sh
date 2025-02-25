#!/usr/bin/env bash
function header_info {
  cat <<"EOF"
  ______          __          _ __  _                    ____  _   _______
 /_  __/__  _____/ /_  ____  (_) /_(_)_  ______ ___ v5  / __ \/ | / / ___/
  / / / _ \/ ___/ __ \/ __ \/ / __/ / / / / __  __ \   / / / /  |/ /\__ \ 
 / / /  __/ /__/ / / / / / / / /_/ / /_/ / / / / / /  / /_/ / /|  /___/ / 
/_/  \___/\___/_/ /_/_/ /_/_/\__/_/\__,_/_/ /_/ /_/  /_____/_/ |_//____/  
 
EOF
}
clear
header_info
echo -e "Loading..."
APP="Technitium DNS"
var_disk="2"
var_cpu="1"
var_ram="512"
var_os="debian"
var_version="11"
NSAPP=$(echo ${APP,,} | tr -d ' ')
var_install="${NSAPP}-v5-install"
INTEGER='^[0-9]+$'
YW=$(echo "\033[33m")
BL=$(echo "\033[36m")
RD=$(echo "\033[01;31m")
BGN=$(echo "\033[4;92m")
GN=$(echo "\033[1;92m")
DGN=$(echo "\033[32m")
CL=$(echo "\033[m")
BFR="\\r\\033[K"
HOLD="-"
CM="${GN}✓${CL}"
CROSS="${RD}✗${CL}"
set -o errexit
set -o errtrace
set -o nounset
set -o pipefail
shopt -s expand_aliases
alias die='EXIT=$? LINE=$LINENO error_exit'
trap die ERR
function error_exit() {
  trap - ERR
  local reason="Unknown failure occurred."
  local msg="${1:-$reason}"
  local flag="${RD}‼ ERROR ${CL}$EXIT@$LINE"
  echo -e "$flag $msg" 1>&2
  exit $EXIT
}

function msg_info() {
  local msg="$1"
  echo -ne " ${HOLD} ${YW}${msg}..."
}

function msg_ok() {
  local msg="$1"
  echo -e "${BFR} ${CM} ${GN}${msg}${CL}"
}

function msg_error() {
    local msg="$1"
    echo -e "${BFR} ${CROSS} ${RD}${msg}${CL}"
}

function PVE_CHECK() {
  PVE=$(pveversion | grep "pve-manager/7" | wc -l)
  if [[ $PVE != 1 ]]; then
    echo -e "${RD}This script requires Proxmox Virtual Environment 7.0 or greater${CL}"
    echo -e "Exiting..."
    sleep 2
    exit
  fi
}

if command -v pveversion >/dev/null 2>&1; then
  if (whiptail --title "${APP} LXC" --yesno "This will create a New ${APP} LXC. Proceed?" 10 58); then
    NEXTID=$(pvesh get /cluster/nextid)
  else
    clear
    echo -e "⚠ User exited script \n"
    exit
  fi
fi
if ! command -v pveversion >/dev/null 2>&1; then
  if [[ ! -d /etc/dns ]]; then
    msg_error "No ${APP} Installation Found!";
    exit 
  fi
  if (whiptail --title "${APP} LXC UPDATE" --yesno "This will update ${APP} LXC.  Proceed?" 10 58); then
    echo "User selected Update"
    else
    clear
    echo -e "⚠ User exited script \n"
    exit
  fi
fi

function default_settings() {
  echo -e "${DGN}Using Container Type: ${BGN}Unprivileged${CL} ${RD}NO DEVICE PASSTHROUGH${CL}"
  CT_TYPE="1"
  echo -e "${DGN}Using Root Password: ${BGN}Automatic Login${CL}"
  PW=""
  echo -e "${DGN}Using Container ID: ${BGN}$NEXTID${CL}"
  CT_ID=$NEXTID
  echo -e "${DGN}Using Hostname: ${BGN}$NSAPP${CL}"
  HN=$NSAPP
  echo -e "${DGN}Using Disk Size: ${BGN}$var_disk${CL}${DGN}GB${CL}"
  DISK_SIZE="$var_disk"
  echo -e "${DGN}Allocated Cores ${BGN}$var_cpu${CL}"
  CORE_COUNT="$var_cpu"
  echo -e "${DGN}Allocated Ram ${BGN}$var_ram${CL}"
  RAM_SIZE="$var_ram"
  echo -e "${DGN}Using Bridge: ${BGN}vmbr0${CL}"
  BRG="vmbr0"
  echo -e "${DGN}Using Static IP Address: ${BGN}dhcp${CL}"
  NET=dhcp
  echo -e "${DGN}Using Gateway Address: ${BGN}Default${CL}"
  GATE=""
  echo -e "${DGN}Using DNS Search Domain: ${BGN}Host${CL}"
  SD=""
  echo -e "${DGN}Using DNS Server Address: ${BGN}Host${CL}"
  NS=""
  echo -e "${DGN}Using MAC Address: ${BGN}Default${CL}"
  MAC=""
  echo -e "${DGN}Using VLAN Tag: ${BGN}Default${CL}"
  VLAN=""
  echo -e "${DGN}Enable Root SSH Access: ${BGN}No${CL}"
  SSH="no"
  echo -e "${DGN}Enable Verbose Mode: ${BGN}No${CL}"
  VERB="no"
  VERB2="silent"
  echo -e "${BL}Creating a ${APP} LXC using the above default settings${CL}"
}
function advanced_settings() {
  CT_TYPE=$(whiptail --title "CONTAINER TYPE" --radiolist --cancel-button Exit-Script "Choose Type" 10 58 2 \
    "1" "Unprivileged" ON \
    "0" "Privileged" OFF \
    3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ $exitstatus = 0 ]; then
    echo -e "${DGN}Using Container Type: ${BGN}$CT_TYPE${CL}"
  fi
  PW1=$(whiptail --inputbox "Set Root Password (needed for root ssh access)" 8 58 --title "PASSWORD(leave blank for automatic login)" --cancel-button Exit-Script 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ $exitstatus = 0 ]; then
    if [ -z $PW1 ]; then
      PW1="Automatic Login" PW=" "
      echo -e "${DGN}Using Root Password: ${BGN}$PW1${CL}"
    else
      PW="-password $PW1"
      echo -e "${DGN}Using Root Password: ${BGN}$PW1${CL}"
    fi
  fi
  CT_ID=$(whiptail --inputbox "Set Container ID" 8 58 $NEXTID --title "CONTAINER ID" --cancel-button Exit-Script 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ -z $CT_ID ]; then
    CT_ID="$NEXTID"
    echo -e "${DGN}Container ID: ${BGN}$CT_ID${CL}"
  else
    if [ $exitstatus = 0 ]; then echo -e "${DGN}Using Container ID: ${BGN}$CT_ID${CL}"; fi
  fi
  CT_NAME=$(whiptail --inputbox "Set Hostname" 8 58 $NSAPP --title "HOSTNAME" --cancel-button Exit-Script 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ -z $CT_NAME ]; then
    HN="$NSAPP"
    echo -e "${DGN}Using Hostname: ${BGN}$HN${CL}"
  else
    if [ $exitstatus = 0 ]; then
      HN=$(echo ${CT_NAME,,} | tr -d ' ')
      echo -e "${DGN}Using Hostname: ${BGN}$HN${CL}"
    fi
  fi
  DISK_SIZE=$(whiptail --inputbox "Set Disk Size in GB" 8 58 $var_disk --title "DISK SIZE" --cancel-button Exit-Script 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ -z $DISK_SIZE ]; then
    DISK_SIZE="$var_disk"
    echo -e "${DGN}Using Disk Size: ${BGN}$DISK_SIZE${CL}"
  else
    if [ $exitstatus = 0 ]; then echo -e "${DGN}Using Disk Size: ${BGN}$DISK_SIZE${CL}"; fi
    if ! [[ $DISK_SIZE =~ $INTEGER ]]; then
      echo -e "${RD}⚠ DISK SIZE MUST BE A INTEGER NUMBER!${CL}"
      advanced_settings
    fi
  fi
  CORE_COUNT=$(whiptail --inputbox "Allocate CPU Cores" 8 58 $var_cpu --title "CORE COUNT" --cancel-button Exit-Script 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ -z $CORE_COUNT ]; then
    CORE_COUNT="$var_cpu"
    echo -e "${DGN}Allocated Cores: ${BGN}$CORE_COUNT${CL}"
  else
    if [ $exitstatus = 0 ]; then echo -e "${DGN}Allocated Cores: ${BGN}$CORE_COUNT${CL}"; fi
  fi
  RAM_SIZE=$(whiptail --inputbox "Allocate RAM in MiB" 8 58 $var_ram --title "RAM" --cancel-button Exit-Script 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ -z $RAM_SIZE ]; then
    RAM_SIZE="$var_ram"
    echo -e "${DGN}Allocated RAM: ${BGN}$RAM_SIZE${CL}"
  else
    if [ $exitstatus = 0 ]; then echo -e "${DGN}Allocated RAM: ${BGN}$RAM_SIZE${CL}"; fi
  fi
  BRG=$(whiptail --inputbox "Set a Bridge" 8 58 vmbr0 --title "BRIDGE" --cancel-button Exit-Script 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ -z $BRG ]; then
    BRG="vmbr0"
    echo -e "${DGN}Using Bridge: ${BGN}$BRG${CL}"
  else
    if [ $exitstatus = 0 ]; then echo -e "${DGN}Using Bridge: ${BGN}$BRG${CL}"; fi
  fi
  NET=$(whiptail --inputbox "Set a Static IPv4 CIDR Address(/24)" 8 58 dhcp --title "IP ADDRESS" --cancel-button Exit-Script 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ -z $NET ]; then
    NET="dhcp"
    echo -e "${DGN}Using IP Address: ${BGN}$NET${CL}"
  else
    if [ $exitstatus = 0 ]; then echo -e "${DGN}Using IP Address: ${BGN}$NET${CL}"; fi
  fi
  GATE1=$(whiptail --inputbox "Set a Gateway IP (mandatory if Static IP was used)" 8 58 --title "GATEWAY IP" --cancel-button Exit-Script 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ $exitstatus = 0 ]; then
    if [ -z $GATE1 ]; then
      GATE1="Default" GATE=""
      echo -e "${DGN}Using Gateway IP Address: ${BGN}$GATE1${CL}"
    else
      GATE=",gw=$GATE1"
      echo -e "${DGN}Using Gateway IP Address: ${BGN}$GATE1${CL}"
    fi
  fi
  SD=$(whiptail --inputbox "Set a DNS Search Domain (leave blank for HOST)" 8 58 --title "DNS Search Domain" --cancel-button Exit-Script 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ $exitstatus = 0 ]; then
    if [ -z $SD ]; then
      SD=""
      echo -e "${DGN}Using DNS Search Domain: ${BGN}Host${CL}"
    else
      SX=$SD
      SD="-searchdomain=$SD"
      echo -e "${DGN}Using DNS Search Domain: ${BGN}$SX${CL}"
    fi
  fi
  NS=$(whiptail --inputbox "Set a DNS Server IP (leave blank for HOST)" 8 58 --title "DNS SERVER IP" --cancel-button Exit-Script 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ $exitstatus = 0 ]; then
    if [ -z $NS ]; then
      NS=""
      echo -e "${DGN}Using DNS Server IP Address: ${BGN}Host${CL}"
    else
      NX=$NS
      NS="-nameserver=$NS"
      echo -e "${DGN}Using DNS Server IP Address: ${BGN}$NX${CL}"
    fi
  fi
  MAC1=$(whiptail --inputbox "Set a MAC Address(leave blank for default)" 8 58 --title "MAC ADDRESS" --cancel-button Exit-Script 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ $exitstatus = 0 ]; then
    if [ -z $MAC1 ]; then
      MAC1="Default" MAC=""
      echo -e "${DGN}Using MAC Address: ${BGN}$MAC1${CL}"
    else
      MAC=",hwaddr=$MAC1"
      echo -e "${DGN}Using MAC Address: ${BGN}$MAC1${CL}"
    fi
  fi
  VLAN1=$(whiptail --inputbox "Set a Vlan(leave blank for default)" 8 58 --title "VLAN" --cancel-button Exit-Script 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ $exitstatus = 0 ]; then
    if [ -z $VLAN1 ]; then
      VLAN1="Default" VLAN=""
      echo -e "${DGN}Using Vlan: ${BGN}$VLAN1${CL}"
    else
      VLAN=",tag=$VLAN1"
      echo -e "${DGN}Using Vlan: ${BGN}$VLAN1${CL}"
    fi
  fi
  if (whiptail --defaultno --title "SSH ACCESS" --yesno "Enable Root SSH Access?" 10 58); then
      echo -e "${DGN}Enable Root SSH Access: ${BGN}Yes${CL}"
      SSH="yes"
  else
      echo -e "${DGN}Enable Root SSH Access: ${BGN}No${CL}"
      SSH="no"
  fi
  if (whiptail --defaultno --title "VERBOSE MODE" --yesno "Enable Verbose Mode?" 10 58); then
      echo -e "${DGN}Enable Verbose Mode: ${BGN}Yes${CL}"
      VERB="yes"
      VERB2=""
  else
      echo -e "${DGN}Enable Verbose Mode: ${BGN}No${CL}"
      VERB="no"
      VERB2="silent"
  fi
  if (whiptail --title "ADVANCED SETTINGS COMPLETE" --yesno "Ready to create ${APP} LXC?" --no-button Do-Over 10 58); then
    echo -e "${RD}Creating a ${APP} LXC using the above advanced settings${CL}"
  else
    clear
    header_info
    echo -e "${RD}Using Advanced Settings${CL}"
    advanced_settings
  fi
}
function install_script() {
  if (whiptail --title "SETTINGS" --yesno "Use Default Settings?" --no-button Advanced 10 58); then
    header_info
    echo -e "${BL}Using Default Settings${CL}"
    default_settings
  else
    header_info
    echo -e "${RD}Using Advanced Settings${CL}"
    advanced_settings
  fi
}

function update_script() {
clear
header_info
msg_info "Updating ${APP} LXC"
dotnetDir="/opt/dotnet"
dnsDir="/etc/dns"
dnsTar="/etc/dns/DnsServerPortable.tar.gz"
dnsUrl="https://download.technitium.com/dns/DnsServerPortable.tar.gz"

mkdir -p $dnsDir
installLog="$dnsDir/install.log"
echo "" >$installLog

echo ""
echo "==============================="
echo "Technitium DNS Server Update"
echo "==============================="

if dotnet --list-runtimes 2>/dev/null | grep -q "Microsoft.NETCore.App 7.0."; then
	dotnetFound="yes"
else
	dotnetFound="no"
fi

if [ -d $dotnetDir ]; then
	dotnetUpdate="yes"
	echo "Updating .NET 7 Runtime..."
fi

curl -sSL https://dot.net/v1/dotnet-install.sh | bash /dev/stdin -c 7.0 --runtime dotnet --no-path --install-dir $dotnetDir --verbose >>$installLog 2>&1

if [ ! -f "/usr/bin/dotnet" ]; then
	ln -s $dotnetDir/dotnet /usr/bin >>$installLog 2>&1
fi

if dotnet --list-runtimes 2>/dev/null | grep -q "Microsoft.NETCore.App 7.0."; then
	if [ "$dotnetUpdate" = "yes" ]; then
		echo ".NET 7 Runtime was updated successfully!"
	fi
else
	echo "Failed to update .NET 7 Runtime. Please try again."
	exit 1
fi

if curl -o $dnsTar --fail $dnsUrl >>$installLog 2>&1; then
	if [ -d $dnsDir ]; then
		echo "Updating Technitium DNS Server..."
	fi

	tar -zxf $dnsTar -C $dnsDir >>$installLog 2>&1

	if [ "$(ps --no-headers -o comm 1 | tr -d '\n')" = "systemd" ]; then
		if [ -f "/etc/systemd/system/dns.service" ]; then
			echo "Restarting systemd service..."
			systemctl restart dns.service >>$installLog 2>&1
		fi

		echo ""
		echo "Technitium DNS Server was updated successfully!"
	else
		echo ""
		echo "Failed to update Technitium DNS Server: systemd was not detected."
		exit 1
	fi
else
	echo ""
	echo "Failed to download Technitium DNS Server from: $dnsUrl"
	exit 1
fi
msg_ok "Update Successfull"
exit
}
clear
if ! command -v pveversion >/dev/null 2>&1; then update_script; else install_script; fi
if [ "$VERB" == "yes" ]; then set -x; fi
if [ "$CT_TYPE" == "1" ]; then
  FEATURES="nesting=1,keyctl=1"
else
  FEATURES="nesting=1"
fi
TEMP_DIR=$(mktemp -d)
pushd $TEMP_DIR >/dev/null
export VERBOSE=$VERB
export STD=$VERB2
export SSH_ROOT=${SSH}
export CTID=$CT_ID
export PCT_OSTYPE=$var_os
export PCT_OSVERSION=$var_version
export PCT_DISK_SIZE=$DISK_SIZE
export PCT_OPTIONS="
  -features $FEATURES
  -hostname $HN
  $SD
  $NS
  -net0 name=eth0,bridge=$BRG$MAC,ip=$NET$GATE$VLAN
  -onboot 1
  -cores $CORE_COUNT
  -memory $RAM_SIZE
  -unprivileged $CT_TYPE
  $PW
"
bash -c "$(wget -qLO - https://raw.githubusercontent.com/tteck/Proxmox/main/ct/create_lxc.sh)" || exit
msg_info "Starting LXC Container"
pct start $CTID
msg_ok "Started LXC Container"
lxc-attach -n $CTID -- bash -c "$(wget -qLO - https://raw.githubusercontent.com/tteck/Proxmox/main/install/$var_install.sh)" || exit
IP=$(pct exec $CTID ip a s dev eth0 | sed -n '/inet / s/\// /p' | awk '{print $2}')
pct set $CTID -description "# ${APP} LXC
### https://tteck.github.io/Proxmox/
<a href='https://ko-fi.com/D1D7EP4GF'><img src='https://img.shields.io/badge/☕-Buy me a coffee-red' /></a>"
msg_ok "Completed Successfully!\n"
echo -e "${APP} should be reachable by going to the following URL.
         ${BL}http://${IP}:5380${CL} \n"
