%define __os_install_post %{nil}
%define uek %( uname -r | egrep -i uek | wc -l | awk '{print $1}' )
%define rpm_arch %( uname -p )
%define rpm_author Jason W. Plummer
%define rpm_author_email vhsjwp01@gmail.com
%define distro_id %( lsb_release -is )
%define distro_ver %( lsb_release -rs )
%define distro_major_ver %( echo "%{distro_ver}" | awk -F'.' '{print $1}' )

Summary: a service to remotely display ZFS pool status
Name: zfsinfo
Release: 1.EL%{distro_major_ver}
License: GNU
Group: Storage/Tools
BuildRoot: %{_tmppath}/%{name}-root
URL: https://github.com/vhsjwp01/zfsinfo
Version: 1.0
BuildArch: noarch

# These BuildRequires can be found in Base
#BuildRequires: zlib, zlib-devel 

## This block handles Oracle Linux UEK .vs. EL BuildRequires
#%if %{uek}
#BuildRequires: kernel-uek-devel, kernel-uek-headers
#%else
#BuildRequires: kernel-devel, kernel-headers
#%endif

# These BuildRequires can be found in EPEL

# These BuildRequires can be found in ZFS on Linux

# These Requires can be found in Base
Requires: /usr/bin/perl
Requires: xinetd

# These Requires can be found in EPEL

# These Requires can be found in ZFS on Linux
Requires: zfs

%define install_base /usr/local
%define install_dir %{install_base}/sbin
%define xinetd_base /etc
%define xinetd_dir %{xinetd_base}/xinetd.d

Source0: ~/rpmbuild/SOURCES/zpool2json.pl
Source1: ~/rpmbuild/SOURCES/zfsinfo.xinetd

%description
ZFS Info is an xinet daemon that returns the output of
"zpool status -T d" in JSON format.  The service can be
queried on TCP port 49000

%install
printf "Source1 is: %{SOURCE1}"
rm -rf %{buildroot}
# Populate %{buildroot}
mkdir -p %{buildroot}%{install_dir}
mkdir -p %{buildroot}%{xinetd_dir}
cp %{SOURCE0} %{buildroot}%{install_dir}/zpool2json
cp %{SOURCE1} %{buildroot}%{xinetd_dir}/zfsinfo
# Build packaging manifest
rm -rf /tmp/MANIFEST.%{name}* > /dev/null 2>&1
echo '%defattr(-,root,root)' > /tmp/MANIFEST.%{name}
chown -R root:root %{buildroot} > /dev/null 2>&1
cd %{buildroot}
find . -depth -type d -exec chmod 755 {} \;
find . -depth -type f -exec chmod 644 {} \;
for i in `find . -depth -type f | sed -e 's/\ /zzqc/g'` ; do
    filename=`echo "${i}" | sed -e 's/zzqc/\ /g'`
    eval is_exe=`file "${filename}" | egrep -i "executable" | wc -l | awk '{print $1}'`
    if [ "${is_exe}" -gt 0 ]; then
        chmod 555 "${filename}"
    fi
done
find . -type f -or -type l | sed -e 's/\ /zzqc/' -e 's/^.//' -e '/^$/d' > /tmp/MANIFEST.%{name}.tmp
for i in `awk '{print $0}' /tmp/MANIFEST.%{name}.tmp` ; do
    filename=`echo "${i}" | sed -e 's/zzqc/\ /g'`
    dir=`dirname "${filename}"`
    echo "${dir}/*"
done | sort -u >> /tmp/MANIFEST.%{name}
# Clean up what we can now and allow overwrite later
rm -f /tmp/MANIFEST.%{name}.tmp
chmod 666 /tmp/MANIFEST.%{name}

%post
echo "zfsinfo         49000/tcp		# zfsinfo" >> /etc/services
chkconfig xinetd on
chkconfig zfsinfo on
service xinetd restart
exit 0

%preun
chkconfig zfsinfo off
service xinetd restart
exit 0

%postun
cp -p /etc/services /tmp/services.$$
egrep -v "zfsinfo" /tmp/services.$$ > /etc/services
rm /tmp/services.$$
exit 0

%files -f /tmp/MANIFEST.%{name}

%changelog
%define today %( date +%a" "%b" "%d" "%Y )
* %{today} %{rpm_author} <%{rpm_author_email}>
- built version %{version} for %{distro_id} %{distro_ver}

