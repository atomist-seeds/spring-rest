FROM openjdk:9-slim

MAINTAINER David Dooling <david@atomist.com>

RUN mkdir -p /opt/app

WORKDIR /opt/app

EXPOSE 8080

CMD ["/usr/bin/java", "-Xmx512m", "-Djava.security.egd=file:/dev/urandom", "-jar", "spring-boot.jar"]

COPY . .

RUN ./mvnw -B package && cp target/*.jar spring-boot.jar && ./mvnw -B clean && rm -rf .mvn mvn* pom.xml src $HOME/.m2
