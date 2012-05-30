Name: check_mk
Version: 1.2.0b5
Release: 2%{?dist}
Summary: check_mk suite of tools for Nagios environment
Group: Applications/Utilities
License: GPL
Url: http://mathias-kettner.de/check_mk.html
Source0: %{_sourcedir}/%{name}-%{version}.tar.gz
Source1: %{_sourcedir}/livestatus.xinetd
Packager: Daniel Wittenberg
Vendor: Mathias Kettner
Autoreq: 0
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)

%description
Check_mk adopts a new a approach for collecting data from operating systems and network components. It obsoletes NRPE, check_by_ssh, NSClient and check_snmp


%package livestatus
Group: Applications/Utilities
Summary: livestatus Nagios Event Broker

%description livestatus
Check_MK offers a completely new approach for accessing status and also historic data: Livestatus. Just as NDO, Livestatus make use of the Nagios Event Broker API and loads a binary module into your Nagios process. But other then NDO, Livestatus does not actively write out data. Instead, it opens a socket by which data can be retrieved on demand. 

%package multisite
Group: Applications/Utilities
Summary: Check_mk multisite web GUI
Requires: check_mk, httpd, mod_python, python

%description multisite
Check_MK Multisite Web GUI

%prep
%setup -q -n %{name}-%{version}

%build
echo "bindir='/usr/bin/'
confdir='/etc/check_mk/'
sharedir='/usr/share/check_mk/'
docdir='%{_docdir}/%{name}-%{version}'
checkmandir='%{_docdir}/%{name}-%{version}/checks'
vardir='/var/lib/check_mk/'
agentslibdir='/usr/lib/check_mk_agent'
agentsconfdir='/etc/check_mk'
nagiosuser='nagios'
wwwuser='apache'
wwwgroup='nagios'
nagios_binary='/usr/bin/nagios'
nagios_config_file='/etc/nagios/nagios.cfg'
nagconfdir='/etc/nagios/objects/'
nagios_startscript='%{_sysconfdir}/init.d/nagios'
nagpipe='/var/nagios/rw/nagios.cmd'
check_result_path='/var/nagios/ramcache/checkresults'
nagios_status_file='/var/nagios/ramcache/status.dat'
check_icmp_path='%{_libdir}/nagios/plugins/check_icmp'
url_prefix='/'
apache_config_dir='/etc/httpd/conf.d'
htpasswd_file='/etc/nagios/htpasswd.users'
nagios_auth_name='Nagios Access'
pnptemplates='/usr/share/nagios/html/pnp4nagios/templates'
enable_livestatus='yes'
libdir='/usr/lib/check_mk'
livesock='/var/nagios/rw/live'
livebackendsdir='/usr/share/check_mk/livestatus'
" > $HOME/.check_mk_setup.conf

%install
%__rm -rf %{buildroot}

%__mkdir_p -m 0755 %{buildroot}/etc/xinetd.d/
%__install -m 0644 %{SOURCE1} %{buildroot}/etc/xinetd.d/livestatus
%__mkdir_p -m 0755 %{buildroot}/%{_docdir}/%{name}-%{version}/
%__mkdir_p -m 0755 %{buildroot}/%{_docdir}/%{name}-%{version}-livestatus/
%__install -m 0644 AUTHORS %{buildroot}/%{_docdir}/%{name}-%{version}/
%__install -m 0644 COPYING %{buildroot}/%{_docdir}/%{name}-%{version}/
%__install -m 0644 ChangeLog %{buildroot}/%{_docdir}/%{name}-%{version}/
%__install -m 0644 VERSION %{buildroot}/%{_docdir}/%{name}-%{version}/

DESTDIR=%{buildroot}/ ./setup.sh --yes

%__mkdir_p -m 755 %{buildroot}/etc/httpd/conf.d/
%__mv %{buildroot}/etc/apache2/conf.d/zzz_check_mk.conf %{buildroot}/etc/httpd/conf.d/
rm -rf %{buildroot}/etc/apache2/
%__mkdir_p -m 755 %{buildroot}/%{_docdir}/%{name}-%{version}
%__cp -a %{buildroot}/usr/share/doc/check_mk/* %{buildroot}/%{_docdir}/%{name}-%{version}/
rm -rf %{buildroot}/usr/share/doc/check_mk/
%__mv -f %{buildroot}/%{_docdir}/%{name}-%{version}/livestatus/* %{buildroot}/%{_docdir}/%{name}-%{version}-livestatus/
%__mkdir_p -m 755 %{buildroot}/usr/share/check_mk/livestatus/

%clean
#%__rm -rf %{buildroot}


%pre
# $1 = 1 operation is an initial installation
# $1 = 2 operation is an upgrade from an existing version to a new one

%post
# $1 = 0 operation is an uninstallation
# $1 = 1 operation is an upgrade

%preun
# $1 = 0 operation is an uninstallation
# $1 = 1 operation is an upgrade

%postun
# $1 = 0 operation is an uninstallation
# $1 = 1 operation is an upgrade

%files
%defattr(-,root,root)
%attr(0755,root,root) %dir /usr/share/check_mk/
%attr(0755,root,root) /usr/share/check_mk/*
%attr(0755,root,root) /usr/bin/check_mk
%attr(0755,root,root) /usr/bin/cmk
%attr(0755,root,root) /usr/bin/mkp

%attr(0644,root,root) %config(noreplace)  /etc/nagios/objects/check_mk_templates.cfg

%attr(0755,root,root) %{_docdir}/%{name}-%{version}/*
%attr(0755,root,root) %dir /var/lib/check_mk/packages
%attr(0644,root,root) /var/lib/check_mk/packages/check_mk

%files livestatus
%attr(0755,root,root) %dir %{_docdir}/%{name}-%{version}/livestatus/
%attr(0755,root,root) %{_docdir}/%{name}-%{version}-livestatus/*
%attr(0755,root,root) %dir /usr/share/check_mk/
%attr(0755,root,root) %dir /usr/lib/check_mk/
%attr(0755,root,root) /usr/lib/check_mk/*
%attr(0755,root,root) /usr/bin/unixcat
%attr(0644,root,root) /etc/xinetd.d/livestatus

%files multisite
%attr(0644,root,root) %config(noreplace) /etc/httpd/conf.d/zzz_check_mk.conf
%attr(0755,root,root) %dir /etc/check_mk/
%attr(0755,root,root) %dir /etc/check_mk/conf.d
%attr(0755,root,root) %dir /etc/check_mk/multisite.d
%attr(0644,root,root) /etc/check_mk/conf.d/README
%attr(0644,root,root) /etc/check_mk/main.mk-%{version}
%attr(0644,root,root) /etc/check_mk/multisite.mk-%{version}
%attr(0644,root,root) %config(noreplace) /etc/check_mk/multisite.mk
%attr(0644,root,root) %config(noreplace) /etc/check_mk/main.mk


%changelog
* Mon May 28 2012 Daniel Wittenberg <dwittenberg2008@gmail.com> 1.2.0b5
- Updated to latest release
- Use more LSB paths instead of /opt/check_mk

* Thu May 3 2012 Daniel Wittenberg <dwittenberg2008@gmail.com> 1.2.0b3
- Initial RPM build


