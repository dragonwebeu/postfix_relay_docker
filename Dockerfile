#FROM debian:buster
FROM debian:bookworm

# Fix for installing postfix getting stuck
RUN set -x \
  && echo mail > /etc/hostname \
  && echo "postfix postfix/main_mailer_type string Internet site" >> preseed.txt \
  && echo "postfix postfix/mailname string mail.example.com" >> preseed.txt \
  && debconf-set-selections preseed.txt && rm preseed.txt \
  ;

# # Set the locale
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y locales \
    && sed -i -e 's/# en_GB.UTF-8 UTF-8/en_GB.UTF-8 UTF-8/' /etc/locale.gen \
    && dpkg-reconfigure --frontend=noninteractive locales \
    && update-locale LANG=en_GB.UTF-8
ENV LANG en_GB.UTF-8 
ENV LC_ALL en_GB.UTF-8

# Install packages
RUN set -x \
  && apt-get update \
  && apt-get install -y --no-install-recommends postfix mailutils opendkim opendkim-tools nano less cron syslog-ng logrotate libsasl2-modules sasl2-bin curl ca-certificates procps pflogsumm \
  && apt-get clean \
  && rm -f /etc/opendkim.conf \
  && usermod -G opendkim postfix \  
  && mkdir -p /etc/opendkim/keys \
  && chown -R opendkim:opendkim /etc/opendkim && chmod 744 /etc/opendkim/keys \
  ;

COPY build/crontab/default_crontab postfix_crontabs_default
# If you have other countries add them here like that and update run.sh
# COPY crontab/crontab_other postfix_crontab_other

# Postfix
COPY build/postfix/main.cf /etc/postfix/main.cf
#COPY postfix/master.cf /etc/postfix/master.cf

# DKIM
COPY build/dkim/DKIM_opendkim.conf /etc/opendkim.conf
COPY build/dkim/DKIM_opendkim /etc/default/opendkim

COPY build/run.sh /
ENTRYPOINT ["/run.sh"]
# Start postfix in foreground mode
CMD ["postfix", "start-fg"]

