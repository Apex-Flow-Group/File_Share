# Packages a prebuilt Flutter Linux bundle; build it with build_rpm.sh.
Name:           apexsender
Version:        %{app_version}
Release:        %{app_build}%{?dist}
Summary:        Share files across devices on the local network
License:        MIT
URL:            https://github.com/Apex-Flow-Group
ExclusiveArch:  x86_64

# The bundle carries its own Flutter and plugin libraries: they are not
# system libraries, so rpm must neither require nor provide them.
%global __provides_exclude_from ^/opt/apexsender/.*$
%global __requires_exclude ^lib(flutter_linux_gtk|app|.*_plugin)\\.so.*$
%global debug_package %{nil}
%global __strip /bin/true

Requires:       gtk3

%description
Apex Sender sends files between phones, TVs and computers on the same network.

%install
mkdir -p %{buildroot}/opt/apexsender %{buildroot}%{_bindir}
cp -a %{bundle}/. %{buildroot}/opt/apexsender/
ln -s /opt/apexsender/file_share_app %{buildroot}%{_bindir}/apexsender
install -Dm644 %{pkgdir}/apexsender.desktop %{buildroot}%{_datadir}/applications/apexsender.desktop
install -Dm644 %{icon} %{buildroot}%{_datadir}/icons/hicolor/512x512/apps/apexsender.png
install -Dm644 %{pkgdir}/apexsender-firewalld.xml %{buildroot}%{_prefix}/lib/firewalld/services/apexsender.xml

%post
# Opens only the discovery port, by service name, so uninstall closes
# exactly what install opened. Skipped when firewalld is not running.
if [ $1 -eq 1 ] && firewall-cmd --state >/dev/null 2>&1; then
    firewall-cmd --reload >/dev/null 2>&1 || :
    firewall-cmd --permanent --add-service=apexsender >/dev/null 2>&1 || :
    firewall-cmd --reload >/dev/null 2>&1 || :
fi

%preun
if [ $1 -eq 0 ] && firewall-cmd --state >/dev/null 2>&1; then
    firewall-cmd --permanent --remove-service=apexsender >/dev/null 2>&1 || :
fi

%postun
if [ $1 -eq 0 ] && firewall-cmd --state >/dev/null 2>&1; then
    firewall-cmd --reload >/dev/null 2>&1 || :
fi

%files
/opt/apexsender
%{_bindir}/apexsender
%{_datadir}/applications/apexsender.desktop
%{_datadir}/icons/hicolor/512x512/apps/apexsender.png
%{_prefix}/lib/firewalld/services/apexsender.xml
%license /opt/apexsender/LICENSE
