# Generated from pkg/pmux-gw-%{version}.gem by gem2rpm -*- rpm-spec -*-
%if %{_ruby_verid} == "default"
%define ruby_verid ""
%else
%define ruby_verid %{_ruby_verid}
%endif
%define rbname pmux-gw
%define version 0.1.12
%define release 1

Summary: Pmux gateway server
Name: rubygem%(echo -n %{ruby_verid})-%{rbname}

Version: %{version}
Release: %{release}
Group: Development/Ruby
License: Distributable
URL: https://github.com/iij/pmux-gw 
Source0: %{rbname}-%{version}.gem
Source1: %{rbname}
BuildRoot: %{_tmppath}/%{name}-%{version}-root
Requires: ruby 
Requires: rubygem%(echo -n %{ruby_verid})-gflocator
Requires: rubygem%(echo -n %{ruby_verid})-pmux
Requires: rubygem%(echo -n %{ruby_verid})-eventmachine => 1.0
Requires: rubygem%(echo -n %{ruby_verid})-eventmachine < 2
Requires: rubygem%(echo -n %{ruby_verid})-em_pessimistic >= 0.1.2
Requires: rubygem%(echo -n %{ruby_verid})-eventmachine_httpserver >= 0.2.1 
BuildRequires: ruby 
BuildArch: noarch
Provides: ruby(Pmux-gateway) = %{version}

%define gemdir  %(ruby%{ruby_verid} -rubygems -e 'puts Gem::dir' 2>/dev/null)
%define gembuilddir %{buildroot}%{gemdir}

%description
Pmux gateway is an executor for Pmux through HTTP request


%prep
%setup -T -c

%build

%install
%{__rm} -rf %{buildroot}
mkdir -p %{gembuilddir}
gem%{ruby_verid} install --local --install-dir %{gembuilddir} --force %{SOURCE0}
mkdir -p %{buildroot}/%{_bindir}
mv %{gembuilddir}/bin/* %{buildroot}/%{_bindir}
rmdir %{gembuilddir}/bin
mkdir -p %{buildroot}/etc/init.d
cp %{SOURCE1} %{buildroot}/etc/init.d/

%clean
%{__rm} -rf %{buildroot}

%files
%defattr(-, root, root)
%{_bindir}/pmux-gw
%{gemdir}/gems/%{rbname}-%{version}/
%attr(0755,root,root) /etc/init.d/%{rbname}

%doc %{gemdir}/doc/%{rbname}-%{version}
%{gemdir}/cache/%{rbname}-%{version}.gem
%{gemdir}/specifications/%{rbname}-%{version}.gemspec

%changelog
