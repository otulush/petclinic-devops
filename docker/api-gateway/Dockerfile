FROM eclipse-temurin:17-jdk-jammy AS build
WORKDIR /workspace
COPY app/ .
RUN ./mvnw -B -pl spring-petclinic-api-gateway -am clean package -DskipTests -Dmaven.gitcommitid.skip=true

FROM eclipse-temurin:17-jre-jammy AS runtime

RUN addgroup --system spring && adduser --system --ingroup spring spring
RUN apt-get update && apt-get install -y --no-install-recommends curl && rm -rf /var/lib/apt/lists/*
ENV SPRING_PROFILES_ACTIVE=docker

ARG GIT_COMMIT_APP=unknown
ARG GIT_COMMIT_DEVOPS=unknown
ARG BUILD_DATE=unknown

LABEL org.opencontainers.image.revision=$GIT_COMMIT_APP
LABEL org.opencontainers.image.created=$BUILD_DATE
LABEL com.petclinic.devops.revision=$GIT_COMMIT_DEVOPS
LABEL org.opencontainers.image.source="https://github.com/spring-petclinic/spring-petclinic-microservices"

WORKDIR /app
USER spring:spring
COPY --from=build /workspace/spring-petclinic-api-gateway/target/*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]