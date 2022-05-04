# Reverse Proxy
A forward proxy, often called a proxy, proxy server, or web proxy is a server that sits in front of a group of client machines. When those computers make requests to sites and services on the Internet, the proxy server intercepts those requests and then communicates with web servers on behalf of those clients, like a mediator.

# Requirements
- Docker
- Docker-compose

# Project Description
This project aims to provide a dynamic reverse proxy that reads the IP address of each service from a database. In this project, I used Redis as a database to store the host address of each service. 

# Project Components
## 1. Docker-Compose
In this section, I will discuss the details of the docker-compose.yml file.

### Network
I created a network for using services, and I called it digi-test.

```yml
networks:
  digi-test:
    name: digi-test
    driver: bridge
```

### Services
In this project, there are three services, OpenResty, Redis, and a mock server.

#### OpenResty
```yml
openResty:
    image: openresty/openresty
    ports:
      - "80:80"
    networks:
      - digi-test
    links:
      - redis:redis
    restart: always
    volumes:
      - ./nginx-conf:/etc/nginx/conf.d
      - ./log:/usr/local/openresty/nginx/logs
      - ./lua:/usr/local/lib/lua-libs
```
This service has multiple parts that will be explained in the following sections.

##### Image
In this service, I used from [openresty/openresty](https://hub.docker.com/r/openresty/openresty), which is the official image of OpenResty.
##### Port
The container made in this image uses port 80. This part of the file map the port with the number of 80 of the host machine to the 80 port of the container.
##### Networks
It shows the network name which contains this service.
##### Links
Links allow us to define extra aliases by which a service is reachable from another service.
##### Restart
The restart policy is set always.
##### Volumes
It is predefined volumes in the host machine to store persistent data for containers.
- The first one is the OpenResty config file address, and it will create a map to the /etc/nginx/conf.d directory.
- The second one is the log directory to store logs of OpenResty.
- The last one is the directory which contains the Lua library.

#### Redis
```yml
redis:
    networks:
      - digi-test
    ports:
      - "6379:6379"
    image: redis
    restart: always
```
This service has multiple parts that will be explained in the following sections.

##### Image
In this service, I used [Redis](https://hub.docker.com/_/redis), which is the official image of Redis.
##### Port
The container made of this image uses port 6379. This part of the file map the 6379 port of the host machine to the 6379 port of the container.
##### Networks
It shows the network name which contains this service.
##### Restart
The restart policy is set with the value of "always".

#### WebServer
```yml
webserver:
    image: digi/mock
    ports:
      - "8000:8000"
    networks:
      - digi-test
    restart: always
```
This container is a simple webserver to test this proxy. This service has multiple parts that will be explained in the following sections.

##### Image
I prepared a mock web server in the mock directory in this service.
##### Port
The container made of this image uses port 8000. This part of the file map the 8000 port of the host machine to the 8000 port of the container.
##### Networks
It shows the network name which contains this service.
##### Restart
The restart policy is set with the value of "always".


## 2. Nginx.Conf
This file contains the configuration of OpenResty to proxy the webservers dynamically. In the following lines, I will explain the different parts of this file.

In the first step, the directory of the Lua package path is specified.

```bash
lua_package_path "/usr/local/lib/lua-libs/?.lua;;";
```

To access the other containers in the container of proxy and resolve their address, I set resolver with the IP address of default docker-compose DNS and disabled IPV6 for lookup in this DNS.

```bash
resolver 127.0.0.11 ipv6=off;
```

In the next part of the file, the server block is defined.

```bash
server 
{
  listen 80;
  server_name api.test.ir;

    location /dynamic/ {
        proxy_pass_request_headers on;
        # proxy_redirect     off;
        set $default_host "http://webserver:8000";
        set $dynamic_host "";
        set $called_path_str "/";

        access_by_lua_block {
            local DRP = require "DynamicReverseProxy"
            local service, called_path_str = DRP.getService(ngx.var.request_uri)
            ngx.var.called_path_str = called_path_str
            ngx.var.dynamic_host = DRP.getHost(service, ngx.var.default_host)
         }
        proxy_pass $dynamic_host/$called_path_str;
    }
}
```
I specified the server name and port in the top lines listened to by proxy. I defined a location with path /dynamic/. I set that the proxy passes all headers to the back server by calling `proxy_pass_request_headers on`. After that, the required variables are defined. The first one is the default host address which will be returned if the specified service host address is not available in the Redis.
`access_by_lua_block` defines a block that contains Lua code to call the Lua package and retrieve the IP address of the service host. At first, I required and created an Object from the DynamicReverseProxy package. Next, I find the service value and the path, which is called. At last, retrieve the host address from Redis.

In the last line, proxy the request to the destination server.

## 3. DynamicReverseProxy.lua

In this file, I defined the primary Lua functions to find the host address of a specific service.
This file contains three functions.

-  **getHost(service, defaultHost)**   
This function returned the host address of the service. It received two inputs: the service name and a default value for the host address. This function is exported for external usage.

- **getService(path)**   
This function extracts the service name based on the requested URI. It considered the second section of the path(after dynamic) as the service name.

- **split(str, pat)**  
This function splits strings based on a given pattern.

# Test
To test the functionality of this project, you must follow these steps.

1. Build image:  
build the mock server docker image at the first stage.
``` bash
cd mock
docker build -t digi/mock .
```
2. Run proxy:   
Run the project with docker-compose.
```bash
docker-compose up -d
```

3. Change address:   
At the first call, the default host address will be saved for specified service in the Redis.
you can change the value of this address by this command:
``` bash
redis-cli set <service> <new_host_address>
```

4. Call Api throw proxy:   
you can call API like the below request. You can call this API by post, get, delete, and put methods.

```bash
curl --location --request POST 'http://PROXY_DOMAIN:PORT/dynamic/SERVICE/crud'
```

