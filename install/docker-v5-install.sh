#!/usr/bin/env bash
if [ "$VERBOSE" == "yes" ]; then set -x; fi
YW=$(echo "\033[33m")
RD=$(echo "\033[01;31m")
BL=$(echo "\033[36m")
GN=$(echo "\033[1;92m")
CL=$(echo "\033[m")
RETRY_NUM=10
RETRY_EVERY=3
NUM=$RETRY_NUM
CM="${GN}✓${CL}"
CROSS="${RD}✗${CL}"
BFR="\\r\\033[K"
HOLD="-"
set -o errexit
set -o errtrace
set -o nounset
set -o pipefail
shopt -s expand_aliases
alias die='EXIT=$? LINE=$LINENO error_exit'
trap die ERR
silent() { "$@" > /dev/null 2>&1; }
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

msg_info "Setting up Container OS "
sed -i "/$LANG/ s/\(^# \)//" /etc/locale.gen
locale-gen >/dev/null
while [ "$(hostname -I)" = "" ]; do
  echo 1>&2 -en "${CROSS}${RD} No Network! "
  sleep $RETRY_EVERY
  ((NUM--))
  if [ $NUM -eq 0 ]; then
    echo 1>&2 -e "${CROSS}${RD} No Network After $RETRY_NUM Tries${CL}"
    exit 1
  fi
done
msg_ok "Set up Container OS"
msg_ok "Network Connected: ${BL}$(hostname -I)"

set +e
alias die=''
if nc -zw1 8.8.8.8 443; then msg_ok "Internet Connected"; else
  msg_error "Internet NOT Connected"
    read -r -p "Would you like to continue anyway? <y/N> " prompt
    if [[ $prompt == "y" || $prompt == "Y" || $prompt == "yes" || $prompt == "Yes" ]]; then
      echo -e " ⚠️  ${RD}Expect Issues Without Internet${CL}"
    else
      echo -e " 🖧  Check Network Settings"
      exit 1
    fi
fi
RESOLVEDIP=$(nslookup "github.com" | awk -F':' '/^Address: / { matched = 1 } matched { print $2}' | xargs)
if [[ -z "$RESOLVEDIP" ]]; then msg_error "DNS Lookup Failure"; else msg_ok "DNS Resolved github.com to $RESOLVEDIP"; fi
alias die='EXIT=$? LINE=$LINENO error_exit'
set -e

msg_info "Updating Container OS"
$STD apt-get update
$STD apt-get -y upgrade
msg_ok "Updated Container OS"

msg_info "Installing Dependencies"
$STD apt-get install -y curl
$STD apt-get install -y sudo
msg_ok "Installed Dependencies"

get_latest_release() {
  curl -sL https://api.github.com/repos/$1/releases/latest | grep '"tag_name":' | cut -d'"' -f4
}

DOCKER_LATEST_VERSION='v20.10.22'
PORTAINER_LATEST_VERSION='2.16.2'
DOCKER_COMPOSE_LATEST_VERSION='v2.15.1'

msg_info "Installing Docker $DOCKER_LATEST_VERSION"
DOCKER_CONFIG_PATH='/etc/docker/daemon.json'
mkdir -p $(dirname $DOCKER_CONFIG_PATH)
if [ "$ST" == "yes" ]; then
VER=$(curl -s https://api.github.com/repos/containers/fuse-overlayfs/releases/latest | grep "tag_name" | awk '{print substr($2, 2, length($2)-3) }')
cd /usr/local/bin
curl -sSL -o fuse-overlayfs https://github.com/containers/fuse-overlayfs/releases/download/$VER/fuse-overlayfs-x86_64
chmod 755 /usr/local/bin/fuse-overlayfs
cd ~
echo -e '{\n  "storage-driver": "fuse-overlayfs",\n  "log-driver": "journald"\n}' > /etc/docker/daemon.json
else
echo -e '{\n  "log-driver": "journald"\n}' > /etc/docker/daemon.json
fi
$STD sh <(curl -sSL https://get.docker.com)
msg_ok "Installed Docker $DOCKER_LATEST_VERSION"

read -r -p "Would you like to add Portainer? <y/N> " prompt
if [[ $prompt == "y" || $prompt == "Y" || $prompt == "yes" || $prompt == "Yes" ]]; then
  PORTAINER="Y"
else
  PORTAINER="N"
fi

if [[ $PORTAINER == "Y" ]]; then
  msg_info "Installing Portainer $PORTAINER_LATEST_VERSION"
  docker volume create portainer_data >/dev/null
 $STD docker run -d \
    -p 8000:8000 \
    -p 9000:9000 \
    --name=portainer \
    --restart=always \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v portainer_data:/data \
    portainer/portainer-ce:latest
  msg_ok "Installed Portainer $PORTAINER_LATEST_VERSION"
fi

read -r -p "Would you like to add Docker Compose? <y/N> " prompt
if [[ $prompt == "y" || $prompt == "Y" || $prompt == "yes" || $prompt == "Yes" ]]; then
  DOCKER_COMPOSE="Y"
else
  DOCKER_COMPOSE="N"
fi

if [[ $DOCKER_COMPOSE == "Y" ]]; then
  msg_info "Installing Docker Compose $DOCKER_COMPOSE_LATEST_VERSION"
  DOCKER_CONFIG=${DOCKER_CONFIG:-$HOME/.docker}
  mkdir -p $DOCKER_CONFIG/cli-plugins
  curl -sSL https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_LATEST_VERSION/docker-compose-linux-x86_64 -o ~/.docker/cli-plugins/docker-compose
  chmod +x $DOCKER_CONFIG/cli-plugins/docker-compose
  msg_ok "Installed Docker Compose $DOCKER_COMPOSE_LATEST_VERSION"
fi

PASS=$(grep -w "root" /etc/shadow | cut -b6)
if [[ $PASS != $ ]]; then
  msg_info "Customizing Container"
  rm /etc/motd
  rm /etc/update-motd.d/10-uname
  touch ~/.hushlogin
  GETTY_OVERRIDE="/etc/systemd/system/container-getty@1.service.d/override.conf"
  mkdir -p $(dirname $GETTY_OVERRIDE)
  cat <<EOF >$GETTY_OVERRIDE
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear --keep-baud tty%I 115200,38400,9600 \$TERM
EOF
  systemctl daemon-reload
  systemctl restart $(basename $(dirname $GETTY_OVERRIDE) | sed 's/\.d//')
  msg_ok "Customized Container"
fi
if [[ "${SSH_ROOT}" == "yes" ]]; then
  sed -i "s/#PermitRootLogin prohibit-password/PermitRootLogin yes/g" /etc/ssh/sshd_config
  systemctl restart sshd
fi

msg_info "Cleaning up"
$STD apt-get autoremove
$STD apt-get autoclean
msg_ok "Cleaned"
