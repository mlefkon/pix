FROM alpine:3.18

RUN apk add apache2 apache2-utils ffmpeg bash file
RUN echo "alias ll='ls -al'" >> /root/.ashrc
RUN echo "alias ll='ls -al'" > /etc/profile.d/aliases.sh && chmod 644 /etc/profile.d/aliases.sh

# Enable Apache modules as needed (e.g. headers_module, expires_module for cache control)
RUN sed -i 's/#LoadModule headers_module/LoadModule headers_module/' /etc/apache2/httpd.conf
RUN sed -i 's/#LoadModule expires_module/LoadModule expires_module/' /etc/apache2/httpd.conf

EXPOSE 80

# Create web root and config dir
RUN mkdir -p /www \
             /www/run \
             /etc/apache2/conf.d

COPY assets/etc-apache2-conf/pix.conf  /etc/apache2/conf.d/pix.conf
COPY assets/usr-local-bin/*            /usr/local/bin/

# Copy static assets (index.html etc.) into web root
COPY assets/www /www

# Ensure Apache can write generated files (e.g. /www/media-list.js)
# Apache in Alpine runs as user:group "apache:apache" so set ownership here.
RUN chown -R apache:apache /www

# Make entrypoint and helper scripts executable; also ensure CGI scripts are executable
RUN chmod +x \
    /usr/local/bin/* \
    /www/run/*

RUN echo "Apache Pix image built on $(date)" > /www/docker.build.info

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
