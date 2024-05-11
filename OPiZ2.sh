#!/bin/bash

# 定义颜色输出函数
red() { echo -e "\033[31m\033[01m[WARNING] $1\033[0m"; }
green() { echo -e "\033[32m\033[01m[INFO] $1\033[0m"; }
greenline() { echo -e "\033[32m\033[01m $1\033[0m"; }
yellow() { echo -e "\033[33m\033[01m[NOTICE] $1\033[0m"; }
blue() { echo -e "\033[34m\033[01m[MESSAGE] $1\033[0m"; }
light_magenta() { echo -e "\033[95m\033[01m[NOTICE] $1\033[0m"; }
highlight() { echo -e "\033[32m\033[01m$1\033[0m"; }
cyan() { echo -e "\033[38;2;0;255;255m$1\033[0m"; }

# 检查是否以 root 用户身份运行
if [ "$(id -u)" -ne 0 ]; then
    echo "此脚本需要以 root 用户权限运行，请输入当前用户的密码："
    green "注意！输入密码过程不显示*号属于正常现象"
    sudo "$0" "$@" # 重新以 root 权限运行此脚本
    exit $?
fi

proxy=""
if [ $# -gt 0 ]; then
    proxy="https://mirror.ghproxy.com/"
fi

declare -a menu_options
declare -A commands
menu_options=(
    "主机信息"
    "修改登录密码"
    "修改日志输入等级"
    "更新系统软件包"
    "一键配置Vim"
    "安装wiringPi库"
    "配置UART5\IIC3\SPI1"
    "安装并配置Samba"
    "安装并启动文件管理器FileBrowser"
    "启动文件管理器FileBrowser"
    "安装1panel面板管理工具"
    "查看1panel用户信息"
    "更新脚本"
)

commands=(
    ["主机信息"]="host_info"
    ["修改登录密码"]="change_password"
    ["修改日志输入等级"]="change_log_level"
    ["更新系统软件包"]="update_system_packages"
    ["一键配置Vim"]="install_vim"
    ["安装wiringPi库"]="install_wiringPi"
    ["配置UART5\IIC3\SPI1"]="config_uart5_iic3_spi1"
    ["安装并配置Samba"]="install_samba"
    ["安装并启动文件管理器FileBrowser"]="install_filemanager"
    ["启动文件管理器FileBrowser"]="start_filemanager"
    ["安装1panel面板管理工具"]="install_1panel_on_linux"
    ["查看1panel用户信息"]="read_user_info"
    ["更新脚本"]="update_scripts"
)

# 获取CPU占用率
get_cpu_usage() {
    # 从 /proc/stat 文件中读取 CPU 利用率信息
    local stat_file="/proc/stat"
    local line
    local user
    local nice
    local system
    local idle
    local iowait
    local irq
    local softirq
    local total
    local non_idle
    local usage

    # 如果无法打开 /proc/stat 文件，则输出错误信息并退出
    if [[ ! -f "$stat_file" ]]; then
        echo "Error opening stat file" >&2
        exit 1
    fi

    if read -r line < "$stat_file"; then
        if [[ "$line" == "cpu"* ]]; then
            read -r _ user nice system idle iowait irq softirq _ <<< "$line"
            total=$((user + nice + system + idle + iowait + irq + softirq))
            non_idle=$((user + nice + system + iowait + irq + softirq))
            usage=$(awk "BEGIN {printf \"%.2f\", 100.0 * $non_idle / $total}")
            echo "$usage"
            return
        fi
    fi

    # 如果无法获取 CPU 利用率信息，则输出默认值 -1.0
    echo "-1.0"
}

# 主机信息
host_info() {
    # 获取主机名
    hostname=$(hostname)
    green "Hostname: $hostname"

    # 获取系统运行时间（天数、小时、分钟、秒）
    uptime_seconds=$(($(date +%s) - $(date -d "$(uptime -s)" +%s)))
    uptime_days=$((uptime_seconds / 86400))
    remaining_seconds=$((uptime_seconds % 86400))
    uptime_hours=$((remaining_seconds / 3600))
    remaining_seconds=$((remaining_seconds % 3600))
    uptime_minutes=$((remaining_seconds / 60))
    uptime_seconds=$((remaining_seconds % 60))
    green "Uptime: $uptime_days days $uptime_hours:$uptime_minutes:$uptime_seconds"

    # 获取当前时间
    current_time=$(date "+%Y-%m-%d %H:%M:%S")
    green "Current time: $current_time"

    # 获取eth0 IP地址
    eth0_ip=$(ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
    green "eth0 IP: $eth0_ip"

    # 获取wlan0 IP地址
    wlan0_ip=$(ip -4 addr show wlan0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
    green "wlan0 IP: $wlan0_ip"

    # 获取CPU使用率
    cpu_usage=$(get_cpu_usage)
    green "CPU Load: $cpu_usage%"

    # CPU温度（注意：获取CPU温度依赖于硬件和系统配置，这里提供一个通用思路）
    cpu_temp=$(</sys/class/thermal/thermal_zone0/temp) # 单位为微摄氏度*1000，需转换
    cpu_temp=$(echo "scale=2; $cpu_temp / 1000" | bc)
    green "CPU Temp: $cpu_temp°C"

    # 内存使用情况
    memory_usage=$(free -m | awk 'NR==2{printf "%dMB/%dMB %.2f%%", $3, $2, $3*100/$2 }')
    green "Memory Usage: $memory_usage"

    # 磁盘使用情况（以根目录为例）
    disk_usage=$(df -h / | awk '$NF=="/" {printf "%sB/%sB %s", $3, $2, $5}')
    green "Disk Usage: $disk_usage"
}

# 修改登录密码
change_password() {
    sudo passwd orangepi
    green "密码修改成功，请使用新密码登录"
}

# 修改日志输入等级
change_log_level() {
    local env_file="/boot/orangepiEnv.txt"

    echo "日志等级参考标准（log level）"
    echo "0 - emerg (Emergency)：紧急情况，系统无法使用。"
    echo "1 - alert (Alert)：需要立即采取行动的情况。"
    echo "2 - crit (Critical)：严重错误，有些功能可能无法执行。"
    echo "3 - err (Error)：错误状态，操作未按预期进行。"
    echo "4 - warning (Warning)：警告状态，非错误情况，但可能需要关注。"
    echo "5 - notice (Notice)：正常但重要的事件，比如服务启动或停止。"
    echo "6 - info (Informational)：信息性消息，确认系统操作无误。"
    echo "7 - debug (Debug)：调试信息，最详细的日志，包含所有程序流程细节。"

    read -p "请输入日志等级（0-7）：" log_level
    if [[ ! $log_level =~ ^[0-7]$ ]]; then
        red "日志等级输入错误，请输入1-7之间的整数"
        return 1
    fi
    sed -i "s/verbosity=[0-7]*/verbosity=$log_level/" "$env_file"
    green "日志等级已修改为 $log_level"
}


# 更新系统软件包
update_system_packages() {
    green "Setting timezone Asia/Shanghai..."
    sudo timedatectl set-timezone Asia/Shanghai
    # 更新系统软件包
    green "Updating system packages..."
    sudo apt update
    sudo apt-get upgrade -y
}

# 一键配置Vim
install_vim() {
    # 检查是否已安装 Vim
    if command -v vim &>/dev/null; then
        yellow "Vim 已安装，跳过安装步骤"
    else
        # 安装 Vim
        green "Installing Vim..."
        sudo apt-get update
        sudo apt-get install vim -y
        if [ $? -ne 0 ]; then
            red "Failed to install Vim"
            return 1
        fi
    fi

    # 检查 Vim 配置文件是否存在
    local vimrc="/etc/vim/vimrc"
    if [ ! -f "$vimrc" ]; then
        red "Vim 配置文件 $vimrc 不存在"
        return 1
    fi

    # 追加配置到 Vim 配置文件
    green "配置 Vim..."
    cat << EOF | sudo tee -a "$vimrc" >/dev/null
" Set syntax highlighting
syntax on
" Set the line number
set number
" Set an indent to account for 4 spaces
set tabstop=4
" Set up automatic indentation
set autoindent
" Set mouse is always available, set mouse= (empty) cancel
set mouse=a
" Tab prompt (as long as it is tab indented, there is a prompt)
set list lcs=tab:\|\
" Column 80 highlighted, set cc=0 cancellation
set cc=80
" Settings to highlight the current row
set cursorline
" Format C language
set cindent
" Set the width of the soft tab to 4 spaces
set st=4
" The width automatically indented when setting a new line is 4 spaces
set shiftwidth=4
" Set the number of spaces inserted when the Tab key is pressed in insertion
" mode to 4.
set sts=4
" Show the status of the last line
set ruler
" The status of this row is displayed in the lower left corner.
set showmode
" Show different background tones
set bg=dark
" Enable Search Highlight
set hlsearch
" set guicursor+=a:blinkon0

" Set Automatically Complete Parentheses
inoremap ' ''<ESC>i
inoremap " ""<ESC>i
inoremap ( ()<ESC>i
inoremap [ []<ESC>i
inoremap < <><ESC>i
inoremap { {<CR>}<ESC>O
" Set to jump out of the auto-complete parentheses
func SkipPair()
     if getline('.')[col('.') - 1] == '<' || getline('.')[col('.') - 1] == ')' || getline('.')[col('.') - 1    ] == ']' || getline('.')[col('.') - 1] == '"' || getline('.')[col('.') - 1] == "'" || getline('.')[col('.'    ) - 1] == '}'
        return "\<ESC>la"
    else
        return "\t"
    endif
endfunc
" be iMproved, required
set nocompatible
" required
filetype off
" Always display the status bar
set laststatus=2
EOF

    green "Vim 配置完成"
}

# 安装wiringPi库
install_wiringPi() {
    green "Installing wiringPi library..."
    sudo apt-get update

    # 判断是否要安装 git
    if ! command -v git &> /dev/null; then
        green "Installing git..."
        sudo apt-get install -y git
    fi

    #判断是否已经安装了 wiringPi 库
    if command -v gpio &> /dev/null; then
        green "wiringPi library is already installed."
        green "wiringPi库已经安装。"
        return 0
    fi

    # 安装 wiringPi 库
    git clone https://github.com/orangepi-xunlong/wiringOP.git

    cd wiringOP
    ./build clean
    ./build

    # 检查是否安装成功
    if ! gpio readall &> /dev/null; then
        red "wiringPi library installation failed. Please check the installation log."
        red "wiringPi库安装失败！请检查安装日志。"
        exit 1
    fi

    green "wiringPi library installation completed."
    green "wiringPi库安装完成。"

    #是否删除 wiringPi 安装文件夹（默认不删除）
    read -n 1 -r -p "是否删除wiringPi安装文件夹？[y/N] " input
    case $input in
        [yY][eE][sS]|[yY])
            green "删除wiringPi安装文件夹"
            cd ..
            rm -rf wiringOP
            ;;
        *)
            green "保留wiringPi安装文件夹"
            ;;
    esac
}

# 配置UART5\IIC3\SPI1
config_uart5_iic3_spi1() {
    local env_file="/boot/orangepiEnv.txt"

    green "Configuring UART5, IIC3, SPI1, PWM..."

    # 注意事项
    red "注意事项："
    red "1. UART5、IIC3 和 SPI1 此三个接口在5.16内核版本默认是关闭状态，要手动打开"
    red "2. 如果打开了 PWM1 和 PWM2，就不能同时打开 UART5，只能二选一。"
    red "3. 如果打开了 PWM3 和 PWM4，会同时关闭 UART0，此时调试串口就无法使用了。"
    red "4. 因主机的 PWM 在开发阶段毫无用处，所以本脚本不设置 PWM 通道的配置选项。"

    local overlays_line=$(grep '^overlays=' "$env_file")

    if [[ -z $overlays_line ]]; then
        yellow "目前还未配置任何接口"
    else
        if [[ $overlays_line == *"uart5"* ]]; then
            uart5_enabled="yes"
        else
            uart5_enabled="no"
        fi
        if [[ $overlays_line == *"i2c3"* ]]; then
            iic3_enabled="yes"
        else
            iic3_enabled="no"
        fi
        if [[ $overlays_line == *"spi-spidev"* ]]; then
            spi1_enabled="yes"
        else
            spi1_enabled="no"
        fi
    fi
    if [[ "$uart5_enabled" == "yes" || "$iic3_enabled" == "yes" || "$spi1_enabled" == "yes" ]]; then
        local overlays_config_current=""
        if [[ "$uart5_enabled" == "yes" ]]; then
            overlays_config_current+="UART5 "
        fi
        if [[ "$iic3_enabled" == "yes" ]]; then
            overlays_config_current+="IIC3 "
        fi
        if [[ "$spi1_enabled" == "yes" ]]; then
            overlays_config_current+="SPI1"
        fi
        blue "目前已配置了$overlays_config_current"
    fi

    # 是否打开UART5
    if [[ "$uart5_enabled" == "yes" ]]; then
        # UART5 已经在配置中，询问是否保持
        read -r -p "UART5已启用，是否保持？[Y/n] " uart5_input
        case ${uart5_input^^} in
            [nN][oO]|[nN])
                uart5_enabled="no"  # 用户选择不保持，设为关闭
                ;;
        esac
    else
        # UART5 当前未启用，询问是否开启
        read -r -p "是否启用 UART5？[Y/n] " uart5_input
        case ${uart5_input^^} in
            [nN][oO]|[nN])
                uart5_enabled="no"  # 用户选择不开启，保持关闭
                ;;
            *)
                uart5_enabled="yes"  # 用户选择开启
                ;;
        esac
    fi

    # 是否打开IIC3
    if [[ "$iic3_enabled" == "yes" ]]; then
        # IIC3 已经在配置中，询问是否保持
        read -r -p "IIC3已启用，是否保持？[Y/n] " iic3_input
        case ${iic3_input^^} in
            [nN][oO]|[nN])
                iic3_enabled="no"  # 用户选择不保持，设为关闭
                ;;
        esac
    else
        # IIC3 当前未启用，询问是否开启
        read -r -p "是否启用 IIC3？[Y/n] " iic3_input
        case ${iic3_input^^} in
            [nN][oO]|[nN])
                iic3_enabled="no"  # 用户选择不开启，保持关闭
                ;;
            *)
                iic3_enabled="yes"  # 用户选择开启
                ;;
        esac
    fi

    # 是否打开SPI1
    if [[ "$spi1_enabled" == "yes" ]]; then
        # SPI1 已经在配置中，询问是否保持
        read -r -p "SPI1已启用，是否保持？[Y/n] " spi1_input
        case ${spi1_input^^} in
            [nN][oO]|[nN])
                spi1_enabled="no"  # 用户选择不保持，设为关闭
                ;;
        esac
    else
        # SPI1 当前未启用，询问是否开启
        read -r -p "是否启用 SPI1？[Y/n] " spi1_input
        case ${spi1_input^^} in
            [nN][oO]|[nN])
                spi1_enabled="no"  # 用户选择不开启，保持关闭
                ;;
            *)
                spi1_enabled="yes"  # 用户选择开启
                ;;
        esac
    fi

    # 先删除原文件的配置
    local overlays_line=$(grep -E '^\s*overlays=' "$env_file")
    if [[ -n $overlays_line ]]; then
        sudo sed -i "/overlays=/d" "$env_file"
        green "删除原配置。。。"
    fi
    local spidev_line=$(grep '^\s*param_spidev_spi_bus=1' "$env_file")
    if [[ -n $spidev_line ]]; then
        sudo sed -i "/param_spidev_spi_bus=1/d" "$env_file"
    fi
    local spidev_line=$(grep '^\s*param_spidev_spi_cs=1' "$env_file")
    if [[ -n $spidev_line ]]; then
        sudo sed -i "/param_spidev_spi_cs=1/d" "$env_file"
    fi

    # 将相关设置添加到 env_file
    echo "" >> "$env_file"
    if [[ "$uart5_enabled" == "yes" || "$iic3_enabled" == "yes" || "$spi1_enabled" == "yes" ]]; then
        local overlays_config=""
        if [[ "$uart5_enabled" == "yes" ]]; then
            overlays_config+="uart5 "
        fi
        if [[ "$iic3_enabled" == "yes" ]]; then
            overlays_config+="i2c3 "
        fi
        if [[ "$spi1_enabled" == "yes" ]]; then
            overlays_config+="spi-spidev\n"
            overlays_config+="param_spidev_spi_bus=1\n"
            overlays_config+="param_spidev_spi_cs=1"
        fi

        echo -ne "overlays=$overlays_config" >> "$env_file"

        green "配置已完成并写入 $env_file ！"
    else
        green "已关闭所有设备，配置已完成并写入 $env_file ！"
    fi

    # 把文本里面是所有多余的空行删除
    sed -i '/^$/d' "$env_file"

    # 询问是否重启
    read -r -p "重启主机后生效，是否重启？[Y/n] " restart_input
    case ${restart_input^^} in
        [nN][oO]|[nN])
            ;;
        *)
            #sudo reboot
            ;;
    esac
}

