#!/bin/bash

NEXUS_ARTIFACT_REPO=$(cat /opt/config/nexus_artifact_repo.txt)
DEMO_ARTIFACTS_VERSION=$(cat /opt/config/demo_artifacts_version.txt)
if [[ "$DEMO_ARTIFACTS_VERSION" =~ "SNAPSHOT" ]]; then REPO=snapshots; else REPO=releases; fi
INSTALL_SCRIPT_VERSION=$(cat /opt/config/install_script_version.txt)
CLOUD_ENV=$(cat /opt/config/cloud_env.txt)

# Convert Network CIDR to Netmask
cdr2mask () {
	# Number of args to shift, 255..255, first non-255 byte, zeroes
	set -- $(( 5 - ($1 / 8) )) 255 255 255 255 $(( (255 << (8 - ($1 % 8))) & 255 )) 0 0 0
	[ $1 -gt 1 ] && shift $1 || shift
	echo ${1-0}.${2-0}.${3-0}.${4-0}
}

# OpenStack network configuration
if [[ $CLOUD_ENV == "openstack" ]]
then
	echo 127.0.0.1 $(hostname) >> /etc/hosts

	# Allow remote login as root
	mv /root/.ssh/authorized_keys /root/.ssh/authorized_keys.bk
	cp /home/ubuntu/.ssh/authorized_keys /root/.ssh

	MTU=$(/sbin/ifconfig | grep MTU | sed 's/.*MTU://' | sed 's/ .*//' | sort -n | head -1)

	IP=$(cat /opt/config/ip_to_dns_net.txt)
	BITS=$(cat /opt/config/vlb_private_net_cidr.txt | cut -d"/" -f2)
	NETMASK=$(cdr2mask $BITS)
	echo "auto eth1" >> /etc/network/interfaces
	echo "iface eth1 inet static" >> /etc/network/interfaces
	echo "    address $IP" >> /etc/network/interfaces
	echo "    netmask $NETMASK" >> /etc/network/interfaces
	echo "    mtu $MTU" >> /etc/network/interfaces

	IP=$(cat /opt/config/oam_private_ipaddr.txt)
	BITS=$(cat /opt/config/onap_private_net_cidr.txt | cut -d"/" -f2)
	NETMASK=$(cdr2mask $BITS)
	echo "auto eth2" >> /etc/network/interfaces
	echo "iface eth2 inet static" >> /etc/network/interfaces
	echo "    address $IP" >> /etc/network/interfaces
	echo "    netmask $NETMASK" >> /etc/network/interfaces
	echo "    mtu $MTU" >> /etc/network/interfaces

	IP=$(cat /opt/config/ip_to_pktgen_net.txt)
	BITS=$(cat /opt/config/pktgen_private_net_cidr.txt | cut -d"/" -f2)
	NETMASK=$(cdr2mask $BITS)
	echo "auto eth3" >> /etc/network/interfaces
	echo "iface eth3 inet static" >> /etc/network/interfaces
	echo "    address $IP" >> /etc/network/interfaces
	echo "    netmask $NETMASK" >> /etc/network/interfaces
	echo "    mtu $MTU" >> /etc/network/interfaces
fi

# Download required dependencies
echo "deb http://ppa.launchpad.net/openjdk-r/ppa/ubuntu $(lsb_release -c -s) main" >>  /etc/apt/sources.list.d/java.list
echo "deb-src http://ppa.launchpad.net/openjdk-r/ppa/ubuntu $(lsb_release -c -s) main" >>  /etc/apt/sources.list.d/java.list
apt-get update
apt-get install --allow-unauthenticated -y make gcc wget openjdk-8-jdk bridge-utils libcurl4-openssl-dev apt-transport-https ca-certificates git maven
sleep 1

# Install fd.io certificate
HOST=nexus.fd.io
PORT=443
TRUST_CERT_FILE="/etc/ssl/certs/ca-certificates.crt"
bash -c "echo -n | openssl s_client -showcerts -connect $HOST:$PORT 2>/dev/null | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' >> $TRUST_CERT_FILE"

