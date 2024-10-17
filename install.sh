#!/bin/bash
ZIPFILE="/tmp/xray/xray-linux-64.zip"
SYSTEMCTL_CMD=$(command -v systemctl 2>/dev/null)
SERVICE_CMD=$(command -v service 2>/dev/null)

downloadxray(){
    rm -rf /tmp/xray
    mkdir -p /tmp/xray
    DOWNLOAD_LINK="https://github.com/zhailiangs/xray-install/raw/main/xray-linux-64.zip"
    echo "Downloading xray: ${DOWNLOAD_LINK}"
    curl -L -H "Cache-Control: no-cache" -o ${ZIPFILE} ${DOWNLOAD_LINK}
    if [ $? != 0 ];then
        echo "Failed to download! Please check your network or try again."
        return 3
    fi
    return 0
}
zipRoot() {
    unzip -lqq "$1" | awk -e '
        NR == 1 {
            prefix = $4;
        }
        NR != 1 {
            prefix_len = length(prefix);
            cur_len = length($4);

            for (len = prefix_len < cur_len ? prefix_len : cur_len; len >= 1; len -= 1) {
                sub_prefix = substr(prefix, 1, len);
                sub_cur = substr($4, 1, len);

                if (sub_prefix == sub_cur) {
                    prefix = sub_prefix;
                    break;
                }
            }

            if (len == 0) {
                prefix = "";
                nextfile;
            }
        }
        END {
            print prefix;
        }
}

stopxray(){
    echo ${BLUE} "Shutting down xray service."
    if [[ -n "${SYSTEMCTL_CMD}" ]] || [[ -f "/lib/systemd/system/xray.service" ]] || [[ -f "/etc/systemd/system/xray.service" ]]; then
        ${SYSTEMCTL_CMD} stop xray
    elif [[ -n "${SERVICE_CMD}" ]] || [[ -f "/etc/init.d/xray" ]]; then
        ${SERVICE_CMD} xray stop
    fi
    if [[ $? -ne 0 ]]; then
        echo ${YELLOW} "Failed to shutdown xray service."
        return 2
    fi
    return 0
}
installxray(){
    # Install xray binary to /usr/bin/xray
    mkdir -p '/etc/xray' '/var/log/xray' && \
    unzip -oj "$1" "$2xray" "$2geoip.dat" "$2geosite.dat" -d '/usr/bin/xray' && \
    chmod +x '/usr/bin/xray/xray' || {
        echo "Failed to copy xray binary and resources."
        return 1
    }

    # Install xray server config to /etc/xray
    if [ ! -f '/etc/xray/config.json' ]; then
        local PORT="$(($RANDOM + 10000))"
        local UUID="$(cat '/proc/sys/kernel/random/uuid')"

        unzip -pq "$1" "$2vpoint_vmess_freedom.json" | \
        sed -e "s/10086/${PORT}/g; s/23ad6b10-8d1a-40f7-8ad0-e3e35cd38297/${UUID}/g;" - > \
        '/etc/xray/config.json' || {
            echo ${YELLOW} "Failed to create xray configuration file. Please create it manually."
            return 1
        }
        echo "------记住下面的内容----------"
        echo "PORT:${PORT}"
        echo "UUID:${UUID}"
        echo "------记住上面的内容----------"
    fi
}


installInitScript(){
    if [[ -n "${SYSTEMCTL_CMD}" ]]; then
        if [[ ! -f "/etc/systemd/system/xray.service" && ! -f "/lib/systemd/system/xray.service" ]]; then
            unzip -oj "$1" "$2systemd/system/xray.service" -d '/etc/systemd/system' && \
            systemctl enable xray.service
        fi
    elif [[ -n "${SERVICE_CMD}" ]] && [[ ! -f "/etc/init.d/xray" ]]; then
        installSoftware 'daemon' && \
        unzip -oj "$1" "$2systemv/xray" -d '/etc/init.d' && \
        chmod +x '/etc/init.d/xray' && \
        update-rc.d xray defaults
    fi
}

startxray(){
    if [ -n "${SYSTEMCTL_CMD}" ] && [[ -f "/lib/systemd/system/xray.service" || -f "/etc/systemd/system/xray.service" ]]; then
        ${SYSTEMCTL_CMD} start xray
    elif [ -n "${SERVICE_CMD}" ] && [ -f "/etc/init.d/xray" ]; then
        ${SERVICE_CMD} xray start
    fi
    if [[ $? -ne 0 ]]; then
        echo "Failed to start xray service."
        return 2
    fi
    return 0
}

if pgrep "xray" > /dev/null ; then
    xray_RUNNING=1
    stopxray
fi
downloadxray
ZIPROOT="$(zipRoot "${ZIPFILE}")"
installxray "${ZIPFILE}" "${ZIPROOT}"
installInitScript "${ZIPFILE}" "${ZIPROOT}"
echo "start xray service."
startxray
echo "xray is installed."
rm -rf /tmp/xray
