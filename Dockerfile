FROM        perl:latest
MAINTAINER  Mike Greb michael@thegrebs.com

RUN curl -L http://cpanmin.us | perl - App::cpanminus
RUN cpanm -n Starman Mojolicious DateTime Chart::Clicker Data::Printer DBD::SQLite

EXPOSE 8080

ADD . /SolarNG
WORKDIR /SolarNG

CMD exec starman --port 8080 script/solar_ng