# Download vLB demo code for load balancer
cd /opt
unzip -p -j /opt/vlbms-scripts-$INSTALL_SCRIPT_VERSION.zip v_lb_init.sh > /opt/v_lb_init.sh
unzip -p -j /opt/vlbms-scripts-$INSTALL_SCRIPT_VERSION.zip vlb.sh > /opt/vlb.sh
unzip -p -j /opt/vlbms-scripts-$INSTALL_SCRIPT_VERSION.zip add_dns.sh > /opt/add_dns.sh
unzip -p -j /opt/vlbms-scripts-$INSTALL_SCRIPT_VERSION.zip remove_dns.sh > /opt/remove_dns.sh
unzip -p -j /opt/vlbms-scripts-$INSTALL_SCRIPT_VERSION.zip properties.conf > /opt/config/properties.conf
unzip -p -j /opt/vlbms-scripts-$INSTALL_SCRIPT_VERSION.zip run_health.sh > /opt/run_health.sh
wget -O ves-$DEMO_ARTIFACTS_VERSION-demo.tar.gz "${NEXUS_ARTIFACT_REPO}/service/local/artifact/maven/redirect?r=${REPO}&g=org.onap.demo.vnf.ves5&a=ves&c=demo&e=tar.gz&v=$DEMO_ARTIFACTS_VERSION"
wget -O ves_vlb_reporting-$DEMO_ARTIFACTS_VERSION-demo.tar.gz "${NEXUS_ARTIFACT_REPO}/service/local/artifact/maven/redirect?r=${REPO}&g=org.onap.demo.vnf.ves5&a=ves_vlb_reporting&c=demo&e=tar.gz&v=$DEMO_ARTIFACTS_VERSION"

tar -zmxvf ves-$DEMO_ARTIFACTS_VERSION-demo.tar.gz
mv ves-$DEMO_ARTIFACTS_VERSION VES
tar -zmxvf ves_vlb_reporting-$DEMO_ARTIFACTS_VERSION-demo.tar.gz
mv ves_vlb_reporting-$DEMO_ARTIFACTS_VERSION VESreporting_vLB
mv VESreporting_vLB /opt/VES/evel/evel-library/code/VESreporting
cp /opt/VES/evel/evel-library/code/VESreporting/onap-ca.crt /opt/config/onap-ca.crt

# Download Honeycomb artifacts
wget -O vlb-vnf-onap-distribution-$DEMO_ARTIFACTS_VERSION-hc.tar.gz "${NEXUS_ARTIFACT_REPO}/service/local/artifact/maven/redirect?r=${REPO}&g=org.onap.demo.vnf&a=vlb-vnf-onap-distribution&c=hc&e=tar.gz&v=$DEMO_ARTIFACTS_VERSION"
tar -zmxvf vlb-vnf-onap-distribution-$DEMO_ARTIFACTS_VERSION-hc.tar.gz
mv vlb-vnf-onap-distribution-$DEMO_ARTIFACTS_VERSION honeycomb

sed -i 's/"restconf-binding-address": "127.0.0.1",/"restconf-binding-address": "0.0.0.0",/g' honeycomb/config/honeycomb.json
sed -i 's/"netconf-tcp-binding-address": "127.0.0.1",/"netconf-tcp-binding-address": "0.0.0.0",/g' honeycomb/config/honeycomb.json

rm *.tar.gz

chmod +x v_lb_init.sh
chmod +x vlb.sh
chmod +x /opt/VES/evel/evel-library/code/VESreporting/go-client.sh
chmod +x add_dns.sh
chmod +x remove_dns.sh
chmod +x run_health.sh

echo "vpp" > config/service.txt

# Install VPP
export UBUNTU="xenial"
export RELEASE=".stable.1707"
rm /etc/apt/sources.list.d/99fd.io.list
echo "deb [trusted=yes] https://nexus.fd.io/content/repositories/fd.io$RELEASE.ubuntu.$UBUNTU.main/ ./" | tee -a /etc/apt/sources.list.d/99fd.io.list
apt-get update
apt-get install -y vpp vpp-dpdk-dkms vpp-lib vpp-dbg vpp-plugins vpp-dev
sleep 1

# Install VES
cd /opt/VES/evel/evel-library/bldjobs/
make clean
make
sleep 1

# Run instantiation script
cd /opt
mv vlb.sh /etc/init.d
update-rc.d vlb.sh defaults

# Rename network interface in openstack Ubuntu 16.04 images. Then, reboot the VM to pick up changes
if [[ $CLOUD_ENV != "rackspace" ]]
then
	sed -i "s/GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX=\"net.ifnames=0 biosdevname=0\"/g" /etc/default/grub
	grub-mkconfig -o /boot/grub/grub.cfg
	sed -i "s/ens[0-9]*/eth0/g" /etc/network/interfaces.d/*.cfg
	sed -i "s/ens[0-9]*/eth0/g" /etc/udev/rules.d/70-persistent-net.rules
	echo 'network: {config: disabled}' >> /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
	echo "APT::Periodic::Unattended-Upgrade \"0\";" >> /etc/apt/apt.conf.d/10periodic
	reboot
fi

./v_lb_init.sh