# 安装并配置Samba
install_samba() {
    # 检查Samba是否已安装
    if command -v smbclient &> /dev/null; then
        echo "Samba 已安装。"
        # 检查smb.conf中是否已有OrangePi ZERO 2的共享配置
        if grep -q "\[OrangePi ZERO 2\]" /etc/samba/smb.conf; then
            echo "Samba 已配置 OrangePi ZERO 2 共享。无需重复配置。"
            return 1
        else
            echo "Samba 未配置 OrangePi ZERO 2 共享，将开始配置过程..."
        fi
    else
        echo "Samba 未安装，将开始安装过程..."
        # 安装Samba
        sudo apt update
        sudo apt install samba -y
    fi

    # 创建共享文件夹
    sudo mkdir -p ~/Share
    sudo chmod 0777 ~/Share

    # 备份原配置
    sudo cp /etc/samba/smb.conf /etc/samba/smb.conf.bak

    # 自动追加配置到 /etc/samba/smb.conf
    echo -e "\n[OrangePi ZERO 2]\n\
    comment=Samba\n\
    path = /home/orangepi/Share\n\
    public=yes\n\
    writable = yes\n\
    available = yes\n\
    browseable = yes\n\
    valid users = orangepi\n" | sudo tee -a /home/orangepi/smb.conf > /dev/null

    # 设置 Samba 用户密码
    echo -n "请输入 orangepi 的 Samba 密码: "
    read -s password  # 隐藏输入
    echo
    echo "$password" | sudo smbpasswd -s -a orangepi

    # 重启 Samba
    sudo systemctl restart smbd.service
    sudo systemctl enable smbd.service

    ip_address=$(hostname -I | awk '{print $1}')

    # 输出配置完成信息
    green "Samba 配置已完成！"
    green "OrangePi ZERO 2 共享路径：/home/orangepi/Share"
    green "用户名：orangepi"
    green "密码：$password"
    green "请在同一局域网的Windows系统中，使用文件资源管理器访问：\\\\\\$ip_address\\OrangePi\\ ZERO 2"
}

