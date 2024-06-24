import requests

# URL of the API endpoint
url = 'https://album-api.blacksmoke-4580d366.canadacentral.azurecontainerapps.io/albums'

# Make the GET request
response = requests.get(url)

# Check if the request was successful
if response.status_code == 200:
    # Parse the JSON response
    albums = response.json()
    
    # Print the list of albums
    for album in albums:
        print(f"ID: {album['id']}")
        print(f"Title: {album['title']}")
        print(f"Artist: {album['artist']}")
        print(f"Price: {album['price']}")
        print(f"Image URL: {album['image_url']}")
        print("-" * 40)
else:
    print(f"Failed to retrieve albums. HTTP Status code: {response.status_code}")
