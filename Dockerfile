FROM centos:7
MAINTAINER Daniiar Abdraimov (doabdraimov@gmail.com)

ENV TZ=Asia/Bishkek
ENV LIBFIXBUF_VERSION=2.4.0
ENV NETSA_PYTHON_VERSION=1.5
ENV IPA_VERSION=0.5.2
ENV SILK_VERSION=3.19.1
ENV FLOWVIEWER_VERSION=4.6

WORKDIR /root/

# ========= Set Timezone ==============
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# ========= Installing Dependencies ==============
RUN yum update -y && yum install -y  epel-release && yum groupinstall -y "development tools" \
    && yum install -y gcc zlib zlib-devel lzo lzo-devel libpcap gnutls gnutls-devel \
                      python2-devel python3-devel c-ares c-ares-devel openssl-devel \
                      glibc-devel glib2-devel wget rrdtool-perl psmisc mod_perl \
                      "perl(Pod::Html)" "perl(GD::Text)" "perl(Encode::HanExtra)" \
                      "perl(GD::Graph)" httpd httpd-tools gd perl-GD rrdtool libmaxminddb libmaxminddb-devel 


# ========= Download Silk Dependencies ==============
RUN wget https://tools.netsa.cert.org/releases/libfixbuf-$LIBFIXBUF_VERSION.tar.gz \
         https://tools.netsa.cert.org/releases/netsa-python-$NETSA_PYTHON_VERSION.tar.gz \
	 https://tools.netsa.cert.org/releases/ipa-$IPA_VERSION.tar.gz \
	 https://tools.netsa.cert.org/releases/silk-$SILK_VERSION.tar.gz


# # ============ Installing Silk Dependencies ===============
RUN tar zxvf libfixbuf-$LIBFIXBUF_VERSION.tar.gz && cd libfixbuf-$LIBFIXBUF_VERSION  \
    && ./configure && make && make install \
    && cd ..

RUN tar zxvf netsa-python-$NETSA_PYTHON_VERSION.tar.gz && cd netsa-python-$NETSA_PYTHON_VERSION \
    && python2 setup.py build && python2 setup.py install \
    && cd ..

RUN tar zxvf ipa-$IPA_VERSION.tar.gz && cd ipa-$IPA_VERSION \
    && ./configure && make && make install \
    && cd ..

RUN echo /usr/local/lib >>/etc/ld.so.conf.d/local.conf && ldconfig -v

RUN tar zxvf silk-$SILK_VERSION.tar.gz && cd silk-$SILK_VERSION \
    && ./configure --enable-data-rootdir=/data/flows \
                   --prefix=/opt/silk \
                   --enable-output-compression \
                   --with-libipa=/usr/local/lib/pkgconfig \
                   --with-libfixbuf=/usr/local/lib/pkgconfig \
                   --enable-localtime \
                   --enable-ipv6 \
                   --with-python=/bin/python3 \
    && make && make install \
    && cd .. 

# ============ Coppy Geo IP Lite File =================
COPY ./GeoLite2-Country-CSV_20200929.zip GeoLite2-Country-CSV_20200929.zip

RUN mkdir -p /opt/silk/etc/ /data/flows/ \
    && /opt/silk/bin/rwpmapbuild --input /opt/silk/share/silk/addrtype-templ.txt --output address_types.pmap \
    && unzip  GeoLite2-Country-CSV_20200929.zip \
    && /opt/silk/bin/rwgeoip2ccmap --input-path=GeoLite2-Country-CSV_20200929/ --output-path=country_codes.pmap \
    && cp country_codes.pmap /opt/silk/share/silk/country_codes.pmap

RUN rm -fr * && yum clean all

# ============ Installing FlowViewer files =================
RUN wget -P /var/www/cgi-bin/ https://netix.dl.sourceforge.net/project/flowviewer/FlowViewer_$FLOWVIEWER_VERSION.tar \
    && tar -C /var/www/cgi-bin/ -xvf /var/www/cgi-bin/FlowViewer_$FLOWVIEWER_VERSION.tar && rm -fr /var/www/cgi-bin/FlowViewer_$FLOWVIEWER_VERSION.tar \
    && mkdir -p /var/www/html/FlowViewer /var/www/html/FlowGrapher /var/www/html/FlowMonitor /var/www/cgi-bin/FlowMonitor_Files/ /var/www/cgi-bin/FlowMonitor_Files/FlowMonitor_Filters /var/www/cgi-bin/FlowMonitor_RRDtool/ \
    && cp /var/www/cgi-bin/FlowViewer_$FLOWVIEWER_VERSION/FV_button.png /var/www/cgi-bin/FlowViewer_$FLOWVIEWER_VERSION/FM_button.png /var/www/cgi-bin/FlowViewer_$FLOWVIEWER_VERSION/FG_button.png /var/www/cgi-bin/FlowViewer_$FLOWVIEWER_VERSION/FlowViewer.css /var/www/html/FlowViewer/ 
    

COPY ./*conf /opt/silk/etc/
COPY ./FlowViewer_Configuration.pm /var/www/cgi-bin/FlowViewer_$FLOWVIEWER_VERSION/

# ============ FlowViewer Documentation =================
COPY ./FlowViewer.pdf /var/www/html/FlowViewer/

COPY scripts/startup.sh          startup.sh
COPY scripts/start_httpd.sh      start_httpd.sh
COPY scripts/start_rwflowpack.sh start_rwflowpack.sh
COPY scripts/start_flowviewer.sh start_flowviewer.sh

RUN chmod +x *sh && chmod 775 -R /var/www/cgi-bin/FlowViewer_$FLOWVIEWER_VERSION && chown -R apache:apache /var/www/ 

EXPOSE 80
EXPOSE 22055/udp

CMD ./startup.sh
