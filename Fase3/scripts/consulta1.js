// Colección: titles - INFORMACION DE UNA PELÍCULA EN ESPECÍFICO
[
    {
      "$match": {
        "$text": { 
            "$search": "\"The Dark Knight\"" 
        }
      }
    },
    {
      "$limit": 1 // mostrar un solo resultado
    },
    {
      "$lookup": {
        "from": "people", "localField": "crew.directors", "foreignField": "_id", "as": "director_details"
      }
    },
    {
      "$lookup": {
        "from": "people", "localField": "principals.nconst", "foreignField": "_id", "as": "actor_details"
      }
    },
    {
      "$lookup": {
        "from": "akas", "localField": "_id", "foreignField": "_id", "as": "akas_details"
      }
    },
    {
      "$project": {
        "_id": 0, "titulo_principal": "$primaryTitle", "tipo": "$titleType", "año_lanzamiento": "$startYear", "duracion_minutos": "$runtimeMinutes", "generos": "$genres",
        "rating": { "promedio": "$rating.average", "votos": "$rating.votes" },
        "directores": { "$map": { "input": "$director_details", "as": "dir", "in": "$$dir.primaryName" } },
        "reparto_principal": {
          "$map": {
            "input": "$principals", "as": "p",
            "in": {
              "nombre_actor": { "$arrayElemAt": [ "$actor_details.primaryName", { "$indexOfArray": [ "$actor_details._id", "$$p.nconst" ] } ] },
              "personajes": "$$p.characters"
            }
          }
        },
        "otros_titulos": {
          "$map": {
            "input": "$akas_details", "as": "aka",
            "in": { "titulo": "$$aka.title", "region": "$$aka.region" }
          }
        }
      }
    }
]

