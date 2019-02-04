This key pair is used as dummy by the build system. It may be used for local testing. 

Releases that leave your local machine should not use this key pair and need to be resigned with a real key before being deployed.

only and has been generated with following command:

```
openssl req -x509 -newkey rsa:4096 -nodes -keyout key.pem -out cert.pem -subj "/O=PlayOS TESTING CERT /CN=playos-testing" -days 25615
```

Note that the key pair will expire on 22. February 2089.
