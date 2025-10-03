# Usar una imagen oficial de Python ligera
FROM python:3.11-slim

# Establecer el directorio de trabajo dentro del contenedor
WORKDIR /app

# Instalar la librería de PostgreSQL para Python
RUN pip install psycopg2-binary

# Copiar los scripts al contenedor (aunque usaremos un volumen para desarrollar)
COPY . .
