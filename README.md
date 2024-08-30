# OpenNoodl Better Backend

Welcome to the OpenNoodl Better Backend project. The goal of this project is to provide a stable Backend as a Service for low-code app development projects. 

You'll find a Docker project that will run a local database, Parse Server and Dashboard, n8n for cloud functions, Dozzle for container logging and Traefik for reverse proxy.

The project is meant to be a locally run starting point for initial development, and is not meant for full production use. The transition to a production environment could be easily achieved by swapping certain services for cloud services, such as MinIO for AWS S3 storage and the local MongoDB for MongoDB Atlas.

## Included services

### Parse Dashboard and Server
Parse was the core of the [original Noodl backend](https://github.com/noodlapp/noodl-cloudservice). This lightweight, simple API layer over either MongoDB or Postgres is perfect for low-code beginners right up to production applications. The addition of Parse Dashboard allows low-coders to set up webhooks on data changes, something that wasn't possible in the original Noodl Cloud Service.

https://github.com/parse-community/parse-dashboard
https://github.com/parse-community/parse-server
https://parseplatform.org/

### MongoDB
MongoDB was also at the core of the original Noodl Cloud Service. Its simplicity and scalability makes it the perfect choice from MVP up to production app.

https://mongodb.com/

### MinIO
The addition of MinIO gives beginning projects a simple S3 storage solution to help manage user uploads and test file storage logic. This can later be swapped out for production-grade S3 storage like AWS S3 Buckets or Google Buckets.

https://github.com/minio/minio
https://min.io/

### n8n
This replaces the original Noodl back-end Cloud Functions. n8n provides a simple low-code visual editor for creating server-side workflows with user-friendly logging and debugging.

https://github.com/n8n-io/n8n
https://n8n.io/

### Dozzle
Dozzle provides a GUI to log Docker resource usage and individual service log output, giving the details necessary to find and debug problems with this backend project.

https://github.com/amir20/dozzle
https://dozzle.dev/

### Traefik
Traefik provides a reserve proxy suitable for locally hosted projects as well as through secure public domain names. It acts as the gateway to the different services in this project.

https://github.com/traefik/traefik
https://traefik.io/traefik/

### Redis
In this project Redis is used as a basic cache for Parse and MongoDB, allowing frequent search queries to be performed much more quickly and reducing  the load on the main database.

https://github.com/redis/redis
https://redis.io/

## Getting started

Clone the repo and run ./setup.sh in your terminal of choice.

Choose yes for local development if you're running on a local Docker instance. Choose no if you want to enter your own domain.

Choose the other authentication and configuration parameters, or hit return to accept the default values.

The project should be cross platform, and has been tested on arm64 and x86 environments. 

The following services should be accessible when finished (localhost examples):

* http://dashboard.localhost (Parse Dashboard)
* http://parse.localhost/parse (Parse Server API endpoint)
* http://n8n.localhost (n8n admin dashboard)
* http://minio-console.localhost (MinIO dashboard)
* http://minio.localhost (MinIO API endpoint)
* http://traefik.localhost (Traefik dashboard)
* http://dozzle.localhost (Dozzle dashboard)