# 安装文件管理器
# 源自 https://filebrowser.org/installation
install_filemanager()
{
	trap 'echo -e "Aborted, error $? in command: $BASH_COMMAND"; trap ERR; return 1' ERR
	filemanager_os="unsupported"
	filemanager_arch="unknown"
	install_path="/usr/local/bin"

	# Termux on Android has $PREFIX set which already ends with /usr
	if [[ -n "$ANDROID_ROOT" && -n "$PREFIX" ]]; then
		install_path="$PREFIX/bin"
	fi

	# Fall back to /usr/bin if necessary
	if [[ ! -d $install_path ]]; then
		install_path="/usr/bin"
	fi

	# Not every platform has or needs sudo (https://termux.com/linux.html)
	((EUID)) && [[ -z "$ANDROID_ROOT" ]] && sudo_cmd="sudo"

	#########################
	# Which OS and version? #
	#########################

	filemanager_bin="filebrowser"
	filemanager_dl_ext=".tar.gz"

	# NOTE: `uname -m` is more accurate and universal than `arch`
	# See https://en.wikipedia.org/wiki/Uname
	unamem="$(uname -m)"
	case $unamem in
	*aarch64*)
		filemanager_arch="arm64";;
	*64*)
		filemanager_arch="amd64";;
	*86*)
		filemanager_arch="386";;
	*armv5*)
		filemanager_arch="armv5";;
	*armv6*)
		filemanager_arch="armv6";;
	*armv7*)
		filemanager_arch="armv7";;
	*)
		green "Aborted, unsupported or unknown architecture: $unamem"
		return 2
		;;
	esac

	unameu="$(tr '[:lower:]' '[:upper:]' <<<$(uname))"
	if [[ $unameu == *DARWIN* ]]; then
		filemanager_os="darwin"
	elif [[ $unameu == *LINUX* ]]; then
		filemanager_os="linux"
	elif [[ $unameu == *FREEBSD* ]]; then
		filemanager_os="freebsd"
	elif [[ $unameu == *NETBSD* ]]; then
		filemanager_os="netbsd"
	elif [[ $unameu == *OPENBSD* ]]; then
		filemanager_os="openbsd"
	elif [[ $unameu == *WIN* || $unameu == MSYS* ]]; then
		# Should catch cygwin
		sudo_cmd=""
		filemanager_os="windows"
		filemanager_bin="filebrowser.exe"
		filemanager_dl_ext=".zip"
	else
		green "Aborted, unsupported or unknown OS: $uname"
		return 6
	fi
	green "Downloading File Browser for $filemanager_os/$filemanager_arch..."
	if type -p curl >/dev/null 2>&1; then
		net_getter="curl -fsSL"
	elif type -p wget >/dev/null 2>&1; then
		net_getter="wget -qO-"
	else
		green "Aborted, could not find curl or wget"
		return 7
	fi
	filemanager_file="${filemanager_os}-$filemanager_arch-filebrowser$filemanager_dl_ext"
    filemanager_url="${proxy}https://github.com/filebrowser/filebrowser/releases/download/v2.28.0/$filemanager_file"
	echo "$filemanager_url"

	# Use $PREFIX for compatibility with Termux on Android
	rm -rf "$PREFIX/tmp/$filemanager_file"

	${net_getter} "$filemanager_url" > "$PREFIX/tmp/$filemanager_file"

	green "Extracting..."
	case "$filemanager_file" in
		*.zip)    unzip -o "$PREFIX/tmp/$filemanager_file" "$filemanager_bin" -d "$PREFIX/tmp/" ;;
		*.tar.gz) tar -xzf "$PREFIX/tmp/$filemanager_file" -C "$PREFIX/tmp/" "$filemanager_bin" ;;
	esac
	chmod +x "$PREFIX/tmp/$filemanager_bin"

	green "Putting filemanager in $install_path (may require password)"
	$sudo_cmd mv "$PREFIX/tmp/$filemanager_bin" "$install_path/$filemanager_bin"
	if setcap_cmd=$(PATH+=$PATH:/sbin type -p setcap); then
		$sudo_cmd $setcap_cmd cap_net_bind_service=+ep "$install_path/$filemanager_bin"
	fi
	$sudo_cmd rm -- "$PREFIX/tmp/$filemanager_file"

	if type -p $filemanager_bin >/dev/null 2>&1; then
		green "Successfully installed"
		trap ERR
		return 0
	else
		red "Something went wrong, File Browser is not in your path"
		trap ERR
		return 1
	fi
}

