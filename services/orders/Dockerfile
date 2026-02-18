FROM eclipse-temurin:21-jdk-alpine AS build

WORKDIR /app

# Copiar archivos de Maven
COPY mvnw .
COPY .mvn .mvn
COPY pom.xml .

# Descargar dependencias
RUN ./mvnw dependency:go-offline -B

# Copiar código fuente
COPY src src

# Compilar aplicación
RUN ./mvnw clean package -DskipTests

# Imagen de ejecución
FROM eclipse-temurin:21-jre-alpine

WORKDIR /app

# Copiar JAR desde la etapa de build
COPY --from=build /app/target/*.jar app.jar

# Exponer puerto
EXPOSE 8082

# Ejecutar aplicación
ENTRYPOINT ["java", "-jar", "app.jar"]
