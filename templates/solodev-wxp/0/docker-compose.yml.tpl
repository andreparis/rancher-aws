version: '2'

volumes:

  session:

  wxp-client:
    driver_opts:
      repl: '2'
      size: '50'
      shared: true
    driver: pxd

  wxp-mysql:
    driver_opts:
      repl: '2'
      size: '10'
    driver: pxd 

  wxp-mongo:
    driver_opts:
      repl: '2'
      size: '10'
    driver: pxd

services:

  php-fpm-lb:
    restart: always
    tty: true
    image: rancher/load-balancer-service
    expose:
      - 9000/tcp
    labels:
      io.rancher.container.agent.role: environmentAdmin
      io.rancher.container.create_agent: 'true'
      io.rancher.scheduler.global: 'true'
    links:
      - php-fpm
    stdin_open: true

  php-fpm:
    image: solodev/wxp:develop
    tty: true
    environment:
      DB_HOST: mysql
      DB_USER: '${MYSQL_USER}'
      DB_PASSWORD: '${MYSQL_PASSWORD}'
      DB_NAME: '${MYSQL_DATABASE}'
      MONGO_HOST: mongo
      SOLODEV_USER: '${SOLODEV_USER}'
      SOLODEV_PASSWORD: '${SOLODEV_PASSWORD}'
      APP_ENV: '${APP_ENV}'
      APP_DEBUG: 0
      APP_SECRET: '${APP_SECRET}'
      DATABASE_URL: 'mysql://${MYSQL_USER}:${MYSQL_PASSWORD}@mysql:${MYSQL_PORT}/solodev'
    labels:
      io.rancher.container.network: true
      io.rancher.container.pull_image: always
      io.rancher.scheduler.global: 'true'
    volumes:
      - wxp-client:/var/www/solodev/fs
      - session:/var/lib/php/session
    links:
      - mysql
      - mongo
    depends_on:
      - mysql
    restart: always

  nginx-lb:
    restart: always
    tty: true
    image: rancher/load-balancer-service
    ports:
      - ${SOLODEV_PORT}:80
    labels:
      io.rancher.container.agent.role: environmentAdmin
      io.rancher.container.create_agent: 'true'
      io.rancher.scheduler.global: 'true'
    links:
      - nginx
    stdin_open: true

  nginx: 
    image: solodev/wxp-nginx:develop
    labels:
      io.rancher.container.network: true
      io.rancher.container.pull_image: always
      io.rancher.scheduler.global: 'true'
    volumes:
      - wxp-client:/var/www/solodev/fs
    links:
      - php-fpm-lb:php-fpm
      - react-lb:react
    entrypoint: /usr/local/bin/wait-for-it.sh php-fpm:9000 -t 60 --
    command: ["nginx", "-g", "daemon off;"]
    restart: always

  react-lb:
    restart: always
    tty: true
    image: rancher/load-balancer-service
    labels:
      io.rancher.container.agent.role: environmentAdmin
      io.rancher.container.create_agent: 'true'
      io.rancher.scheduler.global: 'true'
    expose:
      - 3000/tcp
    links:
      - react
    stdin_open: true

  react:
    image: solodev/wxp-react:develop
    labels:
      io.rancher.scheduler.global: 'true'

  mysql-lb:
    image: rancher/load-balancer-service
    labels:
      io.rancher.scheduler.global: 'true'
    ports:
      - ${MYSQL_PORT}:${MYSQL_PORT}
  
  mysql-data:
    image: busybox
    labels:
      io.rancher.container.start_once: true
    volumes:
      - wxp-mysql:/var/lib/mysql:rw

  mysql:
    image: mysql:5.7.20
    environment:
      MYSQL_DATABASE: '${MYSQL_DATABASE}'
      MYSQL_PASSWORD: '${MYSQL_PASSWORD}'
      MYSQL_ROOT_PASSWORD: '${MYSQL_ROOT_PASSWORD}'
      MYSQL_USER: '${MYSQL_USER}'
    tty: true
    stdin_open: true
    labels:
      io.rancher.sidekicks: mysql-data
      io.rancher.scheduler.global: 'true'
    volumes_from:
      - mysql-data

  mongo:
    image: mongo:3.6
    environment:
      MONGO_INITDB_ROOT_USERNAME: '${MYSQL_USER}'
      MONGO_INITDB_ROOT_PASSWORD: '${MYSQL_ROOT_PASSWORD}'
    volumes:
      - wxp-mongo:/data