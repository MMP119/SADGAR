# Acá todos los scripts de python usados para cargar la data

## Orden de ejecución:

### loader.py carga los datos a las tablas temporales

### etl.py es para filtrar la data y cargar a las tablas finales, se carga de 900k en 900k (este valor se puede ir ampliando dependiendo la máquina), además que se desactivan las claves foráneas para hacer la carga más rápida y luego se reactivan.

### indices_postgres.py es para crear los índices y mejorar las búsquedas a menos de 2 minutos. 