// Colección: titles - Director con más películas

[
    { "$match": { "crew.directors": { "$ne": null, "$not": {"$size": 0} } } },
    { "$unwind": "$crew.directors" },
    { "$group": { "_id": "$crew.directors", "cantidad": { "$sum": 1 } } },
    { "$sort": { "cantidad": -1 } },
    { "$limit": 1 },
    {
      "$lookup": {
        "from": "people", "localField": "_id", "foreignField": "_id", "as": "director_info"
      }
    },
    {
      "$project": {
          "_id": 0,
          "nombre_director": { "$arrayElemAt": ["$director_info.primaryName", 0] },
          "cantidad_obras": "$cantidad"
      }
    }
]
