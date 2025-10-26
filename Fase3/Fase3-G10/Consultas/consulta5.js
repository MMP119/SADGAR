// Colección: titles - Top 10 actores/actrices con más apariciones

[
    { 
      "$match": { 
        "principals.category": { "$in": ["actor", "actress"] } 
      } 
    },
    
    { "$unwind": "$principals" },

    { "$match": { "principals.category": { "$in": ["actor", "actress"] } } },
    { "$group": { "_id": "$principals.nconst", "cantidad": { "$sum": 1 } } },
    { "$sort": { "cantidad": -1 } },
    { "$limit": 10 },
    {
        "$lookup": {
            "from": "people", "localField": "_id", "foreignField": "_id", "as": "actor_info"
        }
    },
    {
        "$project": {
            "_id": 0,
            "nombre_actor": { "$arrayElemAt": ["$actor_info.primaryName", 0] },
            "cantidad_apariciones": "$cantidad"
        }
    }
]