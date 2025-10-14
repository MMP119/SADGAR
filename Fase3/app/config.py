MONGO_URI = "mongodb://admin:admin123@mongodb:27017/"

MONGO_CONFIG = {
    'serverSelectionTimeoutMS': 30000,
    'connectTimeoutMS': 30000,
    'socketTimeoutMS': 30000,
}

BATCH_SIZE = 10000
DATA_PATH = "/data"

TSV_FILES = {
    'people': f"{DATA_PATH}/name.basics.tsv",
    'titles': f"{DATA_PATH}/title.basics.tsv",
    'ratings': f"{DATA_PATH}/title.ratings.tsv",
    'crew': f"{DATA_PATH}/title.crew.tsv",
    'principals': f"{DATA_PATH}/title.principals.tsv",
    'episodes': f"{DATA_PATH}/title.episode.tsv",
}

TITLE_TYPES = {
    'movies': ['movie'],
    'series': ['tvSeries', 'tvMiniSeries'],
    'episodes': ['tvEpisode'],
    'documentaries': ['tvMovie', 'video'],
    'shorts': ['short'],
    'others': ['tvShort', 'tvSpecial', 'videoGame']
}

PERSON_CATEGORIES = {
    'actors': ['actor', 'actress'],
    'directors': ['director'],
    'writers': ['writer'],
}