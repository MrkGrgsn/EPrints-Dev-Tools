# Makefile for setting up EPrints dev instance
# Pre-reqs:
# 1. SELinux in permissive mode (or otherwise configured to allow
#    apache to write to the filesystem)

.PHONY: eprints-user, clean

PREFIX = /opt/eprints3
HOSTNAME = test1.eprints.local
USER = eprints
GROUP = eprints

install-dev: eprints-user
	yum install mysql mysql-server
	yum install perl-CPAN mod_perl mod_perl-devel libxml2-devel libxslt-devel
# Wants to do this as root which is crappy ...
#	cpan Bundle::CPAN 
#	cpan Log::Log4perl CGI Time::HiRes XML::LibXML XML:::LibXSLT Text::Lorem PerlIO::gzip cpan Config::General
	chkconfig mysqld on
	chkconfig httpd on

#$ bin/generate_views test1
#Subroutine parse_xml_string redefined at /opt/eprints3/bin/../perl_lib/EPrints/XML/DOM.pm line 119.
#Subroutine _parse_url redefined at /opt/eprints3/bin/../perl_lib/EPrints/XML/DOM.pm line 144.
#Subroutine parse_xml redefined at /opt/eprints3/bin/../perl_lib/EPrints/XML/DOM.pm line 164.
#Subroutine event_parse redefined at /opt/eprints3/bin/../perl_lib/EPrints/XML/DOM.pm line 211.
#Subroutine _dispose redefined at /opt/eprints3/bin/../perl_lib/EPrints/XML/DOM.pm line 248.
#Subroutine clone_and_own redefined at /opt/eprints3/bin/../perl_lib/EPrints/XML/DOM.pm line 261.
#Subroutine document_to_string redefined at /opt/eprints3/bin/../perl_lib/EPrints/XML/DOM.pm line 276.
#Subroutine make_document redefined at /opt/eprints3/bin/../perl_lib/EPrints/XML/DOM.pm line 286.
#Subroutine version redefined at /opt/eprints3/bin/../perl_lib/EPrints/XML/DOM.pm line 295.
#...
#Can't use an undefined value as an ARRAY reference at /opt/eprints3/bin/../perl_lib/XML/DOM/NamedNodeMap.pm line 136.

# solved by:
# cpan XML::LibXML XML:::LibXSLT

#Name "CGI::AutoloadClass" used only once: possible typo at /usr/local/share/perl5/CGI.pm line 286.
#Undefined phrase: eprint_fieldopt_thesis_type_phd (en) at line 126 in /opt/eprints3/bin/../perl_lib/EPrints/MetaField/Set.pm

# Clone EPrints from git
	git clone -b 3.3 https://MrkGrgsn@github.com/MrkGrgsn/eprints.git $(PREFIX)
	chown -R $(USER).$(GROUP) $(PREFIX)
	chmod -R g+rw $(PREFIX)/
	cd $(PREFIX)
	-git remote add upstream https://github.com/eprints/eprints.git

# create dummy EPrints::SystemSettings	

	sudo -u $(USER) cp $(PREFIX)/perl_lib/EPrints/SystemSettings.pm.in $(PREFIX)/perl_lib/EPrints/SystemSettings.pm
	sed -i 's/@INSTALL_USER@/$(USER)/' $(PREFIX)/perl_lib/EPrints/SystemSettings.pm
	sed -i 's/@INSTALL_GROUP@/$(GROUP)/' $(PREFIX)/perl_lib/EPrints/SystemSettings.pm
	sed -i 's/@SMTP_SERVER@/localhost/' $(PREFIX)/perl_lib/EPrints/SystemSettings.pm

# Setup EPrints indexer
	sudo -u $(USER) cp $(PREFIX)/bin/epindexer.in $(PREFIX)/bin/epindexer
	sed -i 's/@PERL_PATH@/\/usr\/bin\/perl/' $(PREFIX)/bin/epindexer
	sed -i 's/@INSTALL_USER@/$(USER)/' $(PREFIX)/bin/epindexer
	sed -i 's/@INSTALL_GROUP@/$(GROUP)/' $(PREFIX)/bin/epindexer
	sed -i 's/@PREFIX@/\/opt\/eprints3/' $(PREFIX)/bin/epindexer

	cp -s $(PREFIX)/bin/epindexer /etc/init.d/
	chkconfig --add epindexer
	chkconfig epindexer on
	/sbin/service epindexer start

# httpd config
	sudo -u $(USER) $(PREFIX)/bin/epadmin create
	cp -s $(PREFIX)/cfg/apache.conf /etc/httpd/conf.d/eprints.conf
	/sbin/service httpd restart

# add dev site to /etc/hosts
	echo "127.0.0.1 $(HOSTNAME)" | sudo tee -a /etc/hosts

	sudo -u $(USER) $(PREFIX)/testdata/bin/import_rand_data test1

config-git:

eprints-user:
	-groupadd $(GROUP)
	-useradd -r -g $(GROUP) $(USER)
	usermod -aG apache,$(GROUP) apache

clean:
	-rm /etc/httpd/conf.d/eprints.conf
	-/sbin/service epindexer stop
	-chkconfig --del epindexer 
	-rm /etc/init.d/epindexer
	-rm -rf $(PREFIX)
	userdel $(USER)
	groupdel $(GROUP)
	/sbin/service httpd restart
	echo 'DROP DATABASE eprints_test1' | mysql -u root
	echo 'DROP USER eprints_test1@localhost' | mysql -u root
	sed -i 's/127.0.0.1 $(HOSTNAME)//' /etc/hosts