# 启动文件管理器
start_filemanager() {
    # 检查是否已经安装 filebrowser
    if ! command -v filebrowser &>/dev/null; then
        red "Error: filebrowser 未安装，请先安装 filebrowser"
        return 1
    fi

    # 启动 filebrowser 文件管理器
    echo "启动 filebrowser 文件管理器..."

    # 使用 nohup 和输出重定向，记录启动日志到 filebrowser.log 文件中
    nohup sudo filebrowser -r / --address 0.0.0.0 --port 8080 >filebrowser.log 2>&1 &

    # 检查 filebrowser 是否成功启动
    if [ $? -ne 0 ]; then
        red "Error: 启动 filebrowser 文件管理器失败"
        return 1
    fi
    local host_ip
    host_ip=$(hostname -I | awk '{print $1}')
    echo "filebrowser 文件管理器已启动，可以通过 http://${host_ip}:8080 访问"
    echo "登录用户名：admin"
    echo "默认密码：admin（请尽快修改密码）"
}

# 安装1panel面板
install_1panel_on_linux() {
    curl -sSL https://resource.fit2cloud.com/1panel/package/quick_start.sh -o quick_start.sh && sudo bash quick_start.sh
    intro="https://1panel.cn/docs/installation/cli/"
    if command -v 1pctl &>/dev/null; then
        green "如何卸载1panel 请参考：$intro"
    else
        red "未安装1panel"
    fi
}

