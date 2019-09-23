#!/bin/bash

function main
{
    echo "Checking for updates.."
    sleep 2
    apt-get update
    apt-get dist-upgrade -y
    echo "Installing dependencies..."
    sleep 3
    apt-get install -y build-essential cmake bison flex libpcap-dev pkg-config libglib2.0-dev libgpgme11-dev uuid-dev \
sqlfairy xmltoman doxygen libssh-dev libksba-dev libldap2-dev \
libsqlite3-dev libmicrohttpd-dev libxml2-dev libxslt1-dev \
xsltproc clang rsync rpm nsis alien sqlite3 libhiredis-dev libgcrypt11-dev libgnutls28-dev redis-server \
tex-gyre texlive-fonts-recommended texlive-latex-extra texlive-latex-recommended texlive-pictures texlive-latex-base python3 gnutls-bin

    # Make temporary directory to d/l source, extract and compile
    echo "Now installing openVAS, please wait..."
    sleep 3
    mkdir openvas
    cd openvas

    # Download Source
    wget https://github.com/greenbone/gvm-libs/releases/download/v9.0.3/openvas-libraries-9.0.3.tar.gz
    wget -O openvas-scanner-5.1.3.tar.gz https://github.com/greenbone/openvas-scanner/archive/v5.1.3.tar.gz
    wget https://github.com/greenbone/gvmd/releases/download/v7.0.3/openvas-manager-7.0.3.tar.gz
    wget -O gsa-7.0.3.tar.gz https://github.com/greenbone/gsa/archive/v7.0.3.tar.gz
    wget http://wald.intevation.org/frs/download.php/2397/openvas-cli-1.4.5.tar.gz
    wget http://nmap.org/dist-old/nmap-5.51.6.tgz

    # Extract packages and remove them.
    tar xvf gsa-7.0.3.tar.gz
    tar xvf openvas-libraries-9.0.3.tar.gz
    tar xvf openvas-scanner-5.1.3.tar.gz
    tar xvf openvas-manager-7.0.3.tar.gz
    tar xvf openvas-cli-1.4.5.tar.gz
    tar xvf nmap-5.51.6.tgz
    rm gsa-7.0.3.tar.gz \
    openvas-libraries-9.0.3.tar.gz \
    openvas-scanner-5.1.3.tar.gz \
    openvas-manager-7.0.3.tar.gz \
    openvas-cli-1.4.5.tar.gz \
    nmap-5.51.6.tgz

    # Compile and install packages
    cd gvm-libs-9.0.3/
    cmake .
    make
    make doc
    make install
    cd ..
    cd gvm-7.0.3/
    cmake .
    make
    make doc
    make install
    cd ..
    cd openvas-scanner-5.1.3/
    cmake .
    make
    make doc
    make install
    cd ..
    cd gsa-7.0.3/
    cmake .
    make
    make doc
    make install
    cd ..
    cd openvas-cli-1.4.5/
    cmake .
    make
    make doc
    make install
    cd ..
    cd nmap-5.51.6/
    ./configure
    make
    make install
    cd ..
    ldconfig

    # Setup openVAS stuff
    echo "Now setting up openVAS databases, please wait..."
    sleep 5
    initsetup
    openvasmd --user=openvas --new-password=vagrant
    cd ..
    # Add (optional) sync script
    cat > openvas_feedupdate.bash <<EOF
#!/bin/bash
echo "Updating OpenVas Feeds"
greenbone-nvt-sync
greenbone-scapdata-sync
greenbone-certdata-sync
openvasmd --progress --rebuild
EOF
	chmod +x update_openvas.bash
    services
    echo "Installation Complete."
}

function initsetup
{
    if ! grep -q "^unixsocket /tmp/redis.sock" /etc/redis/redis.conf ; then
        sed -i -e 's/^\(#.\)\?port.*$/port 0/' /etc/redis/redis.conf
        sed -i -e 's/^\(#.\)\?unixsocket \/.*$/unixsocket \/tmp\/redis.sock/' /etc/redis/redis.conf
        sed -i -e 's/^\(#.\)\?unixsocketperm.*$/unixsocketperm 700/' /etc/redis/redis.conf
    fi

    service redis-server restart

    greenbone-nvt-sync
    greenbone-scapdata-sync
    greenbone-certdata-sync
    openvas-manage-certs -a
    openvassd
    openvasmd --progress --rebuild

    openvassd
    openvasmd
    gsad

    openvasmd --create-user=openvas --role=Admin
}

function services
{
    # Create the autostart services
    echo "Creating system services... please wait"
    sleep 3
    cat > /etc/systemd/system/openvas-manager.service <<EOF
[Unit]
Description=Open Vulnerability Assessment System Manager Daemon
Documentation=man:openvasmd(9) http://www.openvas.org/
Wants=openvas-scanner.service

[Service]
Type=forking
PIDFile=/usr/local/var/run/openvasmd.pid
ExecStart=/usr/local/sbin/openvasmd --database=/usr/local/var/lib/openvas/mgr/tasks.db

ExecReload=/bin/kill -HUP $MAINPID
# Kill the main process with SIGTERM and after TimeoutStopSec (defaults to
# 1m30) kill remaining processes with SIGKILL
KillMode=mixed

[Install]
WantedBy=multi-user.target
EOF
	cat > /etc/systemd/system/openvas-scanner.service <<EOF
[Unit]
Description=Open Vulnerability Assessment System Scanner Daemon
Documentation=man:openvassd(9) http://www.openvas.org/
After=redis-server.service
Requires=redis-server.service

[Install]
WantedBy=multi-user.target

[Service]
Type=forking
PIDFile=/usr/local/var/run/openvassd.pid
ExecStart=/usr/local/sbin/openvassd
ExecReload=/bin/kill -HUP $MAINPID
# Kill the main process with SIGTERM and after TimeoutStopSec (defaults to
# 1m30) kill remaining processes with SIGKILL
KillMode=mixed
EOF
    cat > /etc/systemd/system/greenbone-security-assistant.service <<EOF
[Unit]
Description=Greenbone Security Assistant
Documentation=man:gsad(9) http://www.openvas.org/
Wants=openvas-manager.service

[Service]
Type=simple
PIDFile=/usr/local/var/run/gsad.pid
ExecStart=/usr/local/sbin/gsad --foreground

[Install]
WantedBy=multi-user.target
EOF
    chmod +x /etc/systemd/system/openvas-manager.service
    chmod +x /etc/systemd/system/openvas-scanner.service
    chmod +x /etc/systemd/system/greenbone-security-assistant.service
    systemctl enable openvas-manager.service
    systemctl enable openvas-scanner.service
    systemctl enable greenbone-security-assistant.service
    echo "Verifying integrity..."
    sleep 3
    killall -9 gsad
    killall -9 openvassd
    killall -9 openvasmd
    systemctl start openvas-manager.service
    systemctl start openvas-scanner.service
    systemctl start greenbone-security-assistant.service
}

if [ "$(id -u)" != "0" ]; then
    echo "This script is not being run as root. Please execute this script with root privileges by running 'sudo ./openVAS.bash'"
    exit
else
    main
fi
