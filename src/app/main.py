from flask import Flask, jsonify
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

class Album:
    def __init__(self, id, title, artist, price, image_url):
        self.id = id
        self.title = title
        self.artist = artist
        self.price = price
        self.image_url = image_url

albums = [
    Album(1, "You, Me and an App Id", "Daprize", 10.99, "https://aka.ms/albums-daprlogo"),
    Album(2, "Seven Revision Army", "The Blue-Green Stripes", 13.99, "https://aka.ms/albums-containerappslogo"),
    Album(3, "Scale It Up", "KEDA Club", 13.99, "https://aka.ms/albums-kedalogo"),
    Album(4, "Lost in Translation", "MegaDNS", 12.99, "https://aka.ms/albums-envoylogo"),
    Album(5, "Lock Down Your Love", "V is for VNET", 12.99, "https://aka.ms/albums-vnetlogo"),
    Album(6, "Sweet Container O' Mine", "Guns N Probeses", 14.99, "https://aka.ms/albums-containerappslogo")
]

@app.route("/")
def read_root():
    return jsonify({"message": "Access /albums to see the list of albums"})

@app.route("/albums")
def get_albums():
    albums_list = [{
        "id": album.id,
        "title": album.title,
        "artist": album.artist,
        "price": album.price,
        "image_url": album.image_url
    } for album in albums]
    return jsonify(albums_list)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
