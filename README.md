Blog Frontend
===

Frontend for my blog [inalandscape.dev](https://inalandscape.dev)
Used with API backend service:
[landscape-service](https://github.com/naglalakk/landscape-service)

### Requirements

* [Purescript](https://github.com/purescript/purescript)
* [Spago](https://github.com/spacchetti/spago)
* npm or yarn
* [Parcel](https://parceljs.org) 

### Installation

Once all the requirements are installed run

    make install

### Commands

This project includes a Makefile with a few common tasks:

* build   - Builds code from src
* bundle  - Bundle code from src to commonjs format
* browser - Make a browser compatible js bundle
* clean   - Clean up generated output (e.g. docs)
* docs    - Generate docs from ./spago and ./src folders
* install - Install all dependencies
* server  - Starts development server on port 8080
* test    - Runs tests for Purescript code
* style   - Process .styl files located in static/style

The default package manager set for this project is yarn.
You can change this by editing the PCK_MANAGER variable in the Makefile

### Running the server

Once you have installed everything you can run

    make bundle && make server

### Environment variables

Environment variables can be included in a .env file .e.g

    echo "PORTNR=8081" > .env

PORTNR

The port number the server will be running on. The default port is 8080

API_URL

The API URL for the backend service

API_KEY

Used for server authentication. The API_KEY is a base64 encoded authentication string.
