// Colección: titles - Top 10 películas mejor valoradas 

[
    {
      "$match": {
        "titleType": "movie",
        "rating.votes": { "$gte": 200000 }
      }
    },
    // Etapa 2: Ordenar por rating. Usa la segunda parte del índice.
    {
      "$sort": {
        "rating.average": -1
      }
    },
    // Etapa 3: Limitar a 10.
    {
      "$limit": 10
    },
    {
      "$project": {
        "titulo": "$primaryTitle",
        "rating": "$rating",
        "año": "$startYear",
        "_id": 0
      }
    }
]