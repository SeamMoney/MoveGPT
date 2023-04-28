import requests

# set up the server URL and endpoint
server_url = "http://localhost:3000/generate-response"

# get input from user
while True:
    user_input = input("You: ")

    # send user input to server to generate response
    response = requests.post(server_url, json={"question": user_input})
    response_data = response.json()

    # print the response from the server
    print("MoveGPT:", response_data["answer"])
