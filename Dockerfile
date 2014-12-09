FROM phusion/baseimage:0.9.14
MAINTAINER Nathan Hopkins <natehop@gmail.com>
MAINTAINER Guillaume Dufour <guillaume.duff@gmail.com>

#RUN echo deb http://archive.ubuntu.com/ubuntu $(lsb_release -cs) main universe > /etc/apt/sources.list.d/universe.list
RUN apt-get -y update

# dependencies
RUN apt-get -y --force-yes install vim\
 nginx\
 python-dev\
 python-flup\
 python-pip\
 expect\
 git\
 memcached\
 sqlite3\
 libcairo2\
 libcairo2-dev\
 python-cairo\
 pkg-config\
 nodejs\
 libffi-dev\
 python-tox

 # we add python dependencies manually because requirements doesn't fix gunicorn version
RUN pip install Django>=1.4\
 Twisted==11.1.0\
 python-memcached==1.47\
 txAMQP==0.4\
 simplejson==2.1.6\
 django-tagging==0.3.1\
 gunicorn==19.1\
 pytz\
 pyparsing==1.5.7\
 cairocffi\
 git+git://github.com/graphite-project/whisper.git#egg=whisper\
 git+git://github.com/graphite-project/ceres.git#egg=ceres

# install graphite
RUN git clone https://github.com/graphite-project/graphite-web.git /usr/local/src/graphite-web/
WORKDIR /usr/local/src/graphite-web
# remove requirements because gunicorn tar 19.1.1 doen't compile on python 2.7
#RUN pip install -r requirements.txt
RUN python ./setup.py install
RUN cp /opt/graphite/webapp/graphite/local_settings.py.example /opt/graphite/webapp/graphite/local_settings.py

# install whisper
RUN git clone https://github.com/graphite-project/whisper.git /usr/local/src/whisper
WORKDIR /usr/local/src/whisper
RUN python ./setup.py install

# install carbon
RUN git clone https://github.com/graphite-project/carbon.git /usr/local/src/carbon
WORKDIR /usr/local/src/carbon
RUN python ./setup.py install

# config nginx
RUN rm /etc/nginx/sites-enabled/default
ADD conf/nginx/nginx.conf /etc/nginx/nginx.conf
ADD conf/nginx/graphite.conf /etc/nginx/sites-available/graphite.conf
RUN ln -s /etc/nginx/sites-available/graphite.conf /etc/nginx/sites-enabled/graphite.conf

# init django admin
ADD scripts/django_admin_init.exp /usr/local/bin/django_admin_init.exp
RUN /usr/local/bin/django_admin_init.exp

# logging support
RUN mkdir -p /var/log/carbon /var/log/graphite /var/log/nginx
ADD conf/logrotate /etc/logrotate.d/graphite

# daemons
ADD daemons/carbon.sh /etc/service/carbon/run
ADD daemons/graphite.sh /etc/service/graphite/run
ADD daemons/statsd.sh /etc/service/statsd/run
ADD daemons/nginx.sh /etc/service/nginx/run

# cleanup
RUN apt-get clean\
 && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# defaults
EXPOSE 8000:8000 80:80 2003:2003 8125:8125/udp
VOLUME ["/opt/graphite", "/etc/nginx", "/opt/statsd", "/etc/logrotate.d", "/var/log"]
ENV HOME /root
WORKDIR /usr/local/src/graphite-web
CMD ["tox -e py27-django17"]
