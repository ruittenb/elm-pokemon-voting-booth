# Pokémon Sprint Name Voting Booth App in Elm

This is a tool for allowing developers to vote for sprint names.
It consists of a simple Node.js web server and an Elm SPA.

## Ingredients and dependencies:

- [Install Elm](http://elm-lang.org/install). You will need elm 0.18.
- [Install Node](https://nodejs.org/en/download/). You might need node 10.12.0.

For development:

- [Install fswatch](brew install fswatch)
- [Install jq](brew install jq)

Next, install the server dependencies, by running

```
make install
```

## Security Keys:

### Auth0:

Download the Auth0 private key from:

https://manage.auth0.com/dashboard/eu/proforto/applications/n0dhDfP61nzDIRpMaw8UsoPLiNxcxdM9/settings

Scroll down and click 'Show Advanced Settings'. Open the tab 'certificates' and copy the 'Signing Certificate'.
Save it to `server/keys/private-auth0.key`

### Firebase:

Download the firebase private key from:
https://console.firebase.google.com/u/0/project/sprintname-voting-booth/settings/serviceaccounts/adminsdk

Click "Generate new private key".  Save it to `server/keys/serviceAccountKey.json`.

## Running the application:

In terminal run:

```
make start
```

Open `http://localhost:4201`

## Installing in a docker image:

If you want to install the voting booth app in a docker image, you may do so with:

```
make docker-start
```

