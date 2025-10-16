// Colección: people - Películas de un director específico

[
    // Etapa 1: Encontrar al director por su nombre. Es instantáneo gracias al índice.
    {
      "$match": {
        "primaryName": "Quentin Tarantino"
      }
    },
    // Etapa 2: Unir con 'titles' para encontrar todas las obras donde su ID aparece en el array 'crew.directors'.
    {
      "$lookup": {
        "from": "titles",
        "localField": "_id",
        "foreignField": "crew.directors",
        "as": "peliculas_dirigidas"
      }
    },
    // Etapa 3: "Desenroscar" el array para tener un documento por película.
    {
      "$unwind": "$peliculas_dirigidas"
    },
    // Etapa 4: Reemplazar el documento actual por el de la película.
    {
      "$replaceRoot": {
        "newRoot": "$peliculas_dirigidas"
      }
    },
    {
      "$project": {
        "titulo": "$primaryTitle",
        "año": "$startYear",
        "tipo": "$titleType",
        "_id": 0
      }
    }
]