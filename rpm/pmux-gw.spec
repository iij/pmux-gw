# Generated from pkg/pmux-gw-%{version}.gem by gem2rpm -*- rpm-spec -*-
%if %{_ruby_verid} == "default"
%define ruby_verid ""
%else
%define ruby_verid %{_ruby_verid}
%endif
%define rbname pmux-gw
%define version 0.1.2
%define release 1

Summary: Pmux gateway server
Name: rubygems%(echo -n %{ruby_verid})-%{rbname}

Version: %{version}
Release: %{release}
Group: Development/Ruby
License: Distributable
URL: https://github.com/iij/pmux-gw 
Source0: %{rbname}-%{version}.gem
BuildRoot: %{_tmppath}/%{name}-%{version}-root
Requires: ruby 
Requires: rubygems%(echo -n %{ruby_verid}) >= 1.3.7
Requires: rubygems%(echo -n %{ruby_verid})-gflocator  >= 0.0.1
Requires: rubygems%(echo -n %{ruby_verid})-pmux >= 0.1.0
Requires: rubygems%(echo -n %{ruby_verid})-eventmachine => 1.0
Requires: rubygems%(echo -n %{ruby_verid})-eventmachine < 2
Requires: rubygems%(echo -n %{ruby_verid})-em_pessimistic >= 0.1.2
Requires: rubygems%(echo -n %{ruby_verid})-eventmachine_httpserver > 0.2.1 
BuildRequires: ruby 
BuildRequires: rubygems%(echo -n %{ruby_verid}) >= 1.3.7
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

%clean
%{__rm} -rf %{buildroot}

%files
%defattr(-, root, root)
%{_bindir}/pmux-gw
%{gemdir}/gems/%{rbname}-%{version}/Gemfile
%{gemdir}/gems/%{rbname}-%{version}/Makefile
%{gemdir}/gems/%{rbname}-%{version}/LICENSE.txt
%{gemdir}/gems/%{rbname}-%{version}/README.md
%{gemdir}/gems/%{rbname}-%{version}/Rakefile
%{gemdir}/gems/%{rbname}-%{version}/pmux-gw.gemspec
%{gemdir}/gems/%{rbname}-%{version}/bin/pmux-gw
%{gemdir}/gems/%{rbname}-%{version}/lib/pmux-gw.rb
%{gemdir}/gems/%{rbname}-%{version}/lib/pmux-gw/http_handler.rb
%{gemdir}/gems/%{rbname}-%{version}/lib/pmux-gw/pmux_handler.rb
%{gemdir}/gems/%{rbname}-%{version}/lib/pmux-gw/template/history.tmpl
%{gemdir}/gems/%{rbname}-%{version}/lib/pmux-gw/client_context.rb
%{gemdir}/gems/%{rbname}-%{version}/lib/pmux-gw/application.rb
%{gemdir}/gems/%{rbname}-%{version}/lib/pmux-gw/version.rb
%{gemdir}/gems/%{rbname}-%{version}/lib/pmux-gw/history.rb
%{gemdir}/gems/%{rbname}-%{version}/lib/pmux-gw/static/css/jquery-ui-1.9.2.custom.css
%{gemdir}/gems/%{rbname}-%{version}/lib/pmux-gw/static/css/images/ui-bg_glass_65_ffffff_1x400.png
%{gemdir}/gems/%{rbname}-%{version}/lib/pmux-gw/static/css/images/ui-icons_cd0a0a_256x240.png
%{gemdir}/gems/%{rbname}-%{version}/lib/pmux-gw/static/css/images/ui-bg_glass_55_fbf9ee_1x400.png
%{gemdir}/gems/%{rbname}-%{version}/lib/pmux-gw/static/css/images/ui-icons_2e83ff_256x240.png
%{gemdir}/gems/%{rbname}-%{version}/lib/pmux-gw/static/css/images/ui-icons_222222_256x240.png
%{gemdir}/gems/%{rbname}-%{version}/lib/pmux-gw/static/css/images/ui-bg_glass_75_dadada_1x400.png
%{gemdir}/gems/%{rbname}-%{version}/lib/pmux-gw/static/css/images/ui-icons_454545_256x240.png
%{gemdir}/gems/%{rbname}-%{version}/lib/pmux-gw/static/css/images/ui-bg_glass_75_e6e6e6_1x400.png
%{gemdir}/gems/%{rbname}-%{version}/lib/pmux-gw/static/css/images/ui-icons_888888_256x240.png
%{gemdir}/gems/%{rbname}-%{version}/lib/pmux-gw/static/css/images/ui-bg_flat_0_aaaaaa_40x100.png
%{gemdir}/gems/%{rbname}-%{version}/lib/pmux-gw/static/css/images/ui-bg_flat_75_ffffff_40x100.png
%{gemdir}/gems/%{rbname}-%{version}/lib/pmux-gw/static/css/images/ui-bg_highlight-soft_75_cccccc_1x100.png
%{gemdir}/gems/%{rbname}-%{version}/lib/pmux-gw/static/css/images/ui-bg_glass_95_fef1ec_1x400.png
%{gemdir}/gems/%{rbname}-%{version}/lib/pmux-gw/static/js/jquery-1.8.3.js
%{gemdir}/gems/%{rbname}-%{version}/lib/pmux-gw/static/js/jquery-ui-1.9.2.custom.js
%{gemdir}/gems/%{rbname}-%{version}/lib/pmux-gw/logger_wrapper.rb
%{gemdir}/gems/%{rbname}-%{version}/lib/pmux-gw/syslog_wrapper.rb
%{gemdir}/gems/%{rbname}-%{version}/examples/pmux-gw.conf
%{gemdir}/gems/%{rbname}-%{version}/examples/password
%{gemdir}/gems/%{rbname}-%{version}/rpm/pmux-gw.spec
%{gemdir}/gems/%{rbname}-%{version}/rpm/Makefile

%doc %{gemdir}/doc/%{rbname}-%{version}
%{gemdir}/cache/%{rbname}-%{version}.gem
%{gemdir}/specifications/%{rbname}-%{version}.gemspec

%changelog