# 查看1panel用户信息
read_user_info(){
    sudo 1pctl user-info
}

# 更新自己
update_scripts(){
    wget -O Pi.sh ${proxy}https://raw.githubusercontent.com/zhengxinyu13/OrangePiZero2Shell/main/OPi.sh && chmod +x Pi.sh
	echo "脚本已更新并保存在当前目录 Pi.sh,现在将执行新脚本。"
	./Pi.sh ${proxy}
	exit 0
}

show_menu() {
    clear
    greenline "————————————————————————————————————————————————————"
    echo '
    ***********  一键装机专辑脚本  ***************
         OrangePi ZERO 2 (内核版本5.16专用)
            脚本作用：快速装机，一键搞定
          --- Made by Grayson with YOU ---'
    echo -e "   https://github.com/zhengxinyu13/OrangePiZero2Shell"
    greenline "————————————————————————————————————————————————————"
    echo "请选择操作："

    # 特殊处理的项数组
    special_items=("")
    for i in "${!menu_options[@]}"; do
        if [[ " ${special_items[*]} " =~ " ${menu_options[i]} " ]]; then
            # 如果当前项在特殊处理项数组中，使用特殊颜色
            highlight "$((i + 1)). ${menu_options[i]}"
        else
            # 否则，使用普通格式
            echo "$((i + 1)). ${menu_options[i]}"
        fi
    done
}

handle_choice() {
    local choice=$1
    # 检查输入是否为空
    if [[ -z $choice ]]; then
        echo -e "${RED}输入不能为空，请重新选择。${NC}"
        return
    fi

    # 检查输入是否为数字
    if ! [[ $choice =~ ^[0-9]+$ ]]; then
        echo -e "${RED}请输入有效数字!${NC}"
        return
    fi

    # 检查数字是否在有效范围内
    if [[ $choice -lt 1 ]] || [[ $choice -gt ${#menu_options[@]} ]]; then
        echo -e "${RED}选项超出范围!${NC}"
        echo -e "${YELLOW}请输入 1 到 ${#menu_options[@]} 之间的数字。${NC}"
        return
    fi

    # 执行命令
    if [ -z "${commands[${menu_options[$choice - 1]}]}" ]; then
        echo -e "${RED}无效选项，请重新选择。${NC}"
        return
    fi

    "${commands[${menu_options[$choice - 1]}]}"
}

while true; do
    show_menu
    read -p "请输入选项的序号(输入q退出): " choice
    if [[ $choice == 'q' ]]; then
        break
    fi
    handle_choice $choice
    echo "按任意键继续..."
    read -n 1 # 等待用户按键
done